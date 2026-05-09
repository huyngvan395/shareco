-- MVP checkout policies for client-side order creation.
-- Run this in Supabase SQL Editor if placing an order fails with an RLS error.

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'orders'
      and policyname = 'orders_insert_own'
  ) then
    create policy "orders_insert_own"
    on public.orders
    for insert
    with check (auth.uid() = buyer_id);
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'order_items'
      and policyname = 'order_items_insert_own_order'
  ) then
    create policy "order_items_insert_own_order"
    on public.order_items
    for insert
    with check (
      exists (
        select 1
        from public.orders o
        where o.id = order_id
          and o.buyer_id = auth.uid()
      )
    );
  end if;
end $$;
