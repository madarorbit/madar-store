'use client';

import {useState} from 'react';
import {useRouter} from 'next/navigation';
import type {OrbyMode} from '@/src/lib/orby';

type Message={id:string;role:'user'|'assistant';content:string;source:'ai'|'smart-fallback';created_at:string};
const modeLabels:Record<OrbyMode,string>={ANALYZE:'تحليل البيانات',PLAN:'خطة عمل',REPORT:'تقرير تنفيذي',MARKETING:'أفكار تسويقية'};

export default function OrbyChat({organizationId,initialConversationId,initialMessages,initialRemaining}:{organizationId:string;initialConversationId:string|null;initialMessages:Message[];initialRemaining:number}){
 const router=useRouter();
 const[conversationId,setConversationId]=useState(initialConversationId),[messages,setMessages]=useState(initialMessages),[mode,setMode]=useState<OrbyMode>('ANALYZE'),[prompt,setPrompt]=useState(''),[pending,setPending]=useState(false),[error,setError]=useState(''),[remaining,setRemaining]=useState(initialRemaining);
 async function submit(event:React.FormEvent){
  event.preventDefault();const clean=prompt.trim();if(clean.length<5)return;
  const now=new Date().toISOString(),temporary:Message={id:`local-${Date.now()}`,role:'user',content:clean,source:'ai',created_at:now};
  setMessages(current=>[...current,temporary]);setPrompt('');setPending(true);setError('');
  try{
   const response=await fetch('/api/orby',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({organizationId,conversationId,mode,prompt:clean})});
   const data=await response.json();if(!response.ok)throw new Error(data.error||'تعذر تشغيل أوربي.');
   setConversationId(data.conversationId);setRemaining(Number(data.remaining||0));
   setMessages(current=>[...current,{id:`assistant-${Date.now()}`,role:'assistant',content:data.text,source:data.source,created_at:new Date().toISOString()}]);
   router.refresh();
  }catch(reason){setMessages(current=>current.filter(message=>message.id!==temporary.id));setPrompt(clean);setError(reason instanceof Error?reason.message:'تعذر تشغيل أوربي.');}
  finally{setPending(false)}
 }
 return <section className="rounded-3xl border border-violet-300/20 bg-gradient-to-b from-violet-400/[.06] to-emerald-300/[.03] p-5 sm:p-6">
  <div className="flex flex-wrap items-start justify-between gap-4"><div><p className="font-bold text-[#70E4D4]">أوربي | ORBY</p><h2 className="mt-1 text-2xl font-black">اسأل بيانات تجارتك</h2><p className="mt-2 text-sm leading-7 text-slate-400">يقرأ أوربي سياق مساحتك فقط. لا ينفذ أي تعديل من المحادثة.</p></div><span className="rounded-full border border-white/10 px-3 py-2 text-xs text-slate-300">متبقي اليوم: {remaining}</span></div>
  <div className="mt-6 max-h-[560px] space-y-4 overflow-y-auto rounded-2xl border border-white/10 bg-slate-950/50 p-4">
   {messages.length?messages.map(message=><article key={message.id} className={`max-w-[92%] rounded-2xl p-4 ${message.role==='user'?'mr-auto bg-white text-slate-950':'ml-auto border border-violet-300/15 bg-violet-300/[.07] text-slate-100'}`}><div className="mb-2 flex items-center justify-between gap-3 text-xs opacity-70"><strong>{message.role==='user'?'أنت':'أوربي'}</strong>{message.role==='assistant'&&<span>{message.source==='ai'?'تحليل لغوي بالذكاء الاصطناعي':'تحليل ذكي محلي'}</span>}</div><p className="whitespace-pre-wrap leading-8">{message.content}</p></article>):<div className="py-16 text-center text-slate-500"><p className="text-lg font-bold text-slate-300">ابدأ بسؤال واضح</p><p className="mt-2">مثل: لماذا انخفضت المبيعات؟ أو جهز لي خطة للأسبوع.</p></div>}
   {pending&&<p className="rounded-xl border border-white/10 p-4 text-sm text-slate-400">يحلل أوربي بيانات المساحة…</p>}
  </div>
  <form onSubmit={submit} className="mt-5 grid gap-3"><div className="flex flex-wrap gap-2">{(Object.keys(modeLabels) as OrbyMode[]).map(value=><button type="button" key={value} onClick={()=>setMode(value)} className={`rounded-xl px-3 py-2 text-sm font-bold ${mode===value?'bg-white text-slate-950':'border border-white/10 text-slate-300'}`}>{modeLabels[value]}</button>)}</div><textarea value={prompt} onChange={event=>setPrompt(event.target.value)} minLength={5} maxLength={12000} required rows={4} className="field rounded-2xl p-4" placeholder="اكتب سؤالك اعتمادًا على بيانات تجارتك…"/><div className="flex flex-wrap items-center justify-between gap-3"><p className="text-xs leading-6 text-slate-500">لا تضع كلمات مرور أو بيانات حساسة. الأرقام تأتي من مساحة عملك المعزولة.</p><button disabled={pending||remaining<=0} className="rounded-xl bg-gradient-to-l from-violet-500 to-emerald-400 px-6 py-3 font-black disabled:cursor-not-allowed disabled:opacity-50">{pending?'جارٍ التحليل…':'إرسال إلى أوربي'}</button></div>{error&&<p role="alert" className="rounded-xl border border-red-300/20 bg-red-300/10 p-3 text-sm text-red-100">{error}</p>}</form>
 </section>;
}
