-- Phase 4.6: Beta feedback, privacy requests and tenant-safe activity history.

create table public.platform_feedback (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  organization_id uuid references public.organizations(id) on delete cascade,
  feedback_type text not null check(feedback_type in ('bug','suggestion','question','rating')),
  severity text not null default 'normal' check(severity in ('low','normal','high','critical')),
  title text not null check(char_length(title) between 3 and 180),
  message text not null check(char_length(message) between 10 and 5000),
  page_path text check(page_path is null or char_length(page_path)<=500),
  attachment_path text,
  attachment_name text,
  attachment_mime text check(attachment_mime is null or attachment_mime in ('image/jpeg','image/png','image/webp','application/pdf')),
  attachment_size bigint check(attachment_size is null or attachment_size between 1 and 10485760),
  rating smallint check(rating is null or rating between 1 and 5),
  status text not null default 'new' check(status in ('new','reviewing','planned','resolved','closed')),
  admin_note text,
  assigned_to uuid references auth.users(id) on delete set null,
  resolved_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index platform_feedback_user_idx on public.platform_feedback(user_id,created_at desc);
create index platform_feedback_org_idx on public.platform_feedback(organization_id,status,created_at desc);
create index platform_feedback_status_idx on public.platform_feedback(status,severity,created_at desc);
create index platform_feedback_assigned_idx on public.platform_feedback(assigned_to);
create trigger platform_feedback_updated before update on public.platform_feedback for each row execute function public.touch_updated_at();

create table public.data_privacy_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  organization_id uuid references public.organizations(id) on delete set null,
  request_type text not null check(request_type in ('export_account','export_workspace','delete_account','delete_workspace')),
  status text not null default 'requested' check(status in ('requested','processing','completed','rejected','cancelled')),
  reason text check(reason is null or char_length(reason)<=2000),
  confirmation_text text,
  admin_note text,
  processed_by uuid references auth.users(id) on delete set null,
  requested_at timestamptz not null default now(),
  processed_at timestamptz,
  updated_at timestamptz not null default now()
);
create unique index data_privacy_one_pending_idx on public.data_privacy_requests(user_id,request_type,coalesce(organization_id,'00000000-0000-0000-0000-000000000000'::uuid)) where status in ('requested','processing');
create index data_privacy_org_idx on public.data_privacy_requests(organization_id,status,requested_at desc);
create index data_privacy_status_idx on public.data_privacy_requests(status,requested_at desc);
create index data_privacy_processed_by_idx on public.data_privacy_requests(processed_by);
create trigger data_privacy_requests_updated before update on public.data_privacy_requests for each row execute function public.touch_updated_at();

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('feedback-attachments','feedback-attachments',false,10485760,array['image/jpeg','image/png','image/webp','application/pdf'])
on conflict(id) do update set public=false,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;

create or replace function private.create_privacy_request_impl(target_organization uuid,request_kind text,request_reason text,confirmation text)
returns uuid language plpgsql security definer set search_path='' as $$
declare current_user_id uuid:=(select auth.uid());request_id uuid;
begin
 if current_user_id is null then raise exception 'AUTHENTICATION_REQUIRED';end if;
 if request_kind not in ('export_account','export_workspace','delete_account','delete_workspace') then raise exception 'INVALID_REQUEST_TYPE';end if;
 if request_kind in ('export_workspace','delete_workspace') then
  if target_organization is null or not private.has_organization_role(target_organization,array['OWNER']::public.organization_role[]) then raise exception 'OWNER_REQUIRED';end if;
 else target_organization:=null;end if;
 if request_kind='delete_workspace' and confirmation<>'حذف مساحتي' then raise exception 'INVALID_CONFIRMATION';end if;
 if request_kind='delete_account' and confirmation<>'حذف حسابي' then raise exception 'INVALID_CONFIRMATION';end if;
 insert into public.data_privacy_requests(user_id,organization_id,request_type,reason,confirmation_text)
 values(current_user_id,target_organization,request_kind,nullif(btrim(request_reason),''),nullif(confirmation,'')) returning id into request_id;
 insert into public.audit_logs(actor_id,action,entity_type,entity_id,metadata)
 values(current_user_id,'privacy.request.created','data_privacy_request',request_id,jsonb_build_object('organization_id',target_organization,'request_type',request_kind));
 return request_id;
end $$;
revoke all on function private.create_privacy_request_impl(uuid,text,text,text) from public,anon,authenticated;
create or replace function public.create_privacy_request(target_organization uuid,request_kind text,request_reason text default null,confirmation text default null)
returns uuid language sql security invoker set search_path='' as $$select private.create_privacy_request_impl(target_organization,request_kind,request_reason,confirmation)$$;
revoke all on function public.create_privacy_request(uuid,text,text,text) from public,anon;
grant execute on function public.create_privacy_request(uuid,text,text,text) to authenticated;
grant execute on function private.create_privacy_request_impl(uuid,text,text,text) to authenticated;

create or replace function private.cancel_privacy_request_impl(target_request uuid)
returns void language plpgsql security definer set search_path='' as $$
begin
 update public.data_privacy_requests set status='cancelled' where id=target_request and user_id=(select auth.uid()) and status='requested';
 if not found then raise exception 'REQUEST_NOT_CANCELLABLE';end if;
end $$;
revoke all on function private.cancel_privacy_request_impl(uuid) from public,anon,authenticated;
create or replace function public.cancel_privacy_request(target_request uuid) returns void language sql security invoker set search_path='' as $$select private.cancel_privacy_request_impl(target_request)$$;
revoke all on function public.cancel_privacy_request(uuid) from public,anon;
grant execute on function public.cancel_privacy_request(uuid) to authenticated;
grant execute on function private.cancel_privacy_request_impl(uuid) to authenticated;

create or replace function private.review_privacy_request_impl(target_request uuid,new_status text,note text default null)
returns public.data_privacy_requests language plpgsql security definer set search_path='' as $$
declare request public.data_privacy_requests;
begin
 if not private.is_admin() then raise exception 'ADMIN_REQUIRED';end if;
 if new_status not in ('processing','completed','rejected') then raise exception 'INVALID_STATUS';end if;
 update public.data_privacy_requests set status=new_status,admin_note=nullif(btrim(note),''),processed_by=(select auth.uid()),processed_at=case when new_status in ('completed','rejected') then now() else null end
 where id=target_request and status in ('requested','processing') returning * into request;
 if request.id is null then raise exception 'REQUEST_NOT_REVIEWABLE';end if;
 insert into public.audit_logs(actor_id,action,entity_type,entity_id,metadata)
 values((select auth.uid()),'privacy.request.reviewed','data_privacy_request',request.id,jsonb_build_object('organization_id',request.organization_id,'status',new_status));
 return request;
end $$;
revoke all on function private.review_privacy_request_impl(uuid,text,text) from public,anon,authenticated;
create or replace function public.review_privacy_request(target_request uuid,new_status text,note text default null)
returns public.data_privacy_requests language sql security invoker set search_path='' as $$select private.review_privacy_request_impl(target_request,new_status,note)$$;
revoke all on function public.review_privacy_request(uuid,text,text) from public,anon;
grant execute on function public.review_privacy_request(uuid,text,text) to authenticated;
grant execute on function private.review_privacy_request_impl(uuid,text,text) to authenticated;

create or replace function private.workspace_activity_impl(target_organization uuid,result_limit integer default 100)
returns table(id uuid,actor_id uuid,action text,entity_type text,entity_id uuid,metadata jsonb,created_at timestamptz)
language plpgsql security definer set search_path='' as $$
begin
 if not private.is_organization_member(target_organization) and not private.is_admin() then raise exception 'NOT_AUTHORIZED';end if;
 return query select a.id,a.actor_id,a.action,a.entity_type,a.entity_id,a.metadata,a.created_at
 from public.audit_logs a where a.metadata->>'organization_id'=target_organization::text
 order by a.created_at desc limit least(greatest(coalesce(result_limit,100),1),500);
end $$;
revoke all on function private.workspace_activity_impl(uuid,integer) from public,anon,authenticated;
create or replace function public.workspace_activity(target_organization uuid,result_limit integer default 100)
returns table(id uuid,actor_id uuid,action text,entity_type text,entity_id uuid,metadata jsonb,created_at timestamptz)
language sql security invoker set search_path='' as $$select * from private.workspace_activity_impl(target_organization,result_limit)$$;
revoke all on function public.workspace_activity(uuid,integer) from public,anon;
grant execute on function public.workspace_activity(uuid,integer) to authenticated;
grant execute on function private.workspace_activity_impl(uuid,integer) to authenticated;

alter table public.platform_feedback enable row level security;
alter table public.data_privacy_requests enable row level security;
create policy "users read own feedback" on public.platform_feedback for select to authenticated using(user_id=(select auth.uid()) or private.is_admin());
create policy "users submit feedback" on public.platform_feedback for insert to authenticated with check(user_id=(select auth.uid()) and (organization_id is null or private.is_organization_member(organization_id)));
create policy "admins update feedback" on public.platform_feedback for update to authenticated using(private.is_admin()) with check(private.is_admin());
create policy "users read own privacy requests" on public.data_privacy_requests for select to authenticated using(user_id=(select auth.uid()) or private.is_admin());
revoke all on table public.platform_feedback,public.data_privacy_requests from anon,authenticated;
grant select,insert,update on public.platform_feedback to authenticated;
grant select on public.data_privacy_requests to authenticated;
