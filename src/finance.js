export const categories={materials:'Malzeme alımı',rent:'Kira',personnel:'Personel',utilities:'Faturalar'};
export const roles={owner:'İşletme sahibi',manager:'Müdür',accountant:'Muhasebeci',staff:'Çalışan'};
export const methods={cash:'Nakit',card:'Kart',platform:'Platform tahsilatı',bank:'Banka'};
export const money=n=>new Intl.NumberFormat('tr-TR',{style:'currency',currency:'TRY',maximumFractionDigits:2,minimumFractionDigits:0}).format((n||0)/100);
export const today=()=>new Intl.DateTimeFormat('en-CA',{timeZone:'Europe/Istanbul',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date());
export const dateText=d=>d?new Intl.DateTimeFormat('tr-TR',{day:'2-digit',month:'short',year:'numeric'}).format(new Date(d+'T12:00:00')):'—';
// Turkish money input: periods group thousands, comma separates kurus.
export function cents(value) {
 const text=String(value??'').trim();
 if(!/^(?:\d+|[1-9]\d{0,2}(?:\.\d{3})+)(?:,\d{1,2})?$/.test(text))
  throw Error('Geçerli bir tutar girin. Örnek: 1.000,50');
 const [whole,decimal='']=text.replaceAll('.','').split(',');
 const amount=Number(whole)*100+Number(decimal.padEnd(2,'0'));
 if(!Number.isSafeInteger(amount)||amount>100000000000)throw Error('Tutar çok büyük.');
 return amount;
}
export function formatAmountInput(value) {
 const text=String(value??'').trim();
 if(!text)return '';
 if(!/^[\d.]+(?:,\d{0,2})?$/.test(text))return text;
 const [whole,decimal]=text.replaceAll('.','').split(',');
 const digits=whole.replace(/^0+(?=\d)/,'');
 return digits.replace(/\B(?=(\d{3})+(?!\d))/g,'.')+(decimal===undefined?'':','+decimal);
}
export function supplierDebt(entries) {
 return entries.filter(e=>e.kind==='expense'&&e.supplier_id&&!e.voided_at)
  .reduce((total,e)=>total+Math.max(0,remaining(e)),0);
}
export function summarize(entries,payments,month){const active=entries.filter(e=>!e.voided_at),selected=active.filter(e=>e.date.startsWith(month));const total=pred=>selected.filter(pred).reduce((a,e)=>a+e.amount,0);const daily=Object.values(selected.reduce((a,e)=>{a[e.date]??={date:e.date,income:0,expense:0};a[e.date][e.kind]+=e.amount;return a},{})).sort((a,b)=>a.date.localeCompare(b.date));const flow={received:0,paid:0};for(const p of payments.filter(p=>p.date.startsWith(month))){const e=active.find(e=>e.id===p.entry_id);if(e)flow[e.kind==='income'?'received':'paid']+=p.amount;}return {summary:{income:total(e=>e.kind==='income'),expense:total(e=>e.kind==='expense'),cash:total(e=>e.kind==='income'&&e.method==='cash'),card:total(e=>e.kind==='income'&&e.method==='card'),orders:total(e=>e.kind==='income'&&e.channel==='order')},flow,daily,categories:Object.keys(categories).map(category=>({category,amount:total(e=>e.category===category)}))};}
export function remaining(e){return e.amount-(e.paid||0);}
export function escapeHTML(value){return String(value??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));}
