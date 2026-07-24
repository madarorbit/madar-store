'use server';

import {revalidatePath} from 'next/cache';
import {redirect} from 'next/navigation';
import {requireBusinessWorkspace} from '@/src/lib/business';
import {supabaseFetch} from '@/src/lib/supabase/server';
import {required} from '@/src/lib/validation';

const finish=(path:string,error?:string,success?:string)=>redirect(`${path}?${error?'error':'success'}=${encodeURIComponent(error||success||'تمت العملية.')}`);

export async function refreshOrbyInsights(){
 let errorMessage:string|undefined;
 try{
  const{workspace}=await requireBusinessWorkspace();
  await supabaseFetch('/rest/v1/rpc/refresh_orby_insights',{method:'POST',body:JSON.stringify({target_organization:workspace.id})});
  revalidatePath('/workspace/orby');revalidatePath('/workspace');
 }catch(error){errorMessage=error instanceof Error?error.message:'تعذر تحديث تنبيهات أوربي.'}
 finish('/workspace/orby',errorMessage,'حدّث أوربي التنبيهات من أحدث بيانات التجارة.');
}

export async function dismissOrbyInsight(form:FormData){
 let errorMessage:string|undefined;
 try{
  await requireBusinessWorkspace();
  await supabaseFetch('/rest/v1/rpc/dismiss_orby_insight',{method:'POST',body:JSON.stringify({target_insight:required(form.get('insight_id'),'التنبيه')})});
  revalidatePath('/workspace/orby');
 }catch(error){errorMessage=error instanceof Error?error.message:'تعذر إخفاء التنبيه.'}
 finish('/workspace/orby',errorMessage,'تم إخفاء التنبيه.');
}

export async function createOrbyTaskDraft(form:FormData){
 let errorMessage:string|undefined;
 try{
  const{workspace}=await requireBusinessWorkspace();
  const title=required(form.get('title'),'عنوان المهمة').slice(0,220),description=String(form.get('description')||'').trim().slice(0,2000)||null,dueAt=String(form.get('due_at')||'').trim()||null,priority=String(form.get('priority')||'medium');
  if(!['low','medium','high','urgent'].includes(priority))throw new Error('أولوية المهمة غير صالحة.');
  await supabaseFetch('/rest/v1/rpc/create_orby_task_draft',{method:'POST',body:JSON.stringify({target_organization:workspace.id,task_title:title,task_description:description,task_due_at:dueAt,task_priority:priority})});
  revalidatePath('/workspace/orby');
 }catch(error){errorMessage=error instanceof Error?error.message:'تعذر إنشاء مسودة الإجراء.'}
 finish('/workspace/orby',errorMessage,'أنشأ أوربي مسودة مهمة. راجعها ثم أكد التنفيذ.');
}

export async function confirmOrbyAction(form:FormData){
 let errorMessage:string|undefined;
 try{
  await requireBusinessWorkspace();
  await supabaseFetch('/rest/v1/rpc/confirm_orby_action',{method:'POST',body:JSON.stringify({target_draft:required(form.get('draft_id'),'المسودة')})});
  revalidatePath('/workspace/orby');revalidatePath('/workspace/tasks');revalidatePath('/workspace');
 }catch(error){errorMessage=error instanceof Error?error.message:'تعذر تنفيذ الإجراء.'}
 finish('/workspace/orby',errorMessage,'تم تأكيد الإجراء وإنشاء المهمة في مساحة العمل.');
}
