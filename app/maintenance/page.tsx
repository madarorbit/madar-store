import Link from 'next/link';
import {supabaseFetch} from '@/src/lib/supabase/server';

export const dynamic='force-dynamic';export const metadata={title:'الصيانة | مَدار'};
export default async function MaintenancePage(){
 const settings=(await supabaseFetch('/rest/v1/platform_settings?id=eq.1&select=maintenance_mode,maintenance_message,support_email,support_whatsapp'))?.[0];
 return <main className="grid min-h-screen place-items-center bg-[#09090b] p-6 text-white"><section className="w-full max-w-2xl rounded-[2rem] border border-amber-300/20 bg-amber-300/[.06] p-8 text-center"><p className="font-bold text-amber-200">مَدار | ORBIT</p><h1 className="mt-4 text-4xl font-black">تجري أعمال صيانة على المنصة</h1><p className="mt-5 leading-8 text-slate-300">{settings?.maintenance_message||'نعمل على تحديث مَدار وتحسينها. ستعود المنصة للعمل عند اكتمال الصيانة.'}</p><div className="mt-7 flex flex-wrap justify-center gap-3"><Link href="/login?next=/admin/founder" className="rounded-xl bg-white px-5 py-3 font-black text-slate-950">دخول المؤسس والإدارة</Link>{settings?.support_email&&<a href={`mailto:${settings.support_email}`} className="rounded-xl border border-white/15 px-5 py-3 font-bold">التواصل مع الدعم</a>}</div></section></main>;
}
