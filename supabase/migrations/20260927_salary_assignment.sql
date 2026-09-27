-- Existing entries are preserved. New salary entries must identify an employee.
create or replace function public.save_expense(p_date date,p_amount bigint,p_category text,p_paid bigint default 0,p_method text default 'cash',p_due date default null,p_supplier uuid default null,p_employee uuid default null,p_memo text default '') returns void language plpgsql security definer set search_path='' as $$
declare v_id uuid; v_role text:=public.app_role();
begin
 if v_role is null or v_role not in ('owner','manager','accountant') then raise exception 'Gider girişi yetkiniz yok.'; end if;
 if p_category='personnel' and v_role not in ('owner','manager') then raise exception 'Maaş bilgilerine erişim yetkiniz yok.'; end if;
 if p_category='personnel' and p_employee is null then raise exception 'Maaş kaydı için personel seçin.'; end if;
 if p_category='personnel' and p_supplier is not null then raise exception 'Maaş kaydı tedarikçiye bağlanamaz.'; end if;
 if p_paid is null or p_paid<0 or p_paid>p_amount then raise exception 'Ödenen tutar toplam tutarı aşamaz.'; end if;
 p_date:=coalesce(p_date,(now() at time zone 'Europe/Istanbul')::date);
 if p_date>(now() at time zone 'Europe/Istanbul')::date then raise exception 'Gelecek güne gider girilemez.'; end if;
 if p_due is not null and p_due<p_date then raise exception 'Vade gider tarihinden önce olamaz.'; end if;
 insert into public.entries(date,kind,amount,category,supplier_id,employee_id,due_date,memo,created_by)
 values(p_date,'expense',p_amount,p_category,p_supplier,p_employee,p_due,coalesce(p_memo,''),auth.uid()) returning id into v_id;
 if p_paid>0 then insert into public.payments(entry_id,date,amount,method,created_by) values(v_id,p_date,p_paid,p_method,auth.uid()); end if;
 insert into public.audit_log(actor,action,entry_id) values(auth.uid(),'expense_created',v_id);
end $$;
