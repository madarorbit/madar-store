import {submitWorkspaceLocalPayment} from '@/app/actions/local-payments';

type PaymentMethod={id:string;name:string;account_name:string;account_identifier:string;instructions:string|null};

export default function PaymentForm({requestId,methods}:{requestId:string;methods:PaymentMethod[]}){
 return <form action={submitWorkspaceLocalPayment} className="mt-6 space-y-5">
  <input type="hidden" name="request_id" value={requestId}/>
  <fieldset className="space-y-3"><legend className="font-black">اختر طريقة الدفع</legend>{methods.map((method,index)=><label key={method.id} className="block cursor-pointer rounded-2xl border border-white/10 bg-white/[.03] p-4 has-[:checked]:border-[#70E4D4]/60 has-[:checked]:bg-[#70E4D4]/10"><div className="flex items-start gap-3"><input required defaultChecked={index===0} type="radio" name="payment_method_id" value={method.id} className="mt-1"/><div><strong>{method.name}</strong><p className="mt-2 text-sm text-slate-300">اسم الحساب: {method.account_name}</p><p dir="ltr" className="mt-1 text-right font-black tracking-wider">{method.account_identifier}</p>{method.instructions&&<p className="mt-2 text-xs leading-6 text-slate-400">{method.instructions}</p>}</div></div></label>)}</fieldset>
  <label className="block font-bold">رقم العملية أو مرجع التحويل<input required minLength={3} maxLength={120} name="payment_reference" className="field mt-2 w-full rounded-xl p-3" placeholder="أدخل الرقم الظاهر في إيصال التحويل"/></label>
  <label className="block font-bold">إثبات التحويل<input required name="proof" type="file" accept="image/jpeg,image/png,image/webp,application/pdf" className="field mt-2 w-full rounded-xl p-3"/><span className="mt-2 block text-xs font-normal text-slate-400">صورة أو PDF، بحد أقصى 10 ميجابايت. الملف خاص ولا يراه إلا فريق الإدارة المخول.</span></label>
  <button className="w-full rounded-xl bg-[#00C292] px-5 py-3 font-black text-black">إرسال الإثبات للمراجعة</button>
 </form>;
}
