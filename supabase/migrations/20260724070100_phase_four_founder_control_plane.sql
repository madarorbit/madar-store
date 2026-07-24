-- Phase 4.6 founder control plane and Beta launch settings.

create table public.platform_settings (
 id smallint primary key default 1 check(id=1),
 platform_name text not null default 'مَدار',
 beta_registration_open boolean not null default true,
 workspace_creation_enabled boolean not null default true,
 store_enabled boolean not null default true,
 orby_enabled boolean not null default true,
 maintenance_mode boolean not null default false,
 maintenance_message text,
 announcement_active boolean not null default false,
 announcement_title text,
 announcement_body text,
 support_email text,
 support_whatsapp text,
 updated_by uuid references auth.users(id) on delete set null,
 updated_at timestamptz not null default now(),
 check(char_length(coalesce(maintenance_message,''))<=1000),
 check(char_length(coalesce(announcement_title,''))<=180),
 check(char_length(coalesce(announcement_body,''))<=2000)
);
insert into public.platform_settings(id,support_email) values(1,'orbit.ops.digital@gmail.com') on conflict(id) do nothing;
alter table public.platform_settings enable row level security;
create policy "everyone reads platform settings" on public.platform_settings for select to anon,authenticated using(true);
create policy "super admins update platform settings" on public.platform_settings for update to authenticated using(private.is_super_admin()) with check(private.is_super_admin());
revoke all on table public.platform_settings from anon,authenticated;
grant select on public.platform_settings to anon,authenticated;
grant update on public.platform_settings to authenticated;

create or replace function private.founder_user_id()
returns uuid language sql stable security definer set search_path='' as $$
 select id from public.profiles where role='SUPER_ADMIN' order by created_at asc,id asc limit 1
$$;
revoke all on function private.founder_user_id() from public,anon,authenticated;

create or replace function private.founder_update_settings_impl(
 registration_open boolean,workspace_enabled boolean,store_open boolean,orby_open boolean,
 maintenance boolean,maintenance_text text,announcement_enabled boolean,announcement_heading text,
 announcement_text text,support_mail text,support_phone text)
returns public.platform_settings language plpgsql security definer set search_path='' as $$
declare changed public.platform_settings;
begin
 if not private.is_super_admin() then raise exception 'SUPER_ADMIN_REQUIRED';end if;
 update public.platform_settings set
  beta_registration_open=coalesce(registration_open,beta_registration_open),
  workspace_creation_enabled=coalesce(workspace_enabled,workspace_creation_enabled),
  store_enabled=coalesce(store_open,store_enabled),
  orby_enabled=coalesce(orby_open,orby_enabled),
  maintenance_mode=coalesce(maintenance,maintenance_mode),
  maintenance_message=nullif(btrim(maintenance_text),''),
  announcement_active=coalesce(announcement_enabled,announcement_active),
  announcement_title=nullif(btrim(announcement_heading),''),
  announcement_body=nullif(btrim(announcement_text),''),
  support_email=nullif(btrim(support_mail),''),
  support_whatsapp=nullif(btrim(support_phone),''),
  updated_by=(select auth.uid()),updated_at=now()
 where id=1 returning * into changed;
 insert into public.audit_logs(actor_id,action,entity_type,entity_id,metadata)
 values((select auth.uid()),'platform.settings.updated','platform_settings',null,jsonb_build_object('maintenance_mode',changed.maintenance_mode,'registration_open',changed.beta_registration_open,'store_enabled',changed.store_enabled,'orby_enabled',changed.orby_enabled));
 return changed;
end $$;
revoke all on function private.founder_update_settings_impl(boolean,boolean,boolean,boolean,boolean,text,boolean,text,text,text,text) from public,anon,authenticated;
create or replace function public.founder_update_settings(registration_open boolean,workspace_enabled boolean,store_open boolean,orby_open boolean,maintenance boolean,maintenance_text text,announcement_enabled boolean,announcement_heading text,announcement_text text,support_mail text,support_phone text)
returns public.platform_settings language sql security invoker set search_path='' as $$select private.founder_update_settings_impl(registration_open,workspace_enabled,store_open,orby_open,maintenance,maintenance_text,announcement_enabled,announcement_heading,announcement_text,support_mail,support_phone)$$;
revoke all on function public.founder_update_settings(boolean,boolean,boolean,boolean,boolean,text,boolean,text,text,text,text) from public,anon;
grant execute on function public.founder_update_settings(boolean,boolean,boolean,boolean,boolean,text,boolean,text,text,text,text) to authenticated;
grant execute on function private.founder_update_settings_impl(boolean,boolean,boolean,boolean,boolean,text,boolean,text,text,text,text) to authenticated;

create or replace function private.founder_update_user_impl(target_user uuid,new_role public.app_role,new_status public.account_status)
returns public.profiles language plpgsql security definer set search_path='' as $$
declare founder_id uuid;current_profile public.profiles;changed public.profiles;active_super_admins integer;
begin
 if not private.is_super_admin() then raise exception 'SUPER_ADMIN_REQUIRED';end if;
 founder_id:=private.founder_user_id();
 select * into current_profile from public.profiles where id=target_user for update;
 if current_profile.id is null then raise exception 'USER_NOT_FOUND';end if;
 if target_user=founder_id and (new_role<>'SUPER_ADMIN' or new_status<>'active') then raise exception 'FOUNDER_ACCOUNT_PROTECTED';end if;
 if current_profile.role='SUPER_ADMIN' and (new_role<>'SUPER_ADMIN' or new_status<>'active') then
  select count(*) into active_super_admins from public.profiles where role='SUPER_ADMIN' and status='active';
  if active_super_admins<=1 then raise exception 'LAST_SUPER_ADMIN_PROTECTED';end if;
 end if;
 update public.profiles set role=new_role,status=new_status,updated_at=now() where id=target_user returning * into changed;
 insert into public.audit_logs(actor_id,action,entity_type,entity_id,metadata)
 values((select auth.uid()),'founder.user.updated','profile',target_user,jsonb_build_object('old_role',current_profile.role,'new_role',new_role,'old_status',current_profile.status,'new_status',new_status));
 insert into public.notifications(user_id,title,body,link)
 values(target_user,'تم تحديث صلاحيات حسابك في مَدار','حدّث مؤسس المنصة حالة الحساب أو مستوى الصلاحية. تواصل مع الدعم إن لم تتوقع هذا التغيير.','/account');
 return changed;
end $$;
revoke all on function private.founder_update_user_impl(uuid,public.app_role,public.account_status) from public,anon,authenticated;
create or replace function public.founder_update_user(target_user uuid,new_role public.app_role,new_status public.account_status)
returns public.profiles language sql security invoker set search_path='' as $$select private.founder_update_user_impl(target_user,new_role,new_status)$$;
revoke all on function public.founder_update_user(uuid,public.app_role,public.account_status) from public,anon;
grant execute on function public.founder_update_user(uuid,public.app_role,public.account_status) to authenticated;
grant execute on function private.founder_update_user_impl(uuid,public.app_role,public.account_status) to authenticated;

create or replace function private.founder_update_organization_impl(target_organization uuid,new_status public.organization_status)
returns public.organizations language plpgsql security definer set search_path='' as $$
declare changed public.organizations;
begin
 if not private.is_super_admin() then raise exception 'SUPER_ADMIN_REQUIRED';end if;
 update public.organizations set status=new_status,updated_at=now() where id=target_organization returning * into changed;
 if changed.id is null then raise exception 'ORGANIZATION_NOT_FOUND';end if;
 insert into public.audit_logs(actor_id,action,entity_type,entity_id,metadata)
 values((select auth.uid()),'founder.organization.updated','organization',changed.id,jsonb_build_object('organization_id',changed.id,'status',new_status));
 insert into public.notifications(user_id,title,body,link)
 select m.user_id,'تم تحديث حالة مساحة العمل',format('أصبحت حالة مساحة %s: %s',changed.name,new_status),'/dashboard'
 from public.organization_members m where m.organization_id=changed.id and m.role in ('OWNER','ADMIN');
 return changed;
end $$;
revoke all on function private.founder_update_organization_impl(uuid,public.organization_status) from public,anon,authenticated;
create or replace function public.founder_update_organization(target_organization uuid,new_status public.organization_status)
returns public.organizations language sql security invoker set search_path='' as $$select private.founder_update_organization_impl(target_organization,new_status)$$;
revoke all on function public.founder_update_organization(uuid,public.organization_status) from public,anon;
grant execute on function public.founder_update_organization(uuid,public.organization_status) to authenticated;
grant execute on function private.founder_update_organization_impl(uuid,public.organization_status) to authenticated;

create or replace function private.founder_adjust_subscription_impl(target_organization uuid,days_delta integer,requested_status text,beta_founder boolean)
returns public.workspace_subscriptions language plpgsql security definer set search_path='' as $$
declare subscription public.workspace_subscriptions;plan public.subscription_plans;new_end timestamptz;
begin
 if not private.is_super_admin() then raise exception 'SUPER_ADMIN_REQUIRED';end if;
 if days_delta not between -3650 and 3650 then raise exception 'INVALID_DAY_ADJUSTMENT';end if;
 if requested_status not in ('active','past_due','expired','cancelled') then raise exception 'INVALID_SUBSCRIPTION_STATUS';end if;
 select * into subscription from public.workspace_subscriptions where organization_id=target_organization order by created_at desc limit 1 for update;
 if subscription.id is null then raise exception 'SUBSCRIPTION_NOT_FOUND';end if;
 select * into plan from public.subscription_plans where id=subscription.plan_id;
 new_end:=case when days_delta>0 then greatest(subscription.ends_at,now())+(days_delta||' days')::interval when days_delta<0 then subscription.ends_at+(days_delta||' days')::interval else subscription.ends_at end;
 update public.workspace_subscriptions set status=requested_status,ends_at=new_end,grace_ends_at=new_end+(coalesce(plan.grace_days,7)||' days')::interval,is_beta_founder=coalesce(beta_founder,is_beta_founder),updated_at=now() where id=subscription.id returning * into subscription;
 insert into public.audit_logs(actor_id,action,entity_type,entity_id,metadata)
 values((select auth.uid()),'founder.subscription.adjusted','workspace_subscription',subscription.id,jsonb_build_object('organization_id',target_organization,'days_delta',days_delta,'status',requested_status,'is_beta_founder',subscription.is_beta_founder,'ends_at',subscription.ends_at));
 return subscription;
end $$;
revoke all on function private.founder_adjust_subscription_impl(uuid,integer,text,boolean) from public,anon,authenticated;
create or replace function public.founder_adjust_subscription(target_organization uuid,days_delta integer,requested_status text,beta_founder boolean)
returns public.workspace_subscriptions language sql security invoker set search_path='' as $$select private.founder_adjust_subscription_impl(target_organization,days_delta,requested_status,beta_founder)$$;
revoke all on function public.founder_adjust_subscription(uuid,integer,text,boolean) from public,anon;
grant execute on function public.founder_adjust_subscription(uuid,integer,text,boolean) to authenticated;
grant execute on function private.founder_adjust_subscription_impl(uuid,integer,text,boolean) to authenticated;

create or replace function private.founder_broadcast_notification_impl(audience text,target_organization uuid,notice_title text,notice_body text,notice_link text)
returns integer language plpgsql security definer set search_path='' as $$
declare inserted_count integer;
begin
 if not private.is_super_admin() then raise exception 'SUPER_ADMIN_REQUIRED';end if;
 if audience not in ('all','customers','admins','workspace') then raise exception 'INVALID_AUDIENCE';end if;
 if char_length(btrim(notice_title)) not between 3 and 180 or char_length(btrim(notice_body)) not between 3 and 2000 then raise exception 'INVALID_NOTIFICATION';end if;
 if audience='workspace' and target_organization is null then raise exception 'ORGANIZATION_REQUIRED';end if;
 if audience='workspace' then
  insert into public.notifications(user_id,title,body,link)
  select distinct m.user_id,btrim(notice_title),btrim(notice_body),nullif(btrim(notice_link),'') from public.organization_members m where m.organization_id=target_organization;
 elsif audience='admins' then
  insert into public.notifications(user_id,title,body,link)
  select p.id,btrim(notice_title),btrim(notice_body),nullif(btrim(notice_link),'') from public.profiles p where p.role in ('ADMIN','SUPER_ADMIN') and p.status='active';
 elsif audience='customers' then
  insert into public.notifications(user_id,title,body,link)
  select p.id,btrim(notice_title),btrim(notice_body),nullif(btrim(notice_link),'') from public.profiles p where p.role in ('CUSTOMER','EDITOR') and p.status='active';
 else
  insert into public.notifications(user_id,title,body,link)
  select p.id,btrim(notice_title),btrim(notice_body),nullif(btrim(notice_link),'') from public.profiles p where p.status='active';
 end if;
 get diagnostics inserted_count=row_count;
 insert into public.audit_logs(actor_id,action,entity_type,entity_id,metadata)
 values((select auth.uid()),'founder.notification.broadcast','notification',null,jsonb_build_object('audience',audience,'organization_id',target_organization,'recipients',inserted_count,'title',notice_title));
 return inserted_count;
end $$;
revoke all on function private.founder_broadcast_notification_impl(text,uuid,text,text,text) from public,anon,authenticated;
create or replace function public.founder_broadcast_notification(audience text,target_organization uuid,notice_title text,notice_body text,notice_link text default null)
returns integer language sql security invoker set search_path='' as $$select private.founder_broadcast_notification_impl(audience,target_organization,notice_title,notice_body,notice_link)$$;
revoke all on function public.founder_broadcast_notification(text,uuid,text,text,text) from public,anon;
grant execute on function public.founder_broadcast_notification(text,uuid,text,text,text) to authenticated;
grant execute on function private.founder_broadcast_notification_impl(text,uuid,text,text,text) to authenticated;

create or replace function private.founder_platform_overview_impl()
returns jsonb language plpgsql security definer set search_path='' as $$
begin
 if not private.is_super_admin() then raise exception 'SUPER_ADMIN_REQUIRED';end if;
 return jsonb_build_object(
  'users',jsonb_build_object('total',(select count(*) from public.profiles),'active',(select count(*) from public.profiles where status='active'),'admins',(select count(*) from public.profiles where role in ('ADMIN','SUPER_ADMIN'))),
  'workspaces',jsonb_build_object('total',(select count(*) from public.organizations),'active',(select count(*) from public.organizations where status='active'),'suspended',(select count(*) from public.organizations where status='suspended')),
  'store',jsonb_build_object('products',(select count(*) from public.products),'services',(select count(*) from public.services),'orders',(select count(*) from public.orders),'approved_revenue',(select coalesce(sum(total),0) from public.orders where payment_status='approved')),
  'operations',jsonb_build_object('pending_workspace_requests',(select count(*) from public.workspace_requests where status='pending_review'),'pending_renewals',(select count(*) from public.subscription_renewal_requests where status='under_review'),'open_feedback',(select count(*) from public.platform_feedback where status in ('new','reviewing','planned')),'privacy_requests',(select count(*) from public.data_privacy_requests where status in ('requested','processing'))),
  'generated_at',now()
 );
end $$;
revoke all on function private.founder_platform_overview_impl() from public,anon,authenticated;
create or replace function public.founder_platform_overview() returns jsonb language sql security invoker set search_path='' as $$select private.founder_platform_overview_impl()$$;
revoke all on function public.founder_platform_overview() from public,anon;
grant execute on function public.founder_platform_overview() to authenticated;
grant execute on function private.founder_platform_overview_impl() to authenticated;
