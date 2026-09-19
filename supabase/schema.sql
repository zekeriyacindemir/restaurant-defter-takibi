-- Run once in a NEW Supabase project, using SQL Editor.
create table public.members (
 id uuid primary key references auth.users(id), name text not null check(length(name) between 1 and 100),
 role text not null check(role in ('owner','manager','accountant','staff')), active boolean not null default true
);
create table public.suppliers(id uuid primary key default gen_random_uuid(), name text not null check(length(name) between 1 and 120));
create table public.employees(id uuid primary key default gen_random_uuid(), name text not null check(length(name) between 1 and 120));
create table public.entries (
 id uuid primary key default gen_random_uuid(), date date not null, kind text not null check(kind in ('income','expense')),
 amount bigint not null check(amount > 0 and amount <= 100000000000),
 channel text check(channel in ('restaurant','order')), method text check(method in ('cash','card','platform')),
 category text check(category in ('materials','rent','personnel','utilities')),
 supplier_id uuid references public.suppliers(id), employee_id uuid references public.employees(id),
 due_date date, memo text not null default '' check(length(memo)<=500),
 created_by uuid not null references auth.users(id), created_at timestamptz not null default now(),
 void_reason text, voided_by uuid references auth.users(id), voided_at timestamptz,
 check((kind='income' and channel is not null and method is not null and category is null and supplier_id is null and employee_id is null)
 or (kind='expense' and category is not null and channel is null and method is null)),
 check(employee_id is null or category='personnel'), check(method is distinct from 'platform' or channel='order')
);
create unique index daily_income_unique on public.entries(date,channel,method) where kind='income' and voided_at is null;
create index entries_date_idx on public.entries(date);
create table public.payments (
 id uuid primary key default gen_random_uuid(), entry_id uuid not null references public.entries(id), date date not null,
 amount bigint not null check(amount>0), method text not null check(method in ('cash','card','bank')),
 created_by uuid not null references auth.users(id), created_at timestamptz not null default now()
);
create index payments_entry_idx on public.payments(entry_id);
create table public.audit_log(id bigint generated always as identity primary key, actor uuid, action text not null, entry_id uuid, details jsonb, created_at timestamptz not null default now());
create function public.app_role() returns text language sql stable security definer set search_path='' as $$
 select role from public.members where id=auth.uid() and active
$$;
revoke all on function public.app_role() from public;
grant execute on function public.app_role() to authenticated;
alter table public.members enable row level security;
alter table public.suppliers enable row level security;
alter table public.employees enable row level security;
alter table public.entries enable row level security;
alter table public.payments enable row level security;
alter table public.audit_log enable row level security;
create policy members_read on public.members for select to authenticated using(id=auth.uid() or public.app_role()='owner');
create policy suppliers_read on public.suppliers for select to authenticated using(public.app_role() in ('owner','manager','accountant'));
create policy employees_read on public.employees for select to authenticated using(public.app_role() in ('owner','manager'));
create policy entries_read on public.entries for select to authenticated using(public.app_role() in ('owner','manager') or (public.app_role()='accountant' and category is distinct from 'personnel'));
create policy payments_read on public.payments for select to authenticated using(exists(select 1 from public.entries e where e.id=entry_id));
create policy audit_read on public.audit_log for select to authenticated using(public.app_role()='owner');
revoke all on public.members,public.suppliers,public.employees,public.entries,public.payments,public.audit_log from anon,authenticated;
grant select on public.members,public.suppliers,public.employees,public.entries,public.payments,public.audit_log to authenticated;

create function public.save_income(p_date date,p_rows jsonb,p_memo text default '') returns void language plpgsql security definer set search_path='' as $$
declare r jsonb; v_id uuid; v_amount bigint; v_role text:=public.app_role(); v_count int:=0;
begin
 if v_role is null then raise exception 'Erişim yetkiniz yok.'; end if;
 if p_date is null or p_date>(now() at time zone 'Europe/Istanbul')::date then raise exception 'Geçerli bir gün seçin; gelecek güne gelir girilemez.'; end if;
 if p_rows is null or jsonb_typeof(p_rows)<>'array' or jsonb_array_length(p_rows)>5 then raise exception 'Geçersiz gelir alanları.'; end if;
 for r in select * from jsonb_array_elements(p_rows) loop
  v_amount:=(r->>'amount')::bigint;
  if v_amount<0 then raise exception 'Tutar negatif olamaz.'; end if;
  if v_amount>0 then
   insert into public.entries(date,kind,amount,channel,method,memo,created_by)
   values(p_date,'income',v_amount,r->>'channel',r->>'method',coalesce(p_memo,''),auth.uid()) returning id into v_id;
   if r->>'method'<>'platform' then
    insert into public.payments(entry_id,date,amount,method,created_by) values(v_id,p_date,v_amount,r->>'method',auth.uid());
   end if;
   insert into public.audit_log(actor,action,entry_id) values(auth.uid(),'income_created',v_id);
   v_count:=v_count+1;
  end if;
 end loop;
 if v_count=0 then raise exception 'En az bir gelir tutarı girin.'; end if;
exception when unique_violation then raise exception 'Bu gün ve ödeme türü için kayıt var. Müdür mevcut kaydı kontrol etmelidir.';
end $$;

create function public.save_expense(p_date date,p_amount bigint,p_category text,p_paid bigint default 0,p_method text default 'cash',p_due date default null,p_supplier uuid default null,p_employee uuid default null,p_memo text default '') returns void language plpgsql security definer set search_path='' as $$
declare v_id uuid; v_role text:=public.app_role();
begin
 if v_role is null or v_role not in ('owner','manager','accountant') then raise exception 'Gider girişi yetkiniz yok.'; end if;
 if p_category='personnel' and v_role not in ('owner','manager') then raise exception 'Maaş bilgilerine erişim yetkiniz yok.'; end if;
 if p_paid is null or p_paid<0 or p_paid>p_amount then raise exception 'Ödenen tutar toplam tutarı aşamaz.'; end if;
 if p_date is null or p_date>(now() at time zone 'Europe/Istanbul')::date then raise exception 'Gelecek güne gider girilemez.'; end if;
 if p_due is not null and p_due<p_date then raise exception 'Vade gider tarihinden önce olamaz.'; end if;
 insert into public.entries(date,kind,amount,category,supplier_id,employee_id,due_date,memo,created_by)
 values(p_date,'expense',p_amount,p_category,p_supplier,p_employee,p_due,coalesce(p_memo,''),auth.uid()) returning id into v_id;
 if p_paid>0 then insert into public.payments(entry_id,date,amount,method,created_by) values(v_id,p_date,p_paid,p_method,auth.uid()); end if;
 insert into public.audit_log(actor,action,entry_id) values(auth.uid(),'expense_created',v_id);
end $$;

create function public.add_payment(p_entry uuid,p_date date,p_amount bigint,p_method text) returns void language plpgsql security definer set search_path='' as $$
declare e public.entries; v_paid bigint; v_role text:=public.app_role();
begin
 if v_role is null or v_role not in ('owner','manager','accountant') then raise exception 'Ödeme yetkiniz yok.'; end if;
 select * into e from public.entries where id=p_entry for update;
 if not found or e.voided_at is not null then raise exception 'Kayıt bulunamadı.'; end if;
 if e.category='personnel' and v_role not in ('owner','manager') then raise exception 'Maaş bilgilerine erişim yetkiniz yok.'; end if;
 if p_date is null or p_date<e.date or p_date>(now() at time zone 'Europe/Istanbul')::date then raise exception 'Ödeme tarihi kayıt tarihinden önce veya gelecekte olamaz.'; end if;
 select coalesce(sum(amount),0) into v_paid from public.payments where entry_id=p_entry;
 if p_amount is null or p_amount<=0 or v_paid+p_amount>e.amount then raise exception 'Tutar kalan bakiyeyi aşamaz.'; end if;
 insert into public.payments(entry_id,date,amount,method,created_by) values(p_entry,p_date,p_amount,p_method,auth.uid());
 insert into public.audit_log(actor,action,entry_id,details) values(auth.uid(),'payment_created',p_entry,jsonb_build_object('amount',p_amount));
end $$;

create function public.add_contact(p_kind text,p_name text) returns void language plpgsql security definer set search_path='' as $$
declare v_role text:=public.app_role();
begin
 if v_role is null or v_role not in ('owner','manager','accountant') then raise exception 'Yetkiniz yok.'; end if;
 if length(trim(p_name))=0 then raise exception 'Ad girin.'; end if;
 if p_kind='supplier' then insert into public.suppliers(name) values(trim(p_name));
 elsif p_kind='employee' and v_role in ('owner','manager') then insert into public.employees(name) values(trim(p_name));
 else raise exception 'Yetkiniz yok.'; end if;
 insert into public.audit_log(actor,action,details) values(auth.uid(),'contact_created',jsonb_build_object('kind',p_kind,'name',p_name));
end $$;

create function public.void_entry(p_entry uuid,p_reason text) returns void language plpgsql security definer set search_path='' as $$
begin
 if public.app_role() is null or public.app_role() not in ('owner','manager') then raise exception 'İptal yetkiniz yok.'; end if;
 if p_reason is null or length(trim(p_reason))<5 or length(p_reason)>500 then raise exception 'En az 5 karakterlik iptal nedeni girin.'; end if;
 update public.entries set voided_at=now(),voided_by=auth.uid(),void_reason=p_reason where id=p_entry and voided_at is null;
 if not found then raise exception 'Aktif kayıt bulunamadı.'; end if;
 insert into public.audit_log(actor,action,entry_id,details) values(auth.uid(),'entry_voided',p_entry,jsonb_build_object('reason',p_reason));
end $$;

create function public.set_member(p_email text,p_name text,p_role text,p_active boolean default true) returns void language plpgsql security definer set search_path='' as $$
declare v_id uuid;
begin
 if public.app_role() is distinct from 'owner' then raise exception 'Yalnızca işletme sahibi kullanıcıları yönetebilir.'; end if;
 select id into v_id from auth.users where lower(email)=lower(trim(p_email));
 if v_id is null then raise exception 'Önce Supabase Authentication ekranında bu kullanıcıyı oluşturun.'; end if;
 if v_id=auth.uid() then raise exception 'Kendi yetkinizi bu ekrandan değiştiremezsiniz.'; end if;
 insert into public.members(id,name,role,active) values(v_id,p_name,p_role,p_active)
 on conflict(id) do update set name=excluded.name,role=excluded.role,active=excluded.active;
 insert into public.audit_log(actor,action,details) values(auth.uid(),'member_changed',jsonb_build_object('id',v_id,'role',p_role,'active',p_active));
end $$;

create function public.dashboard(p_month date) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_role text:=public.app_role(); v_start date:=date_trunc('month',p_month)::date; v_end date:=(date_trunc('month',p_month)+interval '1 month')::date; v_result jsonb;
begin
 if v_role is null then raise exception 'Hesabınız için aktif bir görev tanımlanmamış.'; end if;
 select jsonb_build_object('profile',jsonb_build_object('id',id,'name',name,'role',role)) into v_result from public.members where id=auth.uid();
 if v_role='staff' then return v_result; end if;
 if p_month is null then raise exception 'Ay seçin.'; end if;
 return v_result || jsonb_build_object(
 'summary',(select jsonb_build_object('income',coalesce(sum(amount) filter(where kind='income'),0),'expense',coalesce(sum(amount) filter(where kind='expense'),0),
 'cash',coalesce(sum(amount) filter(where kind='income' and method='cash'),0),'card',coalesce(sum(amount) filter(where kind='income' and method='card'),0),
 'orders',coalesce(sum(amount) filter(where kind='income' and channel='order'),0)) from public.entries where voided_at is null and date>=v_start and date<v_end),
 'flow',(select jsonb_build_object('received',coalesce(sum(p.amount) filter(where e.kind='income'),0),'paid',coalesce(sum(p.amount) filter(where e.kind='expense'),0)) from public.payments p join public.entries e on e.id=p.entry_id where e.voided_at is null and p.date>=v_start and p.date<v_end),
 'daily',(select coalesce(jsonb_agg(t order by t.date),'[]'::jsonb) from (select date,coalesce(sum(amount) filter(where kind='income'),0) income,coalesce(sum(amount) filter(where kind='expense'),0) expense from public.entries where voided_at is null and date>=v_start and date<v_end group by date)t),
 'categories',(select coalesce(jsonb_agg(t),'[]'::jsonb) from (select category,sum(amount) amount from public.entries where kind='expense' and voided_at is null and date>=v_start and date<v_end group by category)t),
 'entries',(select coalesce(jsonb_agg(t order by t.date desc,t.created_at desc),'[]'::jsonb) from (select e.*,coalesce((select sum(amount) from public.payments where entry_id=e.id),0) paid from public.entries e where date>=v_start and date<v_end and (v_role in ('owner','manager') or category is distinct from 'personnel'))t),
 'open',(select coalesce(jsonb_agg(t order by t.due_date nulls last,t.date),'[]'::jsonb) from (select e.*,coalesce((select sum(amount) from public.payments where entry_id=e.id),0) paid from public.entries e where voided_at is null and (v_role in ('owner','manager') or category is distinct from 'personnel'))t where t.paid<t.amount),
 'payments',(select coalesce(jsonb_agg(t order by t.date desc),'[]'::jsonb) from (select p.*,e.kind,e.category,e.employee_id from public.payments p join public.entries e on e.id=p.entry_id where e.voided_at is null and p.date>=v_start and p.date<v_end and (v_role in ('owner','manager') or e.category is distinct from 'personnel'))t),
 'suppliers',(select coalesce(jsonb_agg(s order by s.name),'[]'::jsonb) from public.suppliers s),
 'employees',case when v_role in ('owner','manager') then (select coalesce(jsonb_agg(e order by e.name),'[]'::jsonb) from public.employees e) else '[]'::jsonb end,
 'members',case when v_role='owner' then (select coalesce(jsonb_agg(m order by m.name),'[]'::jsonb) from public.members m) else '[]'::jsonb end,
 'audit',case when v_role='owner' then (select coalesce(jsonb_agg(a order by a.created_at desc),'[]'::jsonb) from (select * from public.audit_log order by created_at desc limit 50)a) else '[]'::jsonb end
 );
end $$;
revoke all on function public.save_income(date,jsonb,text),public.save_expense(date,bigint,text,bigint,text,date,uuid,uuid,text),public.add_payment(uuid,date,bigint,text),public.add_contact(text,text),public.void_entry(uuid,text),public.set_member(text,text,text,boolean),public.dashboard(date) from public;
grant execute on function public.save_income(date,jsonb,text),public.save_expense(date,bigint,text,bigint,text,date,uuid,uuid,text),public.add_payment(uuid,date,bigint,text),public.add_contact(text,text),public.void_entry(uuid,text),public.set_member(text,text,text,boolean),public.dashboard(date) to authenticated;
