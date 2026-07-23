-- Phase 4.1: tenant-safe business operating core.

alter table public.organizations
  add column if not exists currency text not null default 'YER'
    check (currency in ('YER','SAR','USD')),
  add column if not exists industry text,
  add column if not exists onboarding_completed_at timestamptz;

create table if not exists public.organization_member_permissions (
  organization_id uuid not null,
  user_id uuid not null,
  can_manage_products boolean not null default false,
  can_manage_inventory boolean not null default false,
  can_manage_customers boolean not null default false,
  can_manage_sales boolean not null default false,
  can_manage_expenses boolean not null default false,
  can_manage_suppliers boolean not null default false,
  can_manage_tasks boolean not null default false,
  can_view_financials boolean not null default false,
  updated_at timestamptz not null default now(),
  primary key (organization_id,user_id),
  foreign key (organization_id,user_id)
    references public.organization_members(organization_id,user_id)
    on delete cascade
);

create table if not exists public.business_products (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  name text not null check (char_length(btrim(name)) between 1 and 180),
  sku text,
  description text,
  category text,
  cost numeric(14,2) not null default 0 check (cost >= 0),
  price numeric(14,2) not null default 0 check (price >= 0),
  stock_quantity numeric(14,3) not null default 0 check (stock_quantity >= 0),
  low_stock_threshold numeric(14,3) not null default 0 check (low_stock_threshold >= 0),
  is_active boolean not null default true,
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index if not exists business_products_org_sku_unique
  on public.business_products(organization_id,lower(sku))
  where sku is not null and btrim(sku) <> '';
create index if not exists business_products_org_active_idx
  on public.business_products(organization_id,is_active);
create index if not exists business_products_low_stock_idx
  on public.business_products(organization_id,stock_quantity,low_stock_threshold)
  where is_active;

create table if not exists public.business_customers (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  name text not null check (char_length(btrim(name)) between 1 and 180),
  phone text,
  email text,
  address text,
  status text not null default 'active'
    check (status in ('new','active','vip','inactive')),
  notes text,
  total_spent numeric(14,2) not null default 0 check (total_spent >= 0),
  last_order_at timestamptz,
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists business_customers_org_status_idx
  on public.business_customers(organization_id,status);
create index if not exists business_customers_org_phone_idx
  on public.business_customers(organization_id,phone);

create table if not exists public.business_suppliers (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  name text not null check (char_length(btrim(name)) between 1 and 180),
  contact_name text,
  phone text,
  email text,
  address text,
  notes text,
  balance_due numeric(14,2) not null default 0 check (balance_due >= 0),
  is_active boolean not null default true,
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists business_suppliers_org_active_idx
  on public.business_suppliers(organization_id,is_active);

create table if not exists public.business_expenses (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  supplier_id uuid references public.business_suppliers(id) on delete set null,
  title text not null check (char_length(btrim(title)) between 1 and 180),
  category text not null default 'other',
  amount numeric(14,2) not null check (amount > 0),
  currency text not null default 'YER' check (currency in ('YER','SAR','USD')),
  incurred_at date not null default current_date,
  payment_status text not null default 'paid'
    check (payment_status in ('unpaid','partial','paid')),
  notes text,
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists business_expenses_org_date_idx
  on public.business_expenses(organization_id,incurred_at desc);

create table if not exists public.business_sales (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  customer_id uuid references public.business_customers(id) on delete set null,
  sale_number text not null,
  status text not null default 'completed'
    check (status in ('draft','completed','cancelled','refunded')),
  payment_status text not null default 'paid'
    check (payment_status in ('unpaid','partial','paid','refunded')),
  subtotal numeric(14,2) not null default 0 check (subtotal >= 0),
  discount_total numeric(14,2) not null default 0 check (discount_total >= 0),
  total numeric(14,2) not null default 0 check (total >= 0),
  currency text not null default 'YER' check (currency in ('YER','SAR','USD')),
  notes text,
  sold_at timestamptz not null default now(),
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id,sale_number),
  check (discount_total <= subtotal),
  check (total = subtotal - discount_total)
);
create index if not exists business_sales_org_date_idx
  on public.business_sales(organization_id,sold_at desc);
create index if not exists business_sales_customer_idx
  on public.business_sales(customer_id,sold_at desc);

create table if not exists public.business_sale_items (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  sale_id uuid not null references public.business_sales(id) on delete cascade,
  product_id uuid references public.business_products(id) on delete set null,
  title_snapshot text not null,
  quantity numeric(14,3) not null check (quantity > 0),
  unit_price numeric(14,2) not null check (unit_price >= 0),
  unit_cost numeric(14,2) not null default 0 check (unit_cost >= 0),
  line_total numeric(14,2) not null check (line_total >= 0),
  created_at timestamptz not null default now(),
  check (line_total = round(quantity * unit_price,2))
);
create index if not exists business_sale_items_sale_idx
  on public.business_sale_items(sale_id);
create index if not exists business_sale_items_product_idx
  on public.business_sale_items(product_id);

create table if not exists public.inventory_movements (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  product_id uuid not null references public.business_products(id) on delete cascade,
  movement_type text not null
    check (movement_type in ('opening','purchase','sale','return','adjustment','damage')),
  quantity_delta numeric(14,3) not null check (quantity_delta <> 0),
  balance_after numeric(14,3) not null check (balance_after >= 0),
  reference_type text,
  reference_id uuid,
  note text,
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now()
);
create index if not exists inventory_movements_org_product_date_idx
  on public.inventory_movements(organization_id,product_id,created_at desc);

create table if not exists public.business_tasks (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  title text not null check (char_length(btrim(title)) between 1 and 220),
  description text,
  assigned_to uuid references auth.users(id) on delete set null,
  priority text not null default 'medium'
    check (priority in ('low','medium','high','urgent')),
  status text not null default 'todo'
    check (status in ('todo','in_progress','done','cancelled')),
  due_at timestamptz,
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists business_tasks_org_status_due_idx
  on public.business_tasks(organization_id,status,due_at);

create or replace function private.can_manage_business(target uuid, capability text)
returns boolean
language sql
stable
security definer
set search_path=''
as $$
  select exists (
    select 1
    from public.organization_members m
    left join public.organization_member_permissions p
      on p.organization_id=m.organization_id and p.user_id=m.user_id
    where m.organization_id=target
      and m.user_id=(select auth.uid())
      and (
        m.role in ('OWNER','ADMIN')
        or case capability
          when 'products' then coalesce(p.can_manage_products,false)
          when 'inventory' then coalesce(p.can_manage_inventory,false)
          when 'customers' then coalesce(p.can_manage_customers,false)
          when 'sales' then coalesce(p.can_manage_sales,false)
          when 'expenses' then coalesce(p.can_manage_expenses,false)
          when 'suppliers' then coalesce(p.can_manage_suppliers,false)
          when 'tasks' then coalesce(p.can_manage_tasks,false)
          when 'financials' then coalesce(p.can_view_financials,false)
          else false
        end
      )
  )
$$;
revoke all on function private.can_manage_business(uuid,text) from public,anon,authenticated;

create or replace function private.record_business_sale_impl(
  target_organization uuid,
  sale_customer uuid,
  items jsonb,
  sale_discount numeric,
  sale_payment_status text,
  sale_notes text
) returns uuid
language plpgsql
security definer
set search_path=''
as $$
declare
  current_user_id uuid := (select auth.uid());
  org_currency text;
  item jsonb;
  product_record public.business_products%rowtype;
  qty numeric(14,3);
  subtotal_value numeric(14,2) := 0;
  discount_value numeric(14,2) := greatest(coalesce(sale_discount,0),0);
  sale_id uuid;
  generated_number text;
begin
  if current_user_id is null or not private.can_manage_business(target_organization,'sales') then
    raise exception 'NOT_AUTHORIZED';
  end if;
  if jsonb_typeof(items) <> 'array' or jsonb_array_length(items)=0 or jsonb_array_length(items)>100 then
    raise exception 'INVALID_ITEMS';
  end if;
  if sale_payment_status not in ('unpaid','partial','paid') then
    raise exception 'INVALID_PAYMENT_STATUS';
  end if;

  select currency into org_currency
  from public.organizations
  where id=target_organization and status='active' and type <> 'STUDENT';
  if org_currency is null then raise exception 'INVALID_ORGANIZATION'; end if;

  for item in select value from jsonb_array_elements(items)
  loop
    qty := nullif(item->>'quantity','')::numeric;
    if qty is null or qty <= 0 then raise exception 'INVALID_QUANTITY'; end if;
    select * into product_record
    from public.business_products
    where id=(item->>'product_id')::uuid
      and organization_id=target_organization
      and is_active
    for update;
    if not found then raise exception 'PRODUCT_NOT_FOUND'; end if;
    if product_record.stock_quantity < qty then
      raise exception 'INSUFFICIENT_STOCK:%', product_record.name;
    end if;
    subtotal_value := subtotal_value + round(qty * product_record.price,2);
  end loop;

  if discount_value > subtotal_value then raise exception 'INVALID_DISCOUNT'; end if;
  if sale_customer is not null and not exists (
    select 1 from public.business_customers
    where id=sale_customer and organization_id=target_organization
  ) then raise exception 'CUSTOMER_NOT_FOUND'; end if;

  generated_number := 'MAD-' || to_char(clock_timestamp(),'YYYYMMDDHH24MISS') || '-' ||
    upper(substr(replace(gen_random_uuid()::text,'-',''),1,6));

  insert into public.business_sales(
    organization_id,customer_id,sale_number,payment_status,subtotal,
    discount_total,total,currency,notes,created_by
  ) values (
    target_organization,sale_customer,generated_number,sale_payment_status,
    subtotal_value,discount_value,subtotal_value-discount_value,org_currency,
    nullif(btrim(sale_notes),''),current_user_id
  ) returning id into sale_id;

  for item in select value from jsonb_array_elements(items)
  loop
    qty := (item->>'quantity')::numeric;
    select * into product_record
    from public.business_products
    where id=(item->>'product_id')::uuid and organization_id=target_organization
    for update;

    update public.business_products
      set stock_quantity=stock_quantity-qty
      where id=product_record.id;

    insert into public.business_sale_items(
      organization_id,sale_id,product_id,title_snapshot,quantity,
      unit_price,unit_cost,line_total
    ) values (
      target_organization,sale_id,product_record.id,product_record.name,qty,
      product_record.price,product_record.cost,round(qty*product_record.price,2)
    );

    insert into public.inventory_movements(
      organization_id,product_id,movement_type,quantity_delta,balance_after,
      reference_type,reference_id,note,created_by
    ) values (
      target_organization,product_record.id,'sale',-qty,
      product_record.stock_quantity-qty,'sale',sale_id,
      'بيع مسجل عبر مَدار',current_user_id
    );
  end loop;

  if sale_customer is not null then
    update public.business_customers
      set total_spent=total_spent+(subtotal_value-discount_value),
          last_order_at=now(),
          status=case when status='new' then 'active' else status end
      where id=sale_customer and organization_id=target_organization;
  end if;

  insert into public.audit_logs(actor_id,action,entity_type,entity_id,metadata)
  values (
    current_user_id,'business.sale.created','business_sale',sale_id,
    jsonb_build_object('organization_id',target_organization,'total',subtotal_value-discount_value)
  );

  return sale_id;
end
$$;
revoke all on function private.record_business_sale_impl(uuid,uuid,jsonb,numeric,text,text)
  from public,anon,authenticated;

create or replace function public.record_business_sale(
  target_organization uuid,
  sale_customer uuid default null,
  items jsonb default '[]'::jsonb,
  sale_discount numeric default 0,
  sale_payment_status text default 'paid',
  sale_notes text default null
) returns uuid
language sql
security invoker
set search_path=''
as $$
  select private.record_business_sale_impl(
    target_organization,sale_customer,items,sale_discount,sale_payment_status,sale_notes
  )
$$;
revoke all on function public.record_business_sale(uuid,uuid,jsonb,numeric,text,text)
  from public,anon;
grant execute on function public.record_business_sale(uuid,uuid,jsonb,numeric,text,text)
  to authenticated;

create or replace function private.adjust_inventory_impl(
  target_product uuid,
  quantity_change numeric,
  adjustment_note text
) returns numeric
language plpgsql
security definer
set search_path=''
as $$
declare
  current_user_id uuid := (select auth.uid());
  product_record public.business_products%rowtype;
  new_balance numeric(14,3);
begin
  select * into product_record
  from public.business_products
  where id=target_product
  for update;
  if not found then raise exception 'PRODUCT_NOT_FOUND'; end if;
  if current_user_id is null or not private.can_manage_business(product_record.organization_id,'inventory') then
    raise exception 'NOT_AUTHORIZED';
  end if;
  if quantity_change is null or quantity_change=0 then raise exception 'INVALID_QUANTITY'; end if;
  new_balance := product_record.stock_quantity + quantity_change;
  if new_balance < 0 then raise exception 'INSUFFICIENT_STOCK'; end if;

  update public.business_products set stock_quantity=new_balance where id=target_product;
  insert into public.inventory_movements(
    organization_id,product_id,movement_type,quantity_delta,balance_after,note,created_by
  ) values (
    product_record.organization_id,target_product,'adjustment',
    quantity_change,new_balance,nullif(btrim(adjustment_note),''),current_user_id
  );
  insert into public.audit_logs(actor_id,action,entity_type,entity_id,metadata)
  values (
    current_user_id,'business.inventory.adjusted','business_product',target_product,
    jsonb_build_object('organization_id',product_record.organization_id,'delta',quantity_change,'balance',new_balance)
  );
  return new_balance;
end
$$;
revoke all on function private.adjust_inventory_impl(uuid,numeric,text)
  from public,anon,authenticated;

create or replace function public.adjust_inventory(
  target_product uuid,
  quantity_change numeric,
  adjustment_note text default null
) returns numeric
language sql
security invoker
set search_path=''
as $$
  select private.adjust_inventory_impl(target_product,quantity_change,adjustment_note)
$$;
revoke all on function public.adjust_inventory(uuid,numeric,text) from public,anon;
grant execute on function public.adjust_inventory(uuid,numeric,text) to authenticated;

alter table public.organization_member_permissions enable row level security;
alter table public.business_products enable row level security;
alter table public.business_customers enable row level security;
alter table public.business_suppliers enable row level security;
alter table public.business_expenses enable row level security;
alter table public.business_sales enable row level security;
alter table public.business_sale_items enable row level security;
alter table public.inventory_movements enable row level security;
alter table public.business_tasks enable row level security;

create policy "members read own permission row"
on public.organization_member_permissions for select to authenticated
using (
  private.is_admin()
  or user_id=(select auth.uid())
  or private.has_organization_role(organization_id,array['OWNER','ADMIN']::public.organization_role[])
);
create policy "owners manage workspace permissions"
on public.organization_member_permissions for all to authenticated
using (private.has_organization_role(organization_id,array['OWNER','ADMIN']::public.organization_role[]))
with check (private.has_organization_role(organization_id,array['OWNER','ADMIN']::public.organization_role[]));

create policy "members read business products"
on public.business_products for select to authenticated
using (private.is_admin() or private.is_organization_member(organization_id));
create policy "authorized members insert business products"
on public.business_products for insert to authenticated
with check (
  created_by=(select auth.uid())
  and stock_quantity=0
  and private.can_manage_business(organization_id,'products')
);
create policy "authorized members update business products"
on public.business_products for update to authenticated
using (private.can_manage_business(organization_id,'products'))
with check (private.can_manage_business(organization_id,'products'));
create policy "authorized members delete business products"
on public.business_products for delete to authenticated
using (private.can_manage_business(organization_id,'products'));

create policy "members read business customers"
on public.business_customers for select to authenticated
using (private.is_admin() or private.is_organization_member(organization_id));
create policy "authorized members insert business customers"
on public.business_customers for insert to authenticated
with check (created_by=(select auth.uid()) and private.can_manage_business(organization_id,'customers'));
create policy "authorized members update business customers"
on public.business_customers for update to authenticated
using (private.can_manage_business(organization_id,'customers'))
with check (private.can_manage_business(organization_id,'customers'));
create policy "authorized members delete business customers"
on public.business_customers for delete to authenticated
using (private.can_manage_business(organization_id,'customers'));

create policy "members read business suppliers"
on public.business_suppliers for select to authenticated
using (private.is_admin() or private.is_organization_member(organization_id));
create policy "authorized members insert business suppliers"
on public.business_suppliers for insert to authenticated
with check (created_by=(select auth.uid()) and private.can_manage_business(organization_id,'suppliers'));
create policy "authorized members update business suppliers"
on public.business_suppliers for update to authenticated
using (private.can_manage_business(organization_id,'suppliers'))
with check (private.can_manage_business(organization_id,'suppliers'));
create policy "authorized members delete business suppliers"
on public.business_suppliers for delete to authenticated
using (private.can_manage_business(organization_id,'suppliers'));

create policy "members read business expenses"
on public.business_expenses for select to authenticated
using (
  private.is_admin()
  or private.has_organization_role(organization_id,array['OWNER','ADMIN']::public.organization_role[])
  or private.can_manage_business(organization_id,'financials')
  or private.can_manage_business(organization_id,'expenses')
);
create policy "authorized members insert business expenses"
on public.business_expenses for insert to authenticated
with check (created_by=(select auth.uid()) and private.can_manage_business(organization_id,'expenses'));
create policy "authorized members update business expenses"
on public.business_expenses for update to authenticated
using (private.can_manage_business(organization_id,'expenses'))
with check (private.can_manage_business(organization_id,'expenses'));
create policy "authorized members delete business expenses"
on public.business_expenses for delete to authenticated
using (private.can_manage_business(organization_id,'expenses'));

create policy "members read business sales"
on public.business_sales for select to authenticated
using (private.is_admin() or private.is_organization_member(organization_id));
create policy "members read business sale items"
on public.business_sale_items for select to authenticated
using (private.is_admin() or private.is_organization_member(organization_id));

create policy "members read inventory movements"
on public.inventory_movements for select to authenticated
using (private.is_admin() or private.is_organization_member(organization_id));

create policy "members read business tasks"
on public.business_tasks for select to authenticated
using (private.is_admin() or private.is_organization_member(organization_id));
create policy "authorized members insert business tasks"
on public.business_tasks for insert to authenticated
with check (created_by=(select auth.uid()) and private.can_manage_business(organization_id,'tasks'));
create policy "authorized members update business tasks"
on public.business_tasks for update to authenticated
using (private.can_manage_business(organization_id,'tasks') or assigned_to=(select auth.uid()))
with check (private.can_manage_business(organization_id,'tasks') or assigned_to=(select auth.uid()));
create policy "authorized members delete business tasks"
on public.business_tasks for delete to authenticated
using (private.can_manage_business(organization_id,'tasks'));

create trigger organization_member_permissions_updated
before update on public.organization_member_permissions
for each row execute function public.touch_updated_at();
create trigger business_products_updated
before update on public.business_products
for each row execute function public.touch_updated_at();
create trigger business_customers_updated
before update on public.business_customers
for each row execute function public.touch_updated_at();
create trigger business_suppliers_updated
before update on public.business_suppliers
for each row execute function public.touch_updated_at();
create trigger business_expenses_updated
before update on public.business_expenses
for each row execute function public.touch_updated_at();
create trigger business_sales_updated
before update on public.business_sales
for each row execute function public.touch_updated_at();
create trigger business_tasks_updated
before update on public.business_tasks
for each row execute function public.touch_updated_at();

grant select,insert,update,delete on public.organization_member_permissions to authenticated;
grant select,insert,delete on public.business_products to authenticated;
grant update(name,sku,description,category,cost,price,low_stock_threshold,is_active) on public.business_products to authenticated;
grant select,insert,update,delete on public.business_customers to authenticated;
grant select,insert,update,delete on public.business_suppliers to authenticated;
grant select,insert,update,delete on public.business_expenses to authenticated;
grant select on public.business_sales,public.business_sale_items,public.inventory_movements to authenticated;
grant select,insert,update,delete on public.business_tasks to authenticated;

-- Restore anonymous career submission while keeping review access private.
grant insert on public.job_applications to anon,authenticated;
