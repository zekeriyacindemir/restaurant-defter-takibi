-- Existing installations only. Preserves all historical entries and payments.
-- New installations should run schema.sql instead.
begin;
drop index if exists public.daily_income_unique;
drop function if exists public.save_income(date,jsonb,text);
create or replace function public.save_income(p_amount bigint,p_channel text,p_method text,p_memo text default '') returns void language plpgsql security definer set search_path='' as $$
declare v_id uuid; v_role text:=public.app_role(); v_date date:=(now() at time zone 'Europe/Istanbul')::date;
begin
 if v_role is null then raise exception 'Erişim yetkiniz yok.'; end if;
 if p_amount is null or p_amount<=0 then raise exception 'Tutar sıfırdan büyük olmalı.'; end if;
 if p_channel is null or p_channel not in ('restaurant','order') or p_method is null or p_method not in ('cash','card') then
  raise exception 'Ödeme yöntemini ve satış yerini seçin.';
 end if;
 insert into public.entries(date,kind,amount,channel,method,memo,created_by)
 values(v_date,'income',p_amount,p_channel,p_method,coalesce(p_memo,''),auth.uid()) returning id into v_id;
 insert into public.payments(entry_id,date,amount,method,created_by)
 values(v_id,v_date,p_amount,p_method,auth.uid());
 insert into public.audit_log(actor,action,entry_id) values(auth.uid(),'income_created',v_id);
end $$;

create or replace function public.save_expense(p_date date,p_amount bigint,p_category text,p_paid bigint default 0,p_method text default 'cash',p_due date default null,p_supplier uuid default null,p_employee uuid default null,p_memo text default '') returns void language plpgsql security definer set search_path='' as $$
declare v_id uuid; v_role text:=public.app_role();
begin
 if v_role is null or v_role not in ('owner','manager','accountant') then raise exception 'Gider girişi yetkiniz yok.'; end if;
 if p_category='personnel' and v_role not in ('owner','manager') then raise exception 'Maaş bilgilerine erişim yetkiniz yok.'; end if;
 if p_paid is null or p_paid<0 or p_paid>p_amount then raise exception 'Ödenen tutar toplam tutarı aşamaz.'; end if;
 p_date:=coalesce(p_date,(now() at time zone 'Europe/Istanbul')::date);
 if p_date>(now() at time zone 'Europe/Istanbul')::date then raise exception 'Gelecek güne gider girilemez.'; end if;
 if p_due is not null and p_due<p_date then raise exception 'Vade gider tarihinden önce olamaz.'; end if;
 insert into public.entries(date,kind,amount,category,supplier_id,employee_id,due_date,memo,created_by)
 values(p_date,'expense',p_amount,p_category,p_supplier,p_employee,p_due,coalesce(p_memo,''),auth.uid()) returning id into v_id;
 if p_paid>0 then insert into public.payments(entry_id,date,amount,method,created_by) values(v_id,p_date,p_paid,p_method,auth.uid()); end if;
 insert into public.audit_log(actor,action,entry_id) values(auth.uid(),'expense_created',v_id);
end $$;

create or replace function public.add_payment(p_entry uuid,p_date date,p_amount bigint,p_method text) returns void language plpgsql security definer set search_path='' as $$
declare e public.entries; v_paid bigint; v_role text:=public.app_role();
begin
 if v_role is null or v_role not in ('owner','manager','accountant') then raise exception 'Ödeme yetkiniz yok.'; end if;
 select * into e from public.entries where id=p_entry for update;
 if not found or e.voided_at is not null then raise exception 'Kayıt bulunamadı.'; end if;
 if e.category='personnel' and v_role not in ('owner','manager') then raise exception 'Maaş bilgilerine erişim yetkiniz yok.'; end if;
 p_date:=coalesce(p_date,(now() at time zone 'Europe/Istanbul')::date);
 if p_date<e.date or p_date>(now() at time zone 'Europe/Istanbul')::date then raise exception 'Ödeme tarihi kayıt tarihinden önce veya gelecekte olamaz.'; end if;
 select coalesce(sum(amount),0) into v_paid from public.payments where entry_id=p_entry;
 if p_amount is null or p_amount<=0 or v_paid+p_amount>e.amount then raise exception 'Tutar kalan bakiyeyi aşamaz.'; end if;
 insert into public.payments(entry_id,date,amount,method,created_by) values(p_entry,p_date,p_amount,p_method,auth.uid());
 insert into public.audit_log(actor,action,entry_id,details) values(auth.uid(),'payment_created',p_entry,jsonb_build_object('amount',p_amount));
end $$;


revoke all on function public.save_income(bigint,text,text,text) from public;
grant execute on function public.save_income(bigint,text,text,text) to authenticated;
commit;
