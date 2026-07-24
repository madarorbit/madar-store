-- Phase 4.4: ORBY conversations, quotas, proactive insights and confirmed actions.

create table public.orby_conversations (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null check(char_length(title) between 1 and 160),
  status text not null default 'active' check(status in ('active','archived')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  last_message_at timestamptz not null default now()
);
create index orby_conversations_user_recent_idx on public.orby_conversations(user_id,organization_id,last_message_at desc);

create table public.orby_messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.orby_conversations(id) on delete cascade,
  organization_id uuid not null references public.organizations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null check(role in ('user','assistant')),
  mode text not null check(mode in ('ANALYZE','PLAN','REPORT','MARKETING')),
  content text not null check(char_length(content) between 1 and 20000),
  source text not null default 'ai' check(source in ('ai','smart-fallback')),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index orby_messages_conversation_idx on public.orby_messages(conversation_id,created_at);
create index orby_messages_org_user_idx on public.orby_messages(organization_id,user_id,created_at desc);

create table public.orby_usage_daily (
  organization_id uuid not null references public.organizations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  usage_date date not null default current_date,
  requests integer not null default 0 check(requests>=0),
  input_characters integer not null default 0 check(input_characters>=0),
  output_characters integer not null default 0 check(output_characters>=0),
  updated_at timestamptz not null default now(),
  primary key(organization_id,user_id,usage_date)
);

create table public.orby_insights (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  insight_type text not null,
  severity text not null check(severity in ('info','warning','critical')),
  fingerprint text not null,
  title text not null check(char_length(title) between 1 and 180),
  body text not null check(char_length(body) between 1 and 1000),
  action_path text,
  source_data jsonb not null default '{}'::jsonb,
  status text not null default 'active' check(status in ('active','dismissed','resolved')),
  generated_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(organization_id,fingerprint)
);
create index orby_insights_org_status_idx on public.orby_insights(organization_id,status,severity,generated_at desc);

create table public.orby_action_drafts (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  action_type text not null check(action_type in ('create_task')),
  payload jsonb not null check(jsonb_typeof(payload)='object'),
  status text not null default 'draft' check(status in ('draft','executed','cancelled')),
  created_at timestamptz not null default now(),
  confirmed_at timestamptz,
  executed_entity_id uuid
);
create index orby_action_drafts_user_idx on public.orby_action_drafts(user_id,organization_id,status,created_at desc);

create or replace function private.consume_orby_quota_impl(target_organization uuid,submitted_characters integer)
returns jsonb
language plpgsql security definer set search_path=''
as $$
declare current_user_id uuid:=(select auth.uid());usage_row public.orby_usage_daily%rowtype;
begin
 if current_user_id is null or not private.is_organization_member(target_organization) then raise exception 'NOT_AUTHORIZED';end if;
 if submitted_characters<1 or submitted_characters>12000 then raise exception 'INVALID_PROMPT_SIZE';end if;
 insert into public.orby_usage_daily(organization_id,user_id,usage_date,requests,input_characters)
 values(target_organization,current_user_id,current_date,1,submitted_characters)
 on conflict(organization_id,user_id,usage_date) do update
 set requests=public.orby_usage_daily.requests+1,input_characters=public.orby_usage_daily.input_characters+excluded.input_characters,updated_at=now()
 where public.orby_usage_daily.requests<20 and public.orby_usage_daily.input_characters+excluded.input_characters<=100000
 returning * into usage_row;
 if usage_row.user_id is null then raise exception 'ORBY_DAILY_LIMIT';end if;
 return jsonb_build_object('requests',usage_row.requests,'remaining',greatest(20-usage_row.requests,0),'input_characters',usage_row.input_characters);
end $$;
revoke all on function private.consume_orby_quota_impl(uuid,integer) from public,anon,authenticated;
create or replace function public.consume_orby_quota(target_organization uuid,submitted_characters integer)
returns jsonb language sql security invoker set search_path='' as $$select private.consume_orby_quota_impl(target_organization,submitted_characters)$$;
revoke all on function public.consume_orby_quota(uuid,integer) from public,anon;
grant execute on function public.consume_orby_quota(uuid,integer) to authenticated;
grant execute on function private.consume_orby_quota_impl(uuid,integer) to authenticated;

create or replace function private.orby_business_context_impl(target_organization uuid)
returns jsonb
language plpgsql security definer set search_path=''
as $$
declare analytics jsonb;stock jsonb;tasks jsonb;customers jsonb;
begin
 if (select auth.uid()) is null or not private.can_manage_business(target_organization,'financials') then raise exception 'NOT_AUTHORIZED';end if;
 analytics:=private.business_analytics_impl(target_organization,current_date-29,current_date);
 select coalesce(jsonb_agg(jsonb_build_object('id',p.id,'name',p.name,'stock',p.stock_quantity,'threshold',p.low_stock_threshold) order by p.stock_quantity asc),'[]'::jsonb)
 into stock from (select * from public.business_products where organization_id=target_organization and is_active and stock_quantity<=low_stock_threshold order by stock_quantity limit 20) p;
 select coalesce(jsonb_agg(jsonb_build_object('id',t.id,'title',t.title,'priority',t.priority,'due_at',t.due_at) order by t.due_at),'[]'::jsonb)
 into tasks from (select * from public.business_tasks where organization_id=target_organization and status in ('todo','in_progress') and due_at<now() order by due_at limit 20) t;
 select coalesce(jsonb_agg(jsonb_build_object('id',c.id,'name',c.name,'total_spent',c.total_spent,'last_order_at',c.last_order_at) order by c.total_spent desc),'[]'::jsonb)
 into customers from (select * from public.business_customers where organization_id=target_organization and status<>'inactive' and (last_order_at is null or last_order_at<now()-interval '60 days') order by total_spent desc limit 20) c;
 return jsonb_build_object('analytics',analytics,'low_stock',stock,'overdue_tasks',tasks,'inactive_customers',customers);
end $$;
revoke all on function private.orby_business_context_impl(uuid) from public,anon,authenticated;
create or replace function public.orby_business_context(target_organization uuid)
returns jsonb language sql security invoker set search_path='' as $$select private.orby_business_context_impl(target_organization)$$;
revoke all on function public.orby_business_context(uuid) from public,anon;
grant execute on function public.orby_business_context(uuid) to authenticated;
grant execute on function private.orby_business_context_impl(uuid) to authenticated;

create or replace function private.save_orby_exchange_impl(target_organization uuid,target_conversation uuid,conversation_title text,conversation_mode text,user_prompt text,assistant_response text,response_source text,response_metadata jsonb)
returns uuid
language plpgsql security definer set search_path=''
as $$
declare current_user_id uuid:=(select auth.uid());conversation_id uuid:=target_conversation;
begin
 if current_user_id is null or not private.is_organization_member(target_organization) then raise exception 'NOT_AUTHORIZED';end if;
 if conversation_mode not in ('ANALYZE','PLAN','REPORT','MARKETING') or response_source not in ('ai','smart-fallback') then raise exception 'INVALID_ORBY_EXCHANGE';end if;
 if char_length(user_prompt) not between 1 and 12000 or char_length(assistant_response) not between 1 and 20000 then raise exception 'INVALID_ORBY_EXCHANGE';end if;
 if conversation_id is null then
  insert into public.orby_conversations(organization_id,user_id,title) values(target_organization,current_user_id,left(coalesce(nullif(btrim(conversation_title),''),user_prompt),160)) returning id into conversation_id;
 elsif not exists(select 1 from public.orby_conversations where id=conversation_id and organization_id=target_organization and user_id=current_user_id and status='active') then raise exception 'CONVERSATION_NOT_FOUND';
 end if;
 insert into public.orby_messages(conversation_id,organization_id,user_id,role,mode,content,source) values(conversation_id,target_organization,current_user_id,'user',conversation_mode,user_prompt,'ai');
 insert into public.orby_messages(conversation_id,organization_id,user_id,role,mode,content,source,metadata) values(conversation_id,target_organization,current_user_id,'assistant',conversation_mode,assistant_response,response_source,coalesce(response_metadata,'{}'::jsonb));
 update public.orby_conversations set last_message_at=now(),updated_at=now() where id=conversation_id;
 update public.orby_usage_daily set output_characters=output_characters+char_length(assistant_response),updated_at=now() where organization_id=target_organization and user_id=current_user_id and usage_date=current_date;
 return conversation_id;
end $$;
revoke all on function private.save_orby_exchange_impl(uuid,uuid,text,text,text,text,text,jsonb) from public,anon,authenticated;
create or replace function public.save_orby_exchange(target_organization uuid,target_conversation uuid,conversation_title text,conversation_mode text,user_prompt text,assistant_response text,response_source text,response_metadata jsonb default '{}'::jsonb)
returns uuid language sql security invoker set search_path='' as $$select private.save_orby_exchange_impl(target_organization,target_conversation,conversation_title,conversation_mode,user_prompt,assistant_response,response_source,response_metadata)$$;
revoke all on function public.save_orby_exchange(uuid,uuid,text,text,text,text,text,jsonb) from public,anon;
grant execute on function public.save_orby_exchange(uuid,uuid,text,text,text,text,text,jsonb) to authenticated;
grant execute on function private.save_orby_exchange_impl(uuid,uuid,text,text,text,text,text,jsonb) to authenticated;

create or replace function private.refresh_orby_insights_impl(target_organization uuid)
returns integer
language plpgsql security definer set search_path=''
as $$
declare data jsonb;count_added integer:=0;inactive_count integer;
begin
 if (select auth.uid()) is null or not private.can_manage_business(target_organization,'financials') then raise exception 'NOT_AUTHORIZED';end if;
 data:=private.business_analytics_impl(target_organization,current_date-29,current_date);
 update public.orby_insights set status='resolved',updated_at=now() where organization_id=target_organization and status='active';
 if (data#>>'{kpis,out_of_stock}')::integer>0 then
  insert into public.orby_insights(organization_id,insight_type,severity,fingerprint,title,body,action_path,source_data,status,generated_at)
  values(target_organization,'OUT_OF_STOCK','critical','out-of-stock','منتجات نافدة من المخزون','لديك '||(data#>>'{kpis,out_of_stock}')||' منتجًا نافدًا يحتاج إلى إجراء.','/workspace/inventory',data#>'{kpis}','active',now())
  on conflict(organization_id,fingerprint) do update set severity=excluded.severity,title=excluded.title,body=excluded.body,action_path=excluded.action_path,source_data=excluded.source_data,status='active',generated_at=now(),updated_at=now();count_added:=count_added+1;
 end if;
 if (data#>>'{kpis,low_stock}')::integer>0 then
  insert into public.orby_insights(organization_id,insight_type,severity,fingerprint,title,body,action_path,source_data,status,generated_at)
  values(target_organization,'LOW_STOCK','warning','low-stock','المخزون يقترب من النفاد','وصل '||(data#>>'{kpis,low_stock}')||' منتجًا إلى حد التنبيه.','/workspace/inventory',data#>'{kpis}','active',now())
  on conflict(organization_id,fingerprint) do update set body=excluded.body,source_data=excluded.source_data,status='active',generated_at=now(),updated_at=now();count_added:=count_added+1;
 end if;
 if (data#>>'{kpis,overdue_tasks}')::integer>0 then
  insert into public.orby_insights(organization_id,insight_type,severity,fingerprint,title,body,action_path,source_data,status,generated_at)
  values(target_organization,'OVERDUE_TASKS','warning','overdue-tasks','مهام متأخرة','هناك '||(data#>>'{kpis,overdue_tasks}')||' مهمة تجاوزت موعدها.','/workspace/tasks',data#>'{kpis}','active',now())
  on conflict(organization_id,fingerprint) do update set body=excluded.body,source_data=excluded.source_data,status='active',generated_at=now(),updated_at=now();count_added:=count_added+1;
 end if;
 if (data#>>'{comparison,revenue_change}')::numeric<=-10 then
  insert into public.orby_insights(organization_id,insight_type,severity,fingerprint,title,body,action_path,source_data,status,generated_at)
  values(target_organization,'REVENUE_DECLINE','critical','revenue-decline','انخفاض ملحوظ في المبيعات','انخفضت المبيعات '||abs((data#>>'{comparison,revenue_change}')::numeric)||'% عن الفترة السابقة.','/workspace/analytics',data#>'{comparison}','active',now())
  on conflict(organization_id,fingerprint) do update set body=excluded.body,source_data=excluded.source_data,status='active',generated_at=now(),updated_at=now();count_added:=count_added+1;
 end if;
 if (data#>>'{comparison,expenses_change}')::numeric>=25 then
  insert into public.orby_insights(organization_id,insight_type,severity,fingerprint,title,body,action_path,source_data,status,generated_at)
  values(target_organization,'EXPENSE_SPIKE','warning','expense-spike','ارتفاع المصروفات','ارتفعت المصروفات '||(data#>>'{comparison,expenses_change}')||'% عن الفترة السابقة.','/workspace/expenses',data#>'{comparison}','active',now())
  on conflict(organization_id,fingerprint) do update set body=excluded.body,source_data=excluded.source_data,status='active',generated_at=now(),updated_at=now();count_added:=count_added+1;
 end if;
 select count(*) into inactive_count from public.business_customers where organization_id=target_organization and status<>'inactive' and (last_order_at is null or last_order_at<now()-interval '60 days');
 if inactive_count>0 then
  insert into public.orby_insights(organization_id,insight_type,severity,fingerprint,title,body,action_path,source_data,status,generated_at)
  values(target_organization,'INACTIVE_CUSTOMERS','info','inactive-customers','عملاء يحتاجون إعادة تواصل','لديك '||inactive_count||' عميلًا لم يشتروا خلال 60 يومًا أو لم تسجل لهم عملية شراء.','/workspace/customers',jsonb_build_object('count',inactive_count),'active',now())
  on conflict(organization_id,fingerprint) do update set body=excluded.body,source_data=excluded.source_data,status='active',generated_at=now(),updated_at=now();count_added:=count_added+1;
 end if;
 return count_added;
end $$;
revoke all on function private.refresh_orby_insights_impl(uuid) from public,anon,authenticated;
create or replace function public.refresh_orby_insights(target_organization uuid)
returns integer language sql security invoker set search_path='' as $$select private.refresh_orby_insights_impl(target_organization)$$;
revoke all on function public.refresh_orby_insights(uuid) from public,anon;
grant execute on function public.refresh_orby_insights(uuid) to authenticated;
grant execute on function private.refresh_orby_insights_impl(uuid) to authenticated;

create or replace function private.dismiss_orby_insight_impl(target_insight uuid)
returns void language plpgsql security definer set search_path='' as $$
declare current_user_id uuid:=(select auth.uid());target_org uuid;
begin select organization_id into target_org from public.orby_insights where id=target_insight;if target_org is null then raise exception 'INSIGHT_NOT_FOUND';end if;if current_user_id is null or not private.is_organization_member(target_org) then raise exception 'NOT_AUTHORIZED';end if;update public.orby_insights set status='dismissed',updated_at=now() where id=target_insight;end $$;
revoke all on function private.dismiss_orby_insight_impl(uuid) from public,anon,authenticated;
create or replace function public.dismiss_orby_insight(target_insight uuid) returns void language sql security invoker set search_path='' as $$select private.dismiss_orby_insight_impl(target_insight)$$;
revoke all on function public.dismiss_orby_insight(uuid) from public,anon;grant execute on function public.dismiss_orby_insight(uuid) to authenticated;grant execute on function private.dismiss_orby_insight_impl(uuid) to authenticated;

create or replace function private.create_orby_task_draft_impl(target_organization uuid,task_title text,task_description text,task_due_at timestamptz,task_priority text)
returns uuid language plpgsql security definer set search_path='' as $$
declare current_user_id uuid:=(select auth.uid());draft_id uuid;
begin if current_user_id is null or not private.can_manage_business(target_organization,'tasks') then raise exception 'NOT_AUTHORIZED';end if;if char_length(btrim(task_title)) not between 1 and 220 or task_priority not in ('low','medium','high','urgent') then raise exception 'INVALID_TASK_DRAFT';end if;insert into public.orby_action_drafts(organization_id,user_id,action_type,payload) values(target_organization,current_user_id,'create_task',jsonb_build_object('title',btrim(task_title),'description',nullif(btrim(task_description),''),'due_at',task_due_at,'priority',task_priority)) returning id into draft_id;return draft_id;end $$;
revoke all on function private.create_orby_task_draft_impl(uuid,text,text,timestamptz,text) from public,anon,authenticated;
create or replace function public.create_orby_task_draft(target_organization uuid,task_title text,task_description text default null,task_due_at timestamptz default null,task_priority text default 'medium') returns uuid language sql security invoker set search_path='' as $$select private.create_orby_task_draft_impl(target_organization,task_title,task_description,task_due_at,task_priority)$$;
revoke all on function public.create_orby_task_draft(uuid,text,text,timestamptz,text) from public,anon;grant execute on function public.create_orby_task_draft(uuid,text,text,timestamptz,text) to authenticated;grant execute on function private.create_orby_task_draft_impl(uuid,text,text,timestamptz,text) to authenticated;

create or replace function private.confirm_orby_action_impl(target_draft uuid)
returns uuid language plpgsql security definer set search_path='' as $$
declare current_user_id uuid:=(select auth.uid());draft public.orby_action_drafts%rowtype;task_id uuid;
begin select * into draft from public.orby_action_drafts where id=target_draft for update;if not found or draft.user_id<>current_user_id or draft.status<>'draft' then raise exception 'DRAFT_NOT_AVAILABLE';end if;if not private.can_manage_business(draft.organization_id,'tasks') then raise exception 'NOT_AUTHORIZED';end if;insert into public.business_tasks(organization_id,title,description,priority,due_at,created_by) values(draft.organization_id,draft.payload->>'title',nullif(draft.payload->>'description',''),coalesce(draft.payload->>'priority','medium'),nullif(draft.payload->>'due_at','')::timestamptz,current_user_id) returning id into task_id;update public.orby_action_drafts set status='executed',confirmed_at=now(),executed_entity_id=task_id where id=target_draft;insert into public.audit_logs(actor_id,action,entity_type,entity_id,metadata) values(current_user_id,'orby.action.confirmed','business_task',task_id,jsonb_build_object('draft_id',target_draft,'organization_id',draft.organization_id));return task_id;end $$;
revoke all on function private.confirm_orby_action_impl(uuid) from public,anon,authenticated;
create or replace function public.confirm_orby_action(target_draft uuid) returns uuid language sql security invoker set search_path='' as $$select private.confirm_orby_action_impl(target_draft)$$;
revoke all on function public.confirm_orby_action(uuid) from public,anon;grant execute on function public.confirm_orby_action(uuid) to authenticated;grant execute on function private.confirm_orby_action_impl(uuid) to authenticated;

alter table public.orby_conversations enable row level security;alter table public.orby_messages enable row level security;alter table public.orby_usage_daily enable row level security;alter table public.orby_insights enable row level security;alter table public.orby_action_drafts enable row level security;
create policy "users read own orby conversations" on public.orby_conversations for select to authenticated using(user_id=(select auth.uid()) and private.is_organization_member(organization_id));
create policy "users read own orby messages" on public.orby_messages for select to authenticated using(user_id=(select auth.uid()) and private.is_organization_member(organization_id));
create policy "users read own orby usage" on public.orby_usage_daily for select to authenticated using(user_id=(select auth.uid()));
create policy "members read orby insights" on public.orby_insights for select to authenticated using(private.is_organization_member(organization_id));
create policy "users read own orby drafts" on public.orby_action_drafts for select to authenticated using(user_id=(select auth.uid()) and private.is_organization_member(organization_id));
create trigger orby_conversations_updated before update on public.orby_conversations for each row execute function public.touch_updated_at();create trigger orby_insights_updated before update on public.orby_insights for each row execute function public.touch_updated_at();
revoke all on table public.orby_conversations,public.orby_messages,public.orby_usage_daily,public.orby_insights,public.orby_action_drafts from anon,authenticated;
grant select on table public.orby_conversations,public.orby_messages,public.orby_usage_daily,public.orby_insights,public.orby_action_drafts to authenticated;
