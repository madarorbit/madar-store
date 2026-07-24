import {currentUser,supabaseFetch} from '@/src/lib/supabase/server';

export const runtime='nodejs';export const dynamic='force-dynamic';

export async function GET(){
 const user=await currentUser();if(!user)return Response.json({error:'يجب تسجيل الدخول.'},{status:401});
 const memberships=await supabaseFetch(`/rest/v1/organization_members?user_id=eq.${encodeURIComponent(user.id)}&role=eq.OWNER&select=organization_id,organizations(id,name,slug,type,status,currency,country,city,industry,whatsapp,website,description,created_at)`),membership=memberships?.find((item:{organizations?:{type?:string}})=>item.organizations?.type!=='STUDENT');
 if(!membership?.organization_id)return Response.json({error:'مالك مساحة العمل فقط يستطيع تصديرها.'},{status:403});
 const organizationId=String(membership.organization_id),org=encodeURIComponent(organizationId);
 const[products,customers,suppliers,sales,expenses,tasks,inventory,members,imports,subscriptions]=await Promise.all([
  supabaseFetch(`/rest/v1/business_products?organization_id=eq.${org}&select=id,name,sku,description,cost_price,sale_price,stock_quantity,low_stock_threshold,status,created_at,updated_at&order=created_at.desc`),
  supabaseFetch(`/rest/v1/business_customers?organization_id=eq.${org}&select=id,name,email,phone,address,status,total_spent,order_count,last_order_at,notes,created_at,updated_at&order=created_at.desc`),
  supabaseFetch(`/rest/v1/business_suppliers?organization_id=eq.${org}&select=id,name,email,phone,address,notes,created_at,updated_at&order=created_at.desc`),
  supabaseFetch(`/rest/v1/business_sales?organization_id=eq.${org}&select=id,sale_number,customer_id,status,currency,subtotal,discount,total,notes,sold_at,created_at,business_sale_items(product_id,product_name,quantity,unit_price,unit_cost,line_total)&order=sold_at.desc`),
  supabaseFetch(`/rest/v1/business_expenses?organization_id=eq.${org}&select=id,supplier_id,category,description,amount,currency,expense_date,notes,created_at&order=expense_date.desc`),
  supabaseFetch(`/rest/v1/business_tasks?organization_id=eq.${org}&select=id,title,description,status,priority,due_at,assigned_to,completed_at,created_at&order=created_at.desc`),
  supabaseFetch(`/rest/v1/inventory_movements?organization_id=eq.${org}&select=id,product_id,movement_type,quantity,balance_after,reference_type,reference_id,notes,created_at&order=created_at.desc`),
  supabaseFetch(`/rest/v1/organization_members?organization_id=eq.${org}&select=user_id,role,created_at,profiles(full_name,email,phone)`),
  supabaseFetch(`/rest/v1/business_imports?organization_id=eq.${org}&select=id,entity_type,file_name,row_count,status,error_message,created_at,reverted_at&order=created_at.desc`),
  supabaseFetch(`/rest/v1/workspace_subscriptions?organization_id=eq.${org}&select=id,status,starts_at,ends_at,grace_ends_at,is_beta_founder,renewal_count,last_payment_at,subscription_plans(code,name,price,currency,billing_months,member_limit,product_limit,storage_mb,orby_daily_limit,import_rows_limit)&order=created_at.desc`)
 ]);
 const payload={exported_at:new Date().toISOString(),export_type:'madar_workspace',organization:membership.organizations,products,customers,suppliers,sales,expenses,tasks,inventory_movements:inventory,members,imports,subscriptions};
 return new Response(JSON.stringify(payload,null,2),{headers:{'Content-Type':'application/json; charset=utf-8','Content-Disposition':`attachment; filename="madar-workspace-${organizationId}-${new Date().toISOString().slice(0,10)}.json"`,'Cache-Control':'no-store'}});
}
