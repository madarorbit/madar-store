create table public.payment_methods (
  id uuid primary key default gen_random_uuid(),
  code text not null unique check(code ~ '^[A-Z0-9_-]{3,40}$'),
  name text not null check(char_length(name) between 2 and 120),
  method_type text not null check(method_type in ('wallet','bank')),
  account_name text,
  account_identifier text,
  instructions text,
  currency text not null default 'YER' check(currency in ('YER','SAR','USD')),
  is_active boolean not null default false,
  sort_order integer not null default 100,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check(not is_active or (account_name is not null and account_identifier is not null))
);
insert into public.payment_methods(code,name,method_type,account_name,account_identifier,instructions,currency,is_active,sort_order) values
 ('QUTAIBI','بنك القطيبي','bank','مَدار','003441850','حوّل المبلغ إلى الحساب ثم ارفع صورة أو PDF لإثبات العملية.','YER',true,10),
 ('SHILAN','محفظة شلن','wallet',null,null,'يتم تفعيل الطريقة بعد إضافة رقم المحفظة من لوحة الإدارة.','YER',false,20),
 ('OM_FLOOS','محفظة أم فلوس','wallet',null,null,'يتم تفعيل الطريقة بعد إضافة رقم المحفظة من لوحة الإدارة.','YER',false,30),
 ('ONE_CASH','ون كاش','wallet',null,null,'يتم تفعيل الطريقة بعد إضافة رقم المحفظة من لوحة الإدارة.','YER',false,40);
create trigger payment_methods_updated before update on public.payment_methods for each row execute function public.touch_updated_at();

alter table public.subscription_plans
 add column description text,
 add column member_limit integer not null default 1 check(member_limit>0),
 add column product_limit integer not null default 100 check(product_limit>0),
 add column storage_mb integer not null default 250 check(storage_mb>0),
 add column orby_daily_limit integer not null default 20 check(orby_daily_limit>0),
 add column import_rows_limit integer not null default 500 check(import_rows_limit between 1 and 5000),
 add column grace_days integer not null default 7 check(grace_days between 0 and 60),
 add column features jsonb not null default '{}'::jsonb check(jsonb_typeof(features)='object');
update public.subscription_plans set
 description=case organization_type when 'INDIVIDUAL' then 'لبداية فردية وتشغيل تجارة صغيرة.' when 'MERCHANT' then 'للمتاجر والفرق الصغيرة.' else 'للشركات والعمليات الأكبر.' end,
 member_limit=case organization_type when 'INDIVIDUAL' then 1 when 'MERCHANT' then 5 else 20 end,
 product_limit=case organization_type when 'INDIVIDUAL' then 100 when 'MERCHANT' then 1000 else 10000 end,
 storage_mb=case organization_type when 'INDIVIDUAL' then 250 when 'MERCHANT' then 2048 else 10240 end,
 orby_daily_limit=case organization_type when 'INDIVIDUAL' then 20 when 'MERCHANT' then 50 else 100 end,
 import_rows_limit=case organization_type when 'INDIVIDUAL' then 500 when 'MERCHANT' then 1000 else 5000 end,
 grace_days=7,
 features=jsonb_build_object('analytics',true,'orby',true,'imports',true,'team',organization_type<>'INDIVIDUAL');

alter table public.workspace_subscriptions
 add column is_beta_founder boolean not null default false,
 add column grace_ends_at timestamptz,
 add column renewal_count integer not null default 0 check(renewal_count>=0),
 add column last_payment_at timestamptz;
update public.workspace_subscriptions s set grace_ends_at=s.ends_at+(p.grace_days||' days')::interval from public.subscription_plans p where p.id=s.plan_id and s.grace_ends_at is null;

create table public.beta_founder_slots (
  ordinal integer primary key check(ordinal between 1 and 10),
  user_id uuid unique references auth.users(id) on delete set null,
  request_id uuid unique references public.workspace_requests(id) on delete set null,
  organization_id uuid unique references public.organizations(id) on delete set null,
  status text not null default 'available' check(status in ('available','reserved','activated')),
  reserved_at timestamptz,
  reserved_until timestamptz,
  activated_at timestamptz,
  updated_at timestamptz not null default now()
);
insert into public.beta_founder_slots(ordinal) select generate_series(1,10);
create trigger beta_founder_slots_updated before update on public.beta_founder_slots for each row execute function public.touch_updated_at();

alter table public.workspace_requests
 add column beta_slot_ordinal integer references public.beta_founder_slots(ordinal) on delete set null,
 add column payment_method_id uuid references public.payment_methods(id) on delete set null;
create index workspace_requests_payment_method_idx on public.workspace_requests(payment_method_id);

create table public.workspace_payment_submissions (
  id uuid primary key default gen_random_uuid(),
  workspace_request_id uuid not null references public.workspace_requests(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  payment_method_id uuid not null references public.payment_methods(id) on delete restrict,
  amount numeric(12,2) not null check(amount>=0),
  currency text not null check(currency in ('YER','SAR','USD')),
  payment_reference text not null check(char_length(payment_reference) between 3 and 120),
  storage_path text not null,
  original_filename text not null,
  mime_type text not null check(mime_type in ('image/jpeg','image/png','image/webp','application/pdf')),
  file_size bigint not null check(file_size between 1 and 10485760),
  status text not null default 'under_review' check(status in ('under_review','approved','rejected')),
  reviewed_by uuid references auth.users(id) on delete set null,
  reviewed_at timestamptz,
  review_note text,
  created_at timestamptz not null default now()
);
create unique index workspace_payment_one_review_idx on public.workspace_payment_submissions(workspace_request_id) where status='under_review';
create index workspace_payment_user_idx on public.workspace_payment_submissions(user_id,created_at desc);
create index workspace_payment_method_idx on public.workspace_payment_submissions(payment_method_id);
create index workspace_payment_reviewer_idx on public.workspace_payment_submissions(reviewed_by);

create table public.subscription_renewal_requests (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  subscription_id uuid not null references public.workspace_subscriptions(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  payment_method_id uuid not null references public.payment_methods(id) on delete restrict,
  amount numeric(12,2) not null check(amount>=0),
  currency text not null check(currency in ('YER','SAR','USD')),
  payment_reference text not null check(char_length(payment_reference) between 3 and 120),
  storage_path text not null,
  original_filename text not null,
  mime_type text not null check(mime_type in ('image/jpeg','image/png','image/webp','application/pdf')),
  file_size bigint not null check(file_size between 1 and 10485760),
  status text not null default 'under_review' check(status in ('under_review','approved','rejected')),
  reviewed_by uuid references auth.users(id) on delete set null,
  reviewed_at timestamptz,
  review_note text,
  created_at timestamptz not null default now()
);
create unique index subscription_renewal_one_review_idx on public.subscription_renewal_requests(organization_id) where status='under_review';
create index subscription_renewal_subscription_idx on public.subscription_renewal_requests(subscription_id);
create index subscription_renewal_user_idx on public.subscription_renewal_requests(user_id,created_at desc);
create index subscription_renewal_method_idx on public.subscription_renewal_requests(payment_method_id);
create index subscription_renewal_reviewer_idx on public.subscription_renewal_requests(reviewed_by);
