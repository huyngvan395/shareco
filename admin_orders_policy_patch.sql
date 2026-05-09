-- SQL patch to allow the Platform Web Admin to view and manage all orders.
-- Run this in your Supabase SQL Editor (https://supabase.com/dashboard) to fix the empty orders list.

-- Drop conflicting or duplicate policies if they exist
drop policy if exists "admin_select_all_orders" on public.orders;
drop policy if exists "admin_select_all_order_items" on public.order_items;
drop policy if exists "admin_update_all_orders" on public.orders;

-- 1. Create a policy to allow anyone to select/read orders (system-wide visibility for admin)
create policy "admin_select_all_orders"
on public.orders
for select
using (true);

-- 2. Create a policy to allow anyone to select/read order items (system-wide visibility for admin)
create policy "admin_select_all_order_items"
on public.order_items
for select
using (true);

-- 3. Create a policy to allow update on orders (so admin can change delivery status: Pending -> Shipping -> Completed)
create policy "admin_update_all_orders"
on public.orders
for update
using (true)
with check (true);
