-- User-side order actions.
-- Run this in Supabase SQL Editor before testing order cancellation.

create or replace function public.cancel_order(p_order_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.orders%rowtype;
begin
  if auth.uid() is null then
    raise exception 'Please sign in to cancel orders';
  end if;

  select *
  into v_order
  from public.orders
  where id = p_order_id
  for update;

  if not found or v_order.buyer_id <> auth.uid() then
    raise exception 'Order not found';
  end if;

  if v_order.status <> 'pending' then
    raise exception 'Only pending orders can be cancelled';
  end if;

  update public.orders
  set status = 'cancelled'
  where id = p_order_id;
end;
$$;

grant execute on function public.cancel_order(uuid) to authenticated;
