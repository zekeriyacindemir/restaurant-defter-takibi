import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {PGlite} from '@electric-sql/pglite';
import {cents,summarize,formatAmountInput,supplierDebt,today} from '../src/finance.js';
test('Türkçe para girişi kuruş hassasiyetiyle hesaplanır',()=>{assert.equal(cents('1234,56'),123456);assert.equal(cents('0,29'),29);assert.equal(cents('1.234,56'),123456);assert.equal(cents('1.000'),100000);assert.throws(()=>cents('-1'));assert.throws(()=>cents('2,999'));assert.throws(()=>cents('12.34'));assert.throws(()=>cents(''));assert.throws(()=>cents('1e3'));});
test('Kartla ödenen sipariş bir kez sayılır; ödeme gideri tekrarlamaz',()=>{const e=[{id:'1',date:'2026-08-01',kind:'income',channel:'order',method:'card',amount:50000},{id:'2',date:'2026-08-01',kind:'expense',category:'materials',amount:1000000}];const p=[{entry_id:'1',date:'2026-08-01',amount:50000},{entry_id:'2',date:'2026-08-01',amount:400000},{entry_id:'2',date:'2026-09-01',amount:600000}];const a=summarize(e,p,'2026-08'),b=summarize(e,p,'2026-09');assert.equal(a.summary.income,50000);assert.equal(a.summary.orders,50000);assert.equal(a.summary.card,50000);assert.equal(a.summary.expense,1000000);assert.equal(b.summary.expense,0);assert.equal(b.flow.paid,600000);});
test('PostgreSQL iş kuralları ve rol yetkileri',async t=>{const db=new PGlite();const ids={owner:'00000000-0000-0000-0000-000000000001',manager:'00000000-0000-0000-0000-000000000002',accountant:'00000000-0000-0000-0000-000000000003',staff:'00000000-0000-0000-0000-000000000004',outsider:'00000000-0000-0000-0000-000000000005'};
await db.exec(`create role anon;create role authenticated;create schema auth;create table auth.users(id uuid primary key,email text);create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;grant usage on schema auth to authenticated;grant execute on function auth.uid() to authenticated;`);
await db.exec(await readFile(new URL('../supabase/schema.sql',import.meta.url),'utf8'));
for(const [role,id] of Object.entries(ids)){await db.query('insert into auth.users values ($1,$2)',[id,role+'@example.test']);if(role!=='outsider')await db.query('insert into public.members(id,name,role) values ($1,$2,$2)',[id,role]);}
await db.exec('set role authenticated');
const login=role=>db.query("select set_config('request.jwt.claim.sub',$1,false)",[ids[role]]);
const report=async month=>(await db.query('select public.dashboard($1::date) d',[month])).rows[0].d;
let expense,employee,supplier;
await t.test('Çalışan gelir girebilir; rapor ve ham mali kayıtları okuyamaz',async()=>{await login('staff');await db.exec(`select public.save_income(50000,'order','card','')`);const d=await report('2026-01-01');assert.deepEqual(Object.keys(d),['profile']);assert.equal((await db.query('select * from entries')).rows.length,0);assert.equal((await db.query('select * from payments')).rows.length,0);await assert.rejects(db.exec("insert into suppliers(name) values ('deneme')"));await assert.rejects(db.exec("update members set role='owner'"));await assert.rejects(db.exec("select public.save_expense('2026-01-01',100,'rent')"));await assert.rejects(db.exec("select public.add_contact('employee','Test')"));});
await t.test('Aynı gün aynı kanal ve ödeme yöntemiyle tekrar kayıt eklenebilir',async()=>{
 await login('staff');
 await db.exec("select public.save_income(50000,'order','card','İkinci satış')");
 await db.exec("select public.save_income(10000,'restaurant','cash','Üçüncü satış')");
 await login('owner');const d=await report(today().slice(0,7)+'-01');
 assert.equal(d.summary.income,110000);assert.equal(d.summary.cash,10000);assert.equal(d.summary.card,100000);assert.equal(d.summary.orders,100000);
 assert.equal(d.entries.filter(e=>e.kind==='income').length,3);
 assert.ok(d.entries.every(e=>e.date===today()));assert.equal(d.flow.received,110000);
 await assert.rejects(db.exec("select public.save_income(10000,'order','platform','')"));
 await assert.rejects(db.exec("select public.save_income(0,'order','card','')"));
 await assert.rejects(db.exec("select public.save_income(-1,'order','card','')"));
 assert.equal((await report(today().slice(0,7)+'-01')).summary.income,110000);
});
await t.test('Tedarikçi borcu ve farklı ayda ödeme doğru hesaplanır',async()=>{await login('accountant');await db.exec("select public.add_contact('supplier','Test Gıda')");supplier=(await db.query('select id from suppliers')).rows[0].id;await db.query("select public.save_expense('2026-01-02',1000000,'materials',400000,'cash','2026-02-01',$1)",[supplier]);expense=(await db.query("select id from entries where kind='expense'")).rows[0].id;let d=await report('2026-01-01');assert.equal(d.summary.expense,1000000);assert.equal(d.open[0].amount-d.open[0].paid,600000);await db.query("select public.add_payment($1,'2026-02-01',600000,'bank')",[expense]);d=await report('2026-02-01');assert.equal(d.summary.expense,0);assert.equal(d.flow.paid,600000);assert.equal(d.open.length,0);await assert.rejects(db.query("select public.add_payment($1,'2026-02-01',1,'bank')",[expense]));});
await t.test('Maaş kişi bilgileri muhasebeciye kapalı; toplam giderde mevcut',async()=>{await login('manager');await db.exec("select public.add_contact('employee','Test Personel')");employee=(await db.query('select id from employees')).rows[0].id;await db.query("select public.save_expense('2026-01-03',300000,'personnel',300000,'bank',null,null,$1)",[employee]);await login('accountant');const d=await report('2026-01-01');assert.equal(d.summary.expense,1300000);assert.equal(d.employees.length,0);assert.ok(d.entries.every(e=>e.category!=='personnel'));assert.ok(d.payments.every(e=>e.category!=='personnel'));assert.equal((await db.query('select * from employees')).rows.length,0);assert.equal((await db.query("select * from entries where category='personnel'")).rows.length,0);await assert.rejects(db.exec("select public.save_expense('2026-01-01',100,'personnel')"));await login('manager');assert.equal((await report('2026-01-01')).employees.length,1);});
await t.test('İptal kaydı saklar, rapor ve ödeme toplamından çıkarır',async()=>{await login('accountant');await assert.rejects(db.query('select public.void_entry($1,$2)',[expense,'Hatalı kayıt']));await login('owner');await db.query('select public.void_entry($1,$2)',[expense,'Test düzeltmesi']);const d=await report('2026-01-01');assert.equal(d.summary.expense,300000);assert.equal(d.entries.find(e=>e.id===expense).void_reason,'Test düzeltmesi');assert.equal((await report('2026-02-01')).flow.paid,0);await assert.rejects(db.query("select public.add_payment($1,'2026-02-01',100,'cash')",[expense]));});
await t.test('Geçersiz tutarlar ve gelecek tarihleri reddedilir',async()=>{await login('owner');await assert.rejects(db.exec("select public.save_expense('2026-01-01',100,'rent',200)"));await assert.rejects(db.exec("select public.save_expense('2099-01-01',100,'rent')"));await assert.rejects(db.exec("select public.save_income(null,'order','card','')"));await assert.rejects(db.exec("select public.save_income(100,null,'card','')"));await assert.rejects(db.exec("select public.save_income(100,'restaurant','invalid','')"));});
await t.test('Tarih verilmeden gider ve ödeme Türkiye gününe kaydedilir',async()=>{
 await login('owner');
 await db.query("select public.save_expense(null,100000,'materials',0,'cash',null,$1,null,'Otomatik tarih')",[supplier]);
 let d=await report(today().slice(0,7)+'-01');const e=d.entries.find(e=>e.memo==='Otomatik tarih');assert.equal(e.date,today());
 const expenseBefore=d.summary.expense;
 await db.query("select public.add_payment($1,null,40000,'bank')",[e.id]);
 d=await report(today().slice(0,7)+'-01');assert.equal(d.open.find(x=>x.id===e.id).paid,40000);assert.equal(d.summary.expense,expenseBefore);
 assert.equal(d.payments.find(p=>p.entry_id===e.id).date,today());
});
await t.test('Geçiş SQL dosyası kayıtları korur ve eski tekillik kuralını kaldırır',async()=>{
 await db.exec('reset role');
 const count=(await db.query('select count(*) n from entries')).rows[0].n;
 await db.exec(await readFile(new URL('../supabase/migrations/20260921_flexible_income.sql',import.meta.url),'utf8'));
 assert.equal((await db.query('select count(*) n from entries')).rows[0].n,count);
 assert.equal((await db.query("select indexname from pg_indexes where indexname='daily_income_unique'")).rows.length,0);
 await db.exec('set role authenticated');await login('staff');await db.exec("select public.save_income(100,'restaurant','cash','Geçiş sonrası')");
});
await t.test('Maaş geçişi mevcut kayıtları korur, personele bağlanmayan yeni maaşı reddeder',async()=>{
 await db.exec('reset role');const count=(await db.query('select count(*) n from entries')).rows[0].n;
 await db.exec(await readFile(new URL('../supabase/migrations/20260927_salary_assignment.sql',import.meta.url),'utf8'));
 assert.equal((await db.query('select count(*) n from entries')).rows[0].n,count);
 await db.exec('set role authenticated');await login('owner');
 await assert.rejects(db.exec("select public.save_expense(null,100000,'personnel',100000,'bank')"),/personel seçin/);
 await assert.rejects(db.query("select public.save_expense(null,100000,'personnel',100000,'bank',null,$1,$2)",[supplier,employee]),/tedarikçiye bağlanamaz/);
});
await t.test('Kısmi maaş ödemesi doğru personele yazılır ve iptal toplamları geri alır',async()=>{
 await login('owner');const month=today().slice(0,7)+'-01',before=await report(month);
 await db.query("select public.save_expense(null,100000,'personnel',40000,'bank',null,null,$1,'Maaş kontrolü')",[employee]);
 let d=await report(month);const e=d.entries.find(e=>e.memo==='Maaş kontrolü');
 assert.equal(d.summary.expense,before.summary.expense+100000);assert.equal(e.paid,40000);
 assert.equal(d.payments.filter(p=>p.entry_id===e.id&&p.employee_id===employee).reduce((n,p)=>n+p.amount,0),40000);
 await login('accountant');await assert.rejects(db.query("select public.add_payment($1,null,60000,'bank')",[e.id]));
 await login('manager');await db.query("select public.add_payment($1,null,60000,'bank')",[e.id]);
 d=await report(month);assert.equal(d.summary.expense,before.summary.expense+100000);assert.ok(!d.open.some(x=>x.id===e.id));
 assert.equal(d.payments.filter(p=>p.entry_id===e.id&&p.employee_id===employee).reduce((n,p)=>n+p.amount,0),100000);
 await db.query('select public.void_entry($1,$2)',[e.id,'Maaş test düzeltmesi']);
 d=await report(month);assert.equal(d.summary.expense,before.summary.expense);assert.equal(d.flow.paid,before.flow.paid);assert.ok(!d.payments.some(p=>p.entry_id===e.id));
});
await t.test('Yetkisiz veya pasif hesaplar işlemleri çalıştıramaz',async()=>{await login('outsider');await assert.rejects(report('2026-01-01'));await assert.rejects(db.exec("select public.save_income(100,'restaurant','cash','')"));await login('manager');await assert.rejects(db.exec("select public.set_member('staff@example.test','X','owner')"));await login('owner');await db.exec("select public.set_member('staff@example.test','Çalışan','staff',false)");await login('staff');await assert.rejects(report('2026-01-01'));await db.exec('set role anon');await assert.rejects(report('2026-01-01'));});
await db.close();});

test('Binlik ayırıcı girerken eklenir; kuruşlar ve boş alan korunur',()=>{
 for(const [raw,expected] of [['',''],['1000','1.000'],['1000000','1.000.000'],['1234,56','1.234,56'],['1.234,','1.234,'],['0001','1'],['1.000,05','1.000,05']])assert.equal(formatAmountInput(raw),expected);
 assert.equal(formatAmountInput('-100'),'-100');assert.throws(()=>cents(formatAmountInput('-100')));
 assert.equal(formatAmountInput('1,234'),'1,234');assert.throws(()=>cents(formatAmountInput('1,234')));
});
test('Tedarikçi toplam borcu yalnızca aktif ve kalan tedarikçi borçlarını içerir',()=>{
 assert.equal(supplierDebt([{kind:'expense',supplier_id:'s',amount:1000000,paid:400000},{kind:'expense',supplier_id:'s',amount:200000,paid:200000},{kind:'expense',supplier_id:'s',amount:500000,paid:0,voided_at:'2026-01-01'},{kind:'expense',amount:800000,paid:0},{kind:'income',supplier_id:'s',amount:100000,paid:0}]),600000);
});
