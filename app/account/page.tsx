import PageShell from '@/components/ui/PageShell';
import {Section,PageHero} from '@/components/ui/Section';
import Link from 'next/link';
import {requireUser} from '@/src/lib/auth';
import {currentProfile,supabaseFetch} from '@/src/lib/supabase/server';
import {logout} from '@/app/actions/auth';
export const dynamic='force-dynamic';

export default async function AccountPage(){
 await requireUser();const profile=await currentProfile(),isAdmin=['ADMIN','SUPER_ADMIN'].includes(profile?.role||''),isFounder=profile?.role==='SUPER_ADMIN',unread=(await supabaseFetch('/rest/v1/notifications?read_at=is.null&select=id'))?.length||0;
 const memberships=await supabaseFetch(`/rest/v1/organization_members?user_id=eq.${encodeURIComponent(profile?.id||'')}&select=organizations(type,status)`),hasBusiness=memberships?.some((membership:{organizations?:{type?:string}})=>membership.organizations?.type!=='STUDENT');
 const cards=[['/student','مساحة الطالب المجانية','bg-gradient-to-l from-violet-600 to-emerald-500 text-white'],['/dashboard','لوحة العميل','bg-white text-slate-900'],['/account/profile','الملف الشخصي','bg-white text-slate-900'],['/account/orders','طلباتي من متجر مَدار','bg-white text-slate-900'],['/account/purchases','مكتبتي الرقمية','bg-white text-slate-900'],['/account/notifications',`الإشعارات${unread>0?` (${unread})`:''}`,'bg-white text-slate-900'],['/account/support','دعم وملاحظات Beta','bg-[#70E4D4] text-slate-950'],['/account/privacy','الخصوصية وبياناتي','bg-violet-200 text-violet-950']];
 if(hasBusiness)cards.splice(2,0,['/account/subscription','الاشتراك والفوترة','bg-amber-200 text-amber-950']);
 return <PageShell><PageHero eyebrow="حسابي" title={profile?.full_name||'حساب مَدار'} description="إدارة بياناتك وطلباتك ومساحاتك ودعم النسخة التجريبية من مركز واحد."/><Section><div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">{isAdmin&&<Link className="rounded-2xl bg-[#00C292] p-5 font-black text-slate-950" href="/admin">لوحة إدارة المنصة</Link>}{isFounder&&<Link className="rounded-2xl bg-violet-600 p-5 font-black text-white" href="/admin/founder">مركز قيادة المؤسس</Link>}{cards.map(([href,label,style])=><Link key={href} className={`rounded-2xl p-5 font-black ${style}`} href={href}>{label}</Link>)}</div><form action={logout} className="mt-8"><button className="rounded-xl border border-white/20 px-5 py-3">تسجيل الخروج</button></form></Section></PageShell>;
}
