import {currentUser,supabaseFetch} from '@/src/lib/supabase/server';

export const runtime='nodejs';export const dynamic='force-dynamic';

export async function GET(){
 const user=await currentUser();if(!user)return Response.json({error:'يجب تسجيل الدخول.'},{status:401});
 const id=encodeURIComponent(user.id);
 const[profile,memberships,orders,notifications,feedback,privacyRequests]=await Promise.all([
  supabaseFetch(`/rest/v1/profiles?id=eq.${id}&select=id,email,full_name,phone,role,status,email_verified,last_login_at,created_at,updated_at`),
  supabaseFetch(`/rest/v1/organization_members?user_id=eq.${id}&select=role,created_at,organizations(id,name,slug,type,status,currency,created_at)`),
  supabaseFetch(`/rest/v1/orders?user_id=eq.${id}&select=id,order_number,status,payment_status,currency,subtotal,discount_total,total,customer_name,customer_email,customer_phone,customer_notes,payment_reference,paid_at,completed_at,created_at,order_items(quantity,unit_price,line_total,item_type,item_name_snapshot)&order=created_at.desc`),
  supabaseFetch(`/rest/v1/notifications?user_id=eq.${id}&select=id,title,body,link,read_at,created_at&order=created_at.desc`),
  supabaseFetch(`/rest/v1/platform_feedback?user_id=eq.${id}&select=id,organization_id,feedback_type,severity,title,message,page_path,rating,status,admin_note,created_at,resolved_at&order=created_at.desc`),
  supabaseFetch(`/rest/v1/data_privacy_requests?user_id=eq.${id}&select=id,organization_id,request_type,status,reason,admin_note,requested_at,processed_at&order=requested_at.desc`)
 ]);
 const payload={exported_at:new Date().toISOString(),export_type:'madar_account',user_id:user.id,profile:profile?.[0]||null,memberships,orders,notifications,feedback,privacy_requests:privacyRequests};
 return new Response(JSON.stringify(payload,null,2),{headers:{'Content-Type':'application/json; charset=utf-8','Content-Disposition':`attachment; filename="madar-account-${new Date().toISOString().slice(0,10)}.json"`,'Cache-Control':'no-store'}});
}
