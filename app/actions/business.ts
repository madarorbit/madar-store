'use server';

import {revalidatePath} from 'next/cache';
import {redirect} from 'next/navigation';
import {requireBusinessWorkspace,numberValue} from '@/src/lib/business';
import {supabaseFetch} from '@/src/lib/supabase/server';
import {required} from '@/src/lib/validation';

const clean=(value:FormDataEntryValue|null)=>String(value||'').trim()||null;
const finish=(path:string,message:string,error=false)=>redirect(`${path}?${error?'error':'success'}=${encodeURIComponent(message)}`);

export async function createBusinessProduct(form:FormData){
 const path='/workspace/products';
 try{
  const{user,workspace}=await requireBusinessWorkspace();
  const opening=numberValue(form.get('opening_stock'),'المخزون الافتتاحي');
  const rows=await supabaseFetch('/rest/v1/business_products',{method:'POST',body:JSON.stringify({organization_id:workspace.id,name:required(form.get('name'),'اسم المنتج'),sku:clean(form.get('sku')),description:clean(form.get('description')),category:clean(form.get('category')),cost:numberValue(form.get('cost'),'التكلفة'),price:numberValue(form.get('price'),'السعر'),stock_quantity:0,low_stock_threshold:numberValue(form.get('low_stock_threshold'),'حد التنبيه'),created_by:user.id})});
  const product=rows?.[0];
  if(opening>0&&product?.id)await supabaseFetch('/rest/v1/rpc/adjust_inventory',{method:'POST',body:JSON.stringify({target_product:product.id,quantity_change:opening,adjustment_note:'الرصيد الافتتاحي'})});
  revalidatePath(path);revalidatePath('/workspace');
  finish(path,'تمت إضافة المنتج.');
 }catch(error){finish(path,error instanceof Error?error.message:'تعذر إضافة المنتج.',true)}
}

export async function adjustBusinessInventory(form:FormData){
 const path='/workspace/inventory';
 try{
  await requireBusinessWorkspace();
  await supabaseFetch('/rest/v1/rpc/adjust_inventory',{method:'POST',body:JSON.stringify({target_product:required(form.get('product_id'),'المنتج'),quantity_change:numberValue(form.get('quantity_change'),'الكمية',{min:-1000000}),adjustment_note:clean(form.get('note'))})});
  revalidatePath(path);revalidatePath('/workspace/products');revalidatePath('/workspace');
  finish(path,'تم تحديث المخزون.');
 }catch(error){finish(path,error instanceof Error?error.message:'تعذر تحديث المخزون.',true)}
}

export async function createBusinessCustomer(form:FormData){
 const path='/workspace/customers';
 try{
  const{user,workspace}=await requireBusinessWorkspace();
  await supabaseFetch('/rest/v1/business_customers',{method:'POST',body:JSON.stringify({organization_id:workspace.id,name:required(form.get('name'),'اسم العميل'),phone:clean(form.get('phone')),email:clean(form.get('email')),address:clean(form.get('address')),status:String(form.get('status')||'active'),notes:clean(form.get('notes')),created_by:user.id})});
  revalidatePath(path);revalidatePath('/workspace');finish(path,'تمت إضافة العميل.');
 }catch(error){finish(path,error instanceof Error?error.message:'تعذر إضافة العميل.',true)}
}

export async function createBusinessSupplier(form:FormData){
 const path='/workspace/suppliers';
 try{
  const{user,workspace}=await requireBusinessWorkspace();
  await supabaseFetch('/rest/v1/business_suppliers',{method:'POST',body:JSON.stringify({organization_id:workspace.id,name:required(form.get('name'),'اسم المورد'),contact_name:clean(form.get('contact_name')),phone:clean(form.get('phone')),email:clean(form.get('email')),address:clean(form.get('address')),notes:clean(form.get('notes')),balance_due:numberValue(form.get('balance_due'),'الرصيد المستحق'),created_by:user.id})});
  revalidatePath(path);finish(path,'تمت إضافة المورد.');
 }catch(error){finish(path,error instanceof Error?error.message:'تعذر إضافة المورد.',true)}
}

export async function createBusinessExpense(form:FormData){
 const path='/workspace/expenses';
 try{
  const{user,workspace}=await requireBusinessWorkspace();
  await supabaseFetch('/rest/v1/business_expenses',{method:'POST',body:JSON.stringify({organization_id:workspace.id,supplier_id:clean(form.get('supplier_id')),title:required(form.get('title'),'المصروف'),category:clean(form.get('category'))||'other',amount:numberValue(form.get('amount'),'المبلغ',{allowZero:false}),currency:workspace.currency,incurred_at:required(form.get('incurred_at'),'التاريخ'),payment_status:String(form.get('payment_status')||'paid'),notes:clean(form.get('notes')),created_by:user.id})});
  revalidatePath(path);revalidatePath('/workspace');finish(path,'تم تسجيل المصروف.');
 }catch(error){finish(path,error instanceof Error?error.message:'تعذر تسجيل المصروف.',true)}
}

export async function recordBusinessSale(form:FormData){
 const path='/workspace/sales';
 try{
  const{workspace}=await requireBusinessWorkspace();
  const productId=required(form.get('product_id'),'المنتج');
  const quantity=numberValue(form.get('quantity'),'الكمية',{allowZero:false});
  await supabaseFetch('/rest/v1/rpc/record_business_sale',{method:'POST',body:JSON.stringify({target_organization:workspace.id,sale_customer:clean(form.get('customer_id')),items:[{product_id:productId,quantity}],sale_discount:numberValue(form.get('discount'),'الخصم'),sale_payment_status:String(form.get('payment_status')||'paid'),sale_notes:clean(form.get('notes'))})});
  revalidatePath(path);revalidatePath('/workspace/products');revalidatePath('/workspace/inventory');revalidatePath('/workspace/customers');revalidatePath('/workspace');finish(path,'تم تسجيل عملية البيع وتحديث المخزون.');
 }catch(error){finish(path,error instanceof Error?error.message:'تعذر تسجيل البيع.',true)}
}

export async function createBusinessTask(form:FormData){
 const path='/workspace/tasks';
 try{
  const{user,workspace}=await requireBusinessWorkspace();
  await supabaseFetch('/rest/v1/business_tasks',{method:'POST',body:JSON.stringify({organization_id:workspace.id,title:required(form.get('title'),'المهمة'),description:clean(form.get('description')),assigned_to:clean(form.get('assigned_to')),priority:String(form.get('priority')||'medium'),due_at:clean(form.get('due_at')),created_by:user.id})});
  revalidatePath(path);revalidatePath('/workspace');finish(path,'تمت إضافة المهمة.');
 }catch(error){finish(path,error instanceof Error?error.message:'تعذر إضافة المهمة.',true)}
}

export async function updateBusinessTaskStatus(form:FormData){
 const path='/workspace/tasks';
 try{
  const{workspace}=await requireBusinessWorkspace();
  const id=required(form.get('id'),'المهمة'),status=String(form.get('status'));
  if(!['todo','in_progress','done','cancelled'].includes(status))throw new Error('حالة المهمة غير صالحة.');
  await supabaseFetch(`/rest/v1/business_tasks?id=eq.${encodeURIComponent(id)}&organization_id=eq.${encodeURIComponent(workspace.id)}`,{method:'PATCH',body:JSON.stringify({status})});
  revalidatePath(path);revalidatePath('/workspace');finish(path,'تم تحديث المهمة.');
 }catch(error){finish(path,error instanceof Error?error.message:'تعذر تحديث المهمة.',true)}
}
