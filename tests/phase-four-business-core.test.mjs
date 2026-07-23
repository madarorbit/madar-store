import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const migration=fs.readFileSync('supabase/migrations/20260724020000_phase_four_business_core.sql','utf8');
const hardening=fs.readFileSync('supabase/migrations/20260724020100_phase_four_business_core_hardening.sql','utf8');
const actions=fs.readFileSync('app/actions/business.ts','utf8');
const dashboard=fs.readFileSync('app/workspace/page.tsx','utf8');

const tenantTables=['business_products','business_customers','business_suppliers','business_expenses','business_sales','business_sale_items','inventory_movements','business_tasks'];

test('phase four creates tenant-scoped business operating tables',()=>{
 for(const table of tenantTables){
  assert.match(migration,new RegExp(`create table if not exists public\\.${table}`));
  assert.match(migration,new RegExp(`alter table public\\.${table} enable row level security`));
 }
 assert.match(migration,/organization_member_permissions/);
 assert.match(migration,/currency in \('YER','SAR','USD'\)/);
});

test('business data policies require organization membership or explicit capability',()=>{
 assert.match(migration,/private\.is_organization_member\(organization_id\)/);
 assert.match(migration,/private\.can_manage_business\(organization_id,'products'\)/);
 assert.match(migration,/private\.can_manage_business\(organization_id,'customers'\)/);
 assert.match(migration,/private\.can_manage_business\(organization_id,'expenses'\)/);
 assert.match(migration,/private\.can_manage_business\(organization_id,'tasks'\)/);
 assert.match(migration,/revoke all on function private\.can_manage_business/);
});

test('sales and inventory mutations are atomic private implementations',()=>{
 assert.match(migration,/private\.record_business_sale_impl/);
 assert.match(migration,/for update/);
 assert.match(migration,/INSUFFICIENT_STOCK/);
 assert.match(migration,/insert into public\.business_sale_items/);
 assert.match(migration,/insert into public\.inventory_movements/);
 assert.match(migration,/update public\.business_customers/);
 assert.match(migration,/security invoker/);
 assert.match(migration,/grant execute on function public\.record_business_sale/);
 assert.match(migration,/grant select on public\.business_sales,public\.business_sale_items,public\.inventory_movements/);
 assert.doesNotMatch(migration,/grant (insert|update|delete) on public\.business_sales/);
});

test('inventory quantity cannot be directly edited through the Data API grant',()=>{
 assert.match(migration,/grant update\(name,sku,description,category,cost,price,low_stock_threshold,is_active\) on public\.business_products/);
 assert.match(migration,/public\.adjust_inventory/);
 assert.match(actions,/quantity_change:numberValue/);
 assert.match(actions,/allowZero:false/);
});

test('server actions redirect only after work completes',()=>{
 assert.match(actions,/async function runAction/);
 assert.match(actions,/try\{await work\(\)\}catch/);
 assert.match(actions,/redirect\(`\$\{path\}\?/);
 assert.doesNotMatch(actions,/try\{[\s\S]*?redirect\([^)]*\)[\s\S]*?\}catch/);
});

test('workspace exposes the operating center and core modules',()=>{
 assert.match(dashboard,/مركز تشغيل الأعمال/);
 assert.match(dashboard,/business_products/);
 assert.match(dashboard,/business_customers/);
 assert.match(dashboard,/business_sales/);
 assert.match(dashboard,/business_expenses/);
});

test('phase four hardening covers foreign keys and avoids overlapping all policy',()=>{
 assert.match(hardening,/business_expenses_supplier_idx/);
 assert.match(hardening,/business_tasks_assigned_to_idx/);
 assert.match(hardening,/drop policy if exists "owners manage workspace permissions"/);
 assert.match(hardening,/owners insert workspace permissions/);
 assert.match(hardening,/owners update workspace permissions/);
 assert.match(hardening,/owners delete workspace permissions/);
});
