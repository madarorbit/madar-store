create or replace function private.reserve_beta_slot_impl(target_request uuid)
returns integer language plpgsql security definer set search_path='' as $$
declare current_user_id uuid:=(select auth.uid());slot_number integer;
begin
 update public.beta_founder_slots set status='available',user_id=null,request_id=null,reserved_at=null,reserved_until=null
 where status='reserved' and reserved_until<now();
 if not exists(select 1 from public.workspace_requests where id=target_request and user_id=current_user_id) then raise exception 'NOT_AUTHORIZED';end if;
 select ordinal into slot_number from public.beta_founder_slots where status='available' order by ordinal for update skip locked limit 1;
 if slot_number is null then return null;end if;
 update public.beta_founder_slots set status='reserved',user_id=current_user_id,request_id=target_request,reserved_at=now(),reserved_until=now()+interval '72 hours' where ordinal=slot_number;
 update public.workspace_requests set beta_slot_ordinal=slot_number,status='pending_review' where id=target_request and user_id=current_user_id;
 return slot_number;
end $$;
revoke all on function private.reserve_beta_slot_impl(uuid) from public,anon,authenticated;

create or replace function private.create_workspace_request_impl(workspace_name text,workspace_slug text,workspace_type public.organization_type)
returns public.workspace_requests language plpgsql security definer set search_path='' as $$
declare created public.workspace_requests;slot_number integer;
begin
 if (select auth.uid()) is null then raise exception 'Authentication required';end if;
 if workspace_type='STUDENT' then raise exception 'Student workspace does not require payment';end if;
 if workspace_slug !~ '^[a-z0-9][a-z0-9-]{1,78}[a-z0-9]$' then raise exception 'Invalid slug';end if;
 if exists(select 1 from public.organization_members m join public.organizations o on o.id=m.organization_id where m.user_id=(select auth.uid()) and o.type<>'STUDENT') then raise exception 'Business workspace already exists';end if;
 if exists(select 1 from public.workspace_requests where user_id=(select auth.uid()) and status in ('pending_payment','pending_review')) then raise exception 'A pending request already exists';end if;
 insert into public.workspace_requests(user_id,name,slug,type) values((select auth.uid()),trim(workspace_name),workspace_slug,workspace_type) returning * into created;
 slot_number:=private.reserve_beta_slot_impl(created.id);
 select * into created from public.workspace_requests where id=created.id;
 return created;
end $$;

create or replace function public.activate_workspace_subscription()
returns trigger language plpgsql security definer set search_path='' as $$
declare selected_plan public.subscription_plans%rowtype;subscription_end timestamptz;beta boolean:=false;
begin
 if new.status='approved' and old.status is distinct from new.status and new.organization_id is not null then
  select * into selected_plan from public.subscription_plans where id=new.plan_id;
  beta:=new.beta_slot_ordinal is not null;
  subscription_end:=now()+case when beta then interval '90 days' else (selected_plan.billing_months||' months')::interval end;
  insert into public.workspace_subscriptions(organization_id,plan_id,ends_at,grace_ends_at,approved_request_id,is_beta_founder)
  values(new.organization_id,new.plan_id,subscription_end,subscription_end+(selected_plan.grace_days||' days')::interval,new.id,beta)
  on conflict(approved_request_id) do nothing;
  if beta then update public.beta_founder_slots set status='activated',organization_id=new.organization_id,activated_at=now(),reserved_until=null where ordinal=new.beta_slot_ordinal and request_id=new.id;end if;
 end if;
 return new;
end $$;
revoke all on function public.activate_workspace_subscription() from public,anon,authenticated;

create or replace function private.review_workspace_request_impl(target_request uuid,decision text,reason text default null)
returns public.workspace_requests language plpgsql security definer set search_path='' as $$
declare request public.workspace_requests;created public.organizations;
begin
 if not (select private.is_admin()) then raise exception 'Admin required';end if;
 select * into request from public.workspace_requests where id=target_request for update;
 if request.id is null or request.status<>'pending_review' then raise exception 'Request is not reviewable';end if;
 if decision='approve' then
  if request.beta_slot_ordinal is null and not exists(select 1 from public.workspace_payment_submissions where workspace_request_id=request.id and status='under_review') then raise exception 'PAYMENT_PROOF_REQUIRED';end if;
  insert into public.organizations(name,slug,type,created_by) values(request.name,request.slug,request.type,request.user_id) returning * into created;
  insert into public.organization_members(organization_id,user_id,role) values(created.id,request.user_id,'OWNER');
  update public.workspace_payment_submissions set status='approved',reviewed_by=(select auth.uid()),reviewed_at=now() where workspace_request_id=request.id and status='under_review';
  update public.workspace_requests set status='approved',reviewed_by=(select auth.uid()),reviewed_at=now(),organization_id=created.id,rejection_reason=null where id=request.id returning * into request;
 elsif decision='reject' then
  update public.workspace_payment_submissions set status='rejected',reviewed_by=(select auth.uid()),reviewed_at=now(),review_note=nullif(trim(reason),'') where workspace_request_id=request.id and status='under_review';
  update public.beta_founder_slots set status='available',user_id=null,request_id=null,reserved_at=null,reserved_until=null where request_id=request.id and status='reserved';
  update public.workspace_requests set status='rejected',reviewed_by=(select auth.uid()),reviewed_at=now(),rejection_reason=nullif(trim(reason),'') where id=request.id returning * into request;
 else raise exception 'Invalid decision';end if;
 return request;
end $$;

create or replace function private.submit_workspace_payment_v2_impl(target_request uuid,target_method uuid,reference text,proof_path text,proof_name text,proof_mime text,proof_size bigint)
returns uuid language plpgsql security definer set search_path='' as $$
declare request public.workspace_requests;method public.payment_methods%rowtype;submission_id uuid;plan public.subscription_plans%rowtype;
begin
 select * into request from public.workspace_requests where id=target_request and user_id=(select auth.uid()) for update;
 if request.id is null or request.status<>'pending_payment' or request.beta_slot_ordinal is not null then raise exception 'REQUEST_NOT_PAYABLE';end if;
 select * into method from public.payment_methods where id=target_method and is_active;
 if method.id is null then raise exception 'PAYMENT_METHOD_UNAVAILABLE';end if;
 select * into plan from public.subscription_plans where id=request.plan_id and is_active;
 if plan.id is null then raise exception 'PLAN_NOT_AVAILABLE';end if;
 if char_length(trim(reference)) not between 3 and 120 or proof_mime not in ('image/jpeg','image/png','image/webp','application/pdf') or proof_size not between 1 and 10485760 then raise exception 'INVALID_PAYMENT_PROOF';end if;
 insert into public.workspace_payment_submissions(workspace_request_id,user_id,payment_method_id,amount,currency,payment_reference,storage_path,original_filename,mime_type,file_size)
 values(request.id,(select auth.uid()),method.id,plan.price,plan.currency,trim(reference),proof_path,proof_name,proof_mime,proof_size) returning id into submission_id;
 update public.workspace_requests set payment_method_id=method.id,payment_reference=trim(reference),payment_submitted_at=now(),status='pending_review' where id=request.id;
 return submission_id;
end $$;
revoke all on function private.submit_workspace_payment_v2_impl(uuid,uuid,text,text,text,text,bigint) from public,anon,authenticated;
create or replace function public.submit_workspace_payment_v2(target_request uuid,target_method uuid,reference text,proof_path text,proof_name text,proof_mime text,proof_size bigint)
returns uuid language sql security invoker set search_path='' as $$select private.submit_workspace_payment_v2_impl(target_request,target_method,reference,proof_path,proof_name,proof_mime,proof_size)$$;
revoke all on function public.submit_workspace_payment_v2(uuid,uuid,text,text,text,text,bigint) from public,anon;
grant execute on function public.submit_workspace_payment_v2(uuid,uuid,text,text,text,text,bigint) to authenticated;
grant execute on function private.submit_workspace_payment_v2_impl(uuid,uuid,text,text,text,text,bigint) to authenticated;
