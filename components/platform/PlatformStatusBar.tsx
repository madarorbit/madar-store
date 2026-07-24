import Link from 'next/link';
import {supabaseFetch} from '@/src/lib/supabase/server';

type PlatformSettings={maintenance_mode:boolean;maintenance_message:string|null;announcement_active:boolean;announcement_title:string|null;announcement_body:string|null;support_email:string|null;support_whatsapp:string|null};

export default async function PlatformStatusBar(){
 let settings:PlatformSettings|undefined;try{settings=(await supabaseFetch('/rest/v1/platform_settings?id=eq.1&select=maintenance_mode,maintenance_message,announcement_active,announcement_title,announcement_body,support_email,support_whatsapp'))?.[0]}catch{return null}
 if(!settings)return null;
 if(settings.maintenance_mode)return <div className="border-b border-amber-400/30 bg-amber-300 px-4 py-3 text-center text-sm font-black text-amber-950">وضع الصيانة مفعّل: {settings.maintenance_message||'تجري أعمال صيانة على مَدار.'} <Link href="/login?next=/admin/founder" className="mr-3 underline">دخول الإدارة</Link></div>;
 if(settings.announcement_active&&(settings.announcement_title||settings.announcement_body))return <div className="border-b border-violet-300/20 bg-violet-950 px-4 py-3 text-center text-sm text-violet-50"><strong>{settings.announcement_title||'إعلان مَدار'}</strong>{settings.announcement_body&&<span className="mr-2">{settings.announcement_body}</span>}</div>;
 return null;
}
