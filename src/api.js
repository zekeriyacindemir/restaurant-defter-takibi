import {createClient} from '@supabase/supabase-js';
const url=import.meta.env.VITE_SUPABASE_URL,key=import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY;
export const configured=Boolean(url&&key);
export const misconfigured=Boolean(url||key)&&!configured;
export const client=configured?createClient(url,key):null;
export async function rpc(name,args){const {data,error}=await client.rpc(name,args);if(error)throw Error(error.message);return data;}
