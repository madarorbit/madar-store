create index if not exists business_products_created_by_idx on public.business_products(created_by);
create index if not exists business_customers_created_by_idx on public.business_customers(created_by);
create index if not exists business_suppliers_created_by_idx on public.business_suppliers(created_by);
create index if not exists business_expenses_supplier_idx on public.business_expenses(supplier_id);
create index if not exists business_expenses_created_by_idx on public.business_expenses(created_by);
create index if not exists business_sales_created_by_idx on public.business_sales(created_by);
create index if not exists business_sale_items_organization_idx on public.business_sale_items(organization_id);
create index if not exists inventory_movements_product_idx on public.inventory_movements(product_id);
create index if not exists inventory_movements_created_by_idx on public.inventory_movements(created_by);
create index if not exists business_tasks_assigned_to_idx on public.business_tasks(assigned_to);
create index if not exists business_tasks_created_by_idx on public.business_tasks(created_by);

drop policy if exists "owners manage workspace permissions" on public.organization_member_permissions;
create policy "owners insert workspace permissions"
on public.organization_member_permissions for insert to authenticated
with check (private.has_organization_role(organization_id,array['OWNER','ADMIN']::public.organization_role[]));
create policy "owners update workspace permissions"
on public.organization_member_permissions for update to authenticated
using (private.has_organization_role(organization_id,array['OWNER','ADMIN']::public.organization_role[]))
with check (private.has_organization_role(organization_id,array['OWNER','ADMIN']::public.organization_role[]));
create policy "owners delete workspace permissions"
on public.organization_member_permissions for delete to authenticated
using (private.has_organization_role(organization_id,array['OWNER','ADMIN']::public.organization_role[]));
