import {loadEnv} from 'vite';
const env={...loadEnv('production',process.cwd(),'VITE_'),...process.env};
const url=env.VITE_SUPABASE_URL,key=env.VITE_SUPABASE_PUBLISHABLE_KEY;
if(!url||!key)throw Error('Canlı sürüm için Supabase URL ve publishable/anon anahtarı gerekli. Örnek önizleme için npm run build:demo kullanın.');
if(!/^https:\/\/[a-z0-9-]+\.supabase\.co\/?$/.test(url))throw Error('Supabase HTTPS proje adresini kontrol edin.');
let legacyRole;try{legacyRole=JSON.parse(Buffer.from(key.split('.')[1],'base64url').toString()).role;}catch{}
if(!key.startsWith('sb_publishable_')&&legacyRole!=='anon')throw Error('Yalnızca publishable veya anon anahtarı kullanın. Secret/service_role anahtarı tarayıcıya konulamaz.');
console.log('Canlı bağlantı ayarlarının biçimi doğrulandı.');
