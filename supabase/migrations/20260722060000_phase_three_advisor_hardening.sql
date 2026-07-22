-- Keep privileged implementations out of the exposed API schema.
alter function public.create_customer_order(jsonb,text,text,text) rename to create_customer_order_impl;
alter function public.create_customer_order_impl(jsonb,text,text,text) set schema private;
alter function public.submit_order_payment(uuid,text) rename to submit_order_payment_impl;
alter function public.submit_order_payment_impl(uuid,text) set schema private;
alter function public.review_order_payment(uuid,boolean,text) rename to review_order_payment_impl;
alter function public.review_order_payment_impl(uuid,boolean,text) set schema private;
alter function public.update_order_fulfillment(uuid,public.order_status,text) rename to update_order_fulfillment_impl;
alter function public.update_order_fulfillment_impl(uuid,public.order_status,text) set schema private;

create function public.create_customer_order(p_items jsonb,p_coupon_code text default null,p_customer_phone text default null,p_customer_notes text default null)
returns uuid language sql security invoker set search_path='' as $$select private.create_customer_order_impl(p_items,p_coupon_code,p_customer_phone,p_customer_notes)$$;
create function public.submit_order_payment(p_order_id uuid,p_payment_reference text)
returns void language sql security invoker set search_path='' as $$select private.submit_order_payment_impl(p_order_id,p_payment_reference)$$;
create function public.review_order_payment(p_order_id uuid,p_approved boolean,p_note text default null)
returns void language sql security invoker set search_path='' as $$select private.review_order_payment_impl(p_order_id,p_approved,p_note)$$;
create function public.update_order_fulfillment(p_order_id uuid,p_status public.order_status,p_note text default null)
returns void language sql security invoker set search_path='' as $$select private.update_order_fulfillment_impl(p_order_id,p_status,p_note)$$;

revoke all on function private.create_customer_order_impl(jsonb,text,text,text) from public,anon;
revoke all on function private.submit_order_payment_impl(uuid,text) from public,anon;
revoke all on function private.review_order_payment_impl(uuid,boolean,text) from public,anon;
revoke all on function private.update_order_fulfillment_impl(uuid,public.order_status,text) from public,anon;
grant execute on function private.create_customer_order_impl(jsonb,text,text,text) to authenticated;
grant execute on function private.submit_order_payment_impl(uuid,text) to authenticated;
grant execute on function private.review_order_payment_impl(uuid,boolean,text) to authenticated;
grant execute on function private.update_order_fulfillment_impl(uuid,public.order_status,text) to authenticated;
revoke all on function public.create_customer_order(jsonb,text,text,text) from public,anon;
revoke all on function public.submit_order_payment(uuid,text) from public,anon;
revoke all on function public.review_order_payment(uuid,boolean,text) from public,anon;
revoke all on function public.update_order_fulfillment(uuid,public.order_status,text) from public,anon;
grant execute on function public.create_customer_order(jsonb,text,text,text),public.submit_order_payment(uuid,text),public.review_order_payment(uuid,boolean,text),public.update_order_fulfillment(uuid,public.order_status,text) to authenticated;

-- Cover foreign keys used by authorization, fulfillment and reporting joins.
create index coupon_redemptions_user_idx on public.coupon_redemptions(user_id);
create index coupons_created_by_idx on public.coupons(created_by);
create index digital_downloads_user_idx on public.digital_downloads(user_id);
create index order_items_product_idx on public.order_items(product_id);
create index order_items_service_idx on public.order_items(service_id);
create index order_history_order_idx on public.order_status_history(order_id);
create index order_history_actor_idx on public.order_status_history(actor_id);
create index orders_coupon_idx on public.orders(coupon_id);
create index orders_organization_idx on public.orders(organization_id);
create index orders_reviewed_by_idx on public.orders(reviewed_by);
create index payment_proofs_order_idx on public.payment_proofs(order_id);
create index payment_proofs_user_idx on public.payment_proofs(user_id);
create index workspace_requests_plan_idx on public.workspace_requests(plan_id);
create index workspace_subscriptions_plan_idx on public.workspace_subscriptions(plan_id);

-- Consolidate overlapping permissive SELECT policies.
drop policy "admins read coupons" on public.coupons;
drop policy "admins read notifications" on public.notifications;
drop policy "users read notifications" on public.notifications;
create policy "users or admins read notifications" on public.notifications for select to authenticated using(user_id=(select auth.uid()) or public.is_admin());

drop policy "admins product files" on public.product_files;
drop policy "paid customers read purchased files" on public.product_files;
create policy "admins or paid customers read files" on public.product_files for select to authenticated using(public.is_admin() or (is_active and exists(select 1 from public.order_items oi join public.orders o on o.id=oi.order_id where oi.product_id=product_id and o.user_id=(select auth.uid()) and o.payment_status='approved')));
create policy "admins insert product files" on public.product_files for insert to authenticated with check(public.is_admin());
create policy "admins update product files" on public.product_files for update to authenticated using(public.is_admin()) with check(public.is_admin());
create policy "admins delete product files" on public.product_files for delete to authenticated using(public.is_admin());

drop policy "admins manage plans" on public.subscription_plans;
create policy "admins insert plans" on public.subscription_plans for insert to authenticated with check(public.is_admin());
create policy "admins update plans" on public.subscription_plans for update to authenticated using(public.is_admin()) with check(public.is_admin());
create policy "admins delete plans" on public.subscription_plans for delete to authenticated using(public.is_admin());
drop policy "admins manage subscriptions" on public.workspace_subscriptions;
create policy "admins insert subscriptions" on public.workspace_subscriptions for insert to authenticated with check(public.is_admin());
create policy "admins update subscriptions" on public.workspace_subscriptions for update to authenticated using(public.is_admin()) with check(public.is_admin());
create policy "admins delete subscriptions" on public.workspace_subscriptions for delete to authenticated using(public.is_admin());
