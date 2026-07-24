import Link from 'next/link';
import ActionFeedback from '@/components/business/ActionFeedback';
import OrbyChat from '@/components/orby/OrbyChat';
import {confirmOrbyAction,createOrbyTaskDraft,dismissOrbyInsight,refreshOrbyInsights} from '@/app/actions/orby';
import {adenToday} from '@/src/lib/analytics';
import {requireBusinessWorkspace} from '@/src/lib/business';
import {supabaseFetch} from '@/src/lib/supabase/server';

export const dynamic='force-dynamic';
export const metadata={title:'أوربي | مَدار'};
const severityClasses:{[key:string]:string}={critical:'border-red-300/25 bg-red-300/[.07]',warning:'border-amber-300/25 bg-amber-300/[.07]',info:'border-sky-300/20 bg-sky-300/[.06]'};
const priorityLabels:{[key:string]:string}={low:'منخفضة',medium:'متوسطة',high:'عالية',urgent:'عاجلة'};

type Conversation={id:string;title:string;last_message_at:string};
type OrbyMessage={id:string;role:'user'|'assistant';content:string;source:'ai'|'smart-fallback';created_at:string};
type Insight={id:string;severity:string;title:string;body:string;action_path:string|null;generated_at:string};
type Draft={id:string;payload:{title:string;description?:string|null;priority:string;due_at?:string|null};created_at:string};

export default async function OrbyPage({searchParams}:{searchParams:Promise<{conversation?:string;success?:string;error?:string}>}){
 const{workspace,user}=await requireBusinessWorkspace(),params=await searchParams,org=encodeURIComponent(workspace.id),uid=encodeURIComponent(user.id);
 const[conversations,insights,usage,drafts]=await Promise.all([
  supabaseFetch(`/rest/v1/orby_conversations?organization_id=eq.${org}&user_id=eq.${uid}&status=eq.active&select=id,title,last_message_at&order=last_message_at.desc&limit=30`).catch(()=>[]),
  supabaseFetch(`/rest/v1/orby_insights?organization_id=eq.${org}&status=eq.active&select=id,severity,title,body,action_path,generated_at&order=severity.asc,generated_at.desc`).catch(()=>[]),
  supabaseFetch(`/rest/v1/orby_usage_daily?organization_id=eq.${org}&user_id=eq.${uid}&usage_date=eq.${adenToday()}&select=requests&limit=1`).catch(()=>[]),
  supabaseFetch(`/rest/v1/orby_action_drafts?organization_id=eq.${org}&user_id=eq.${uid}&status=eq.draft&select=id,payload,created_at&order=created_at.desc&limit=20`).catch(()=>[]),
 ]);
 const available=conversations as Conversation[],requested=params.conversation,selected=available.find(item=>item.id===requested)||available[0]||null;
 const messages:OrbyMessage[]=selected?await supabaseFetch(`/rest/v1/orby_messages?conversation_id=eq.${encodeURIComponent(selected.id)}&organization_id=eq.${org}&user_id=eq.${uid}&select=id,role,content,source,created_at&order=created_at.asc&limit=100`).catch(()=>[]):[];
 const remaining=Math.max(0,20-Number(usage?.[0]?.requests||0));
 return <main className="mx-auto max-w-7xl p-5 py-10">
  <div className="flex flex-wrap items-end justify-between gap-5"><div><p className="font-bold text-[#70E4D4]">العقل التشغيلي لمَدار</p><h2 className="mt-2 text-4xl font-black">أوربي | ORBY</h2><p className="mt-3 max-w-3xl leading-8 text-slate-300">يفهم مؤشرات تجارتك، يفسرها، ويقترح الخطوة التالية. بيانات كل مساحة تبقى منفصلة ولا تُستخدم للإجابة عن مساحة أخرى.</p></div><form action={refreshOrbyInsights}><button className="rounded-xl border border-white/15 px-5 py-3 font-black">تحديث التنبيهات الذكية</button></form></div>
  <div className="mt-6"><ActionFeedback success={params.success} error={params.error}/></div>
  <section className="mt-7 grid gap-5 lg:grid-cols-[260px_1fr]">
   <aside className="rounded-3xl border border-white/10 bg-white/[.03] p-4"><div className="flex items-center justify-between"><h3 className="font-black">المحادثات</h3><Link href="/workspace/orby?conversation=new" className="rounded-lg bg-white px-3 py-2 text-xs font-bold text-slate-950">جديدة</Link></div><div className="mt-4 space-y-2">{available.length?available.map(item=><Link key={item.id} href={`/workspace/orby?conversation=${item.id}`} className={`block rounded-xl p-3 ${selected?.id===item.id?'bg-violet-300/15 text-white':'text-slate-400 hover:bg-white/[.04]'}`}><strong className="line-clamp-2 text-sm">{item.title}</strong><span className="mt-1 block text-[10px]">{new Date(item.last_message_at).toLocaleString('ar-YE')}</span></Link>):<p className="rounded-xl border border-dashed border-white/10 p-4 text-center text-xs text-slate-500">لم تبدأ محادثة بعد.</p>}</div></aside>
   <OrbyChat key={selected?.id||'new'} organizationId={workspace.id} initialConversationId={requested==='new'?null:selected?.id||null} initialMessages={requested==='new'?[]:messages} initialRemaining={remaining}/>
  </section>
  <section className="mt-8 grid gap-7 xl:grid-cols-[1.25fr_.75fr]">
   <article className="rounded-3xl border border-white/10 p-6"><div className="flex items-center justify-between gap-4"><div><h3 className="text-2xl font-black">تنبيهات أوربي الاستباقية</h3><p className="mt-2 text-sm text-slate-400">تُبنى بقواعد موثوقة من بيانات مَدار حتى لو كان مزود الذكاء الاصطناعي متوقفًا.</p></div><span className="rounded-full border border-white/10 px-3 py-2 text-xs">{insights.length} نشط</span></div><div className="mt-5 space-y-4">{insights.length?(insights as Insight[]).map(insight=><div key={insight.id} className={`rounded-2xl border p-5 ${severityClasses[insight.severity]||severityClasses.info}`}><div className="flex flex-wrap items-start justify-between gap-4"><div><h4 className="font-black">{insight.title}</h4><p className="mt-2 leading-7 text-slate-300">{insight.body}</p><p className="mt-2 text-xs text-slate-500">{new Date(insight.generated_at).toLocaleString('ar-YE')}</p></div><div className="flex gap-2">{insight.action_path&&<Link href={insight.action_path} className="rounded-xl bg-white px-3 py-2 text-xs font-bold text-slate-950">فتح</Link>}<form action={dismissOrbyInsight}><input type="hidden" name="insight_id" value={insight.id}/><button className="rounded-xl border border-white/15 px-3 py-2 text-xs font-bold">إخفاء</button></form></div></div></div>):<div className="rounded-2xl border border-dashed border-white/10 p-10 text-center text-slate-500"><p>لا توجد تنبيهات نشطة.</p><p className="mt-2 text-sm">اضغط «تحديث التنبيهات الذكية» لتحليل أحدث البيانات.</p></div>}</div></article>
   <article className="rounded-3xl border border-white/10 p-6"><h3 className="text-2xl font-black">إجراء بموافقتك</h3><p className="mt-2 text-sm leading-7 text-slate-400">ينشئ أوربي مسودة فقط. لن تظهر المهمة في مساحة العمل إلا بعد تأكيدك.</p><form action={createOrbyTaskDraft} className="mt-5 grid gap-3"><input name="title" required maxLength={220} className="field rounded-xl p-3" placeholder="عنوان المهمة المقترحة"/><textarea name="description" maxLength={2000} rows={3} className="field rounded-xl p-3" placeholder="تفاصيل اختيارية"/><div className="grid grid-cols-2 gap-3"><select name="priority" defaultValue="medium" className="field rounded-xl p-3"><option value="low">منخفضة</option><option value="medium">متوسطة</option><option value="high">عالية</option><option value="urgent">عاجلة</option></select><input name="due_at" type="datetime-local" className="field rounded-xl p-3"/></div><button className="rounded-xl bg-gradient-to-l from-violet-500 to-emerald-400 p-3 font-black">إنشاء مسودة للمراجعة</button></form><div className="mt-6 space-y-3">{drafts.length?(drafts as Draft[]).map(draft=><div key={draft.id} className="rounded-2xl bg-white/[.04] p-4"><div className="flex items-start justify-between gap-3"><div><strong>{draft.payload.title}</strong><p className="mt-1 text-xs text-slate-400">{priorityLabels[draft.payload.priority]||draft.payload.priority}{draft.payload.due_at?` · ${new Date(draft.payload.due_at).toLocaleString('ar-YE')}`:''}</p></div><form action={confirmOrbyAction}><input type="hidden" name="draft_id" value={draft.id}/><button className="rounded-xl bg-white px-3 py-2 text-xs font-black text-slate-950">تأكيد التنفيذ</button></form></div>{draft.payload.description&&<p className="mt-3 text-sm leading-7 text-slate-400">{draft.payload.description}</p>}</div>):<p className="rounded-xl border border-dashed border-white/10 p-5 text-center text-xs text-slate-500">لا توجد مسودات تنتظر التأكيد.</p>}</div></article>
  </section>
 </main>;
}
