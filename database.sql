

-- ==========================================================================
-- SECTION: MAIN DATABASE SCHEMA
-- FILENAME: database.sql
-- ==========================================================================

3. Extensions và helper
-- Extensions
create extension if not exists pgcrypto;
create extension if not exists pg_trgm;

-- updated_at helper
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;
4. Profiles
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text not null unique,
  display_name text,
  bio text,
  avatar_url text,
  gender text,
  dob date,
  country_code text,
  language_code text default 'vi',
  is_verified boolean not null default false,
  follower_count integer not null default 0,
  following_count integer not null default 0,
  like_received_count bigint not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint username_length check (char_length(username) between 3 and 30)
);

create index if not exists idx_profiles_username_trgm on public.profiles using gin (username gin_trgm_ops);
create index if not exists idx_profiles_display_name_trgm on public.profiles using gin (display_name gin_trgm_ops);

create trigger trg_profiles_updated_at
before update on public.profiles
for each row
execute function public.set_updated_at();
5. Tự tạo profile khi user đăng ký
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (
    id,
    username,
    display_name,
    avatar_url
  )
  values (
    new.id,
    coalesce(
      nullif(new.raw_user_meta_data ->> 'username', ''),
      'user_' || substr(replace(new.id::text, '-', ''), 1, 10)
    ),
    coalesce(new.raw_user_meta_data ->> 'display_name', ''),
    new.raw_user_meta_data ->> 'avatar_url'
  )
  on conflict (id) do nothing;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;

create trigger on_auth_user_created
after insert on auth.users
for each row
execute function public.handle_new_user();
6. Follow system
create table if not exists public.user_follows (
  follower_id uuid not null references public.profiles(id) on delete cascade,
  following_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (follower_id, following_id),
  constraint no_self_follow check (follower_id <> following_id)
);

create index if not exists idx_user_follows_following_id on public.user_follows(following_id);
create index if not exists idx_user_follows_follower_id on public.user_follows(follower_id);
7. Trigger cập nhật counter follow
create or replace function public.handle_follow_insert()
returns trigger
language plpgsql
as $$
begin
  update public.profiles
  set following_count = following_count + 1
  where id = new.follower_id;

  update public.profiles
  set follower_count = follower_count + 1
  where id = new.following_id;

  return new;
end;
$$;

create or replace function public.handle_follow_delete()
returns trigger
language plpgsql
as $$
begin
  update public.profiles
  set following_count = greatest(following_count - 1, 0)
  where id = old.follower_id;

  update public.profiles
  set follower_count = greatest(follower_count - 1, 0)
  where id = old.following_id;

  return old;
end;
$$;

create trigger trg_user_follows_insert
after insert on public.user_follows
for each row
execute function public.handle_follow_insert();

create trigger trg_user_follows_delete
after delete on public.user_follows
for each row
execute function public.handle_follow_delete();
8. Hashtags
create table if not exists public.hashtags (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  usage_count bigint not null default 0,
  created_at timestamptz not null default now()
);
9. Videos
create table if not exists public.videos (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references public.profiles(id) on delete cascade,
  caption text,
  status text not null default 'draft',
  visibility text not null default 'public',
  video_path text not null,
  thumbnail_path text,
  duration_ms integer,
  width integer,
  height integer,
  allow_comment boolean not null default true,
  allow_duet boolean not null default true,
  allow_stitch boolean not null default true,
  view_count bigint not null default 0,
  like_count bigint not null default 0,
  comment_count bigint not null default 0,
  share_count bigint not null default 0,
  product_tag_count integer not null default 0,
  published_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint videos_status_check check (status in ('draft', 'published', 'blocked', 'deleted')),
  constraint videos_visibility_check check (visibility in ('public', 'followers', 'private'))
);

create index if not exists idx_videos_author_published on public.videos(author_id, published_at desc);
create index if not exists idx_videos_status_visibility on public.videos(status, visibility, published_at desc);
create index if not exists idx_videos_created_at on public.videos(created_at desc);
create index if not exists idx_videos_caption_trgm on public.videos using gin (caption gin_trgm_ops);

create trigger trg_videos_updated_at
before update on public.videos
for each row
execute function public.set_updated_at();
10. Video hashtags
create table if not exists public.video_hashtags (
  video_id uuid not null references public.videos(id) on delete cascade,
  hashtag_id uuid not null references public.hashtags(id) on delete cascade,
  primary key (video_id, hashtag_id)
);

create index if not exists idx_video_hashtags_hashtag_id on public.video_hashtags(hashtag_id);
11. Trigger cập nhật usage_count hashtag
create or replace function public.handle_video_hashtag_insert()
returns trigger
language plpgsql
as $$
begin
  update public.hashtags
  set usage_count = usage_count + 1
  where id = new.hashtag_id;

  return new;
end;
$$;

create or replace function public.handle_video_hashtag_delete()
returns trigger
language plpgsql
as $$
begin
  update public.hashtags
  set usage_count = greatest(usage_count - 1, 0)
  where id = old.hashtag_id;

  return old;
end;
$$;

create trigger trg_video_hashtags_insert
after insert on public.video_hashtags
for each row
execute function public.handle_video_hashtag_insert();

create trigger trg_video_hashtags_delete
after delete on public.video_hashtags
for each row
execute function public.handle_video_hashtag_delete();
12. Video likes
create table if not exists public.video_likes (
  user_id uuid not null references public.profiles(id) on delete cascade,
  video_id uuid not null references public.videos(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, video_id)
);

create index if not exists idx_video_likes_video_id on public.video_likes(video_id);
create index if not exists idx_video_likes_user_id on public.video_likes(user_id);
13. Trigger cập nhật like_count và like_received_count
create or replace function public.handle_video_like_insert()
returns trigger
language plpgsql
as $$
declare
  v_author_id uuid;
begin
  update public.videos
  set like_count = like_count + 1
  where id = new.video_id
  returning author_id into v_author_id;

  if v_author_id is not null then
    update public.profiles
    set like_received_count = like_received_count + 1
    where id = v_author_id;
  end if;

  return new;
end;
$$;

create or replace function public.handle_video_like_delete()
returns trigger
language plpgsql
as $$
declare
  v_author_id uuid;
begin
  select author_id into v_author_id
  from public.videos
  where id = old.video_id;

  update public.videos
  set like_count = greatest(like_count - 1, 0)
  where id = old.video_id;

  if v_author_id is not null then
    update public.profiles
    set like_received_count = greatest(like_received_count - 1, 0)
    where id = v_author_id;
  end if;

  return old;
end;
$$;

create trigger trg_video_likes_insert
after insert on public.video_likes
for each row
execute function public.handle_video_like_insert();

create trigger trg_video_likes_delete
after delete on public.video_likes
for each row
execute function public.handle_video_like_delete();
14. Comments
create table if not exists public.video_comments (
  id uuid primary key default gen_random_uuid(),
  video_id uuid not null references public.videos(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  parent_id uuid references public.video_comments(id) on delete cascade,
  content text not null,
  like_count integer not null default 0,
  reply_count integer not null default 0,
  status text not null default 'visible',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint video_comments_status_check check (status in ('visible', 'hidden', 'deleted'))
);

create index if not exists idx_video_comments_video_created on public.video_comments(video_id, created_at desc);
create index if not exists idx_video_comments_parent_id on public.video_comments(parent_id);
create index if not exists idx_video_comments_user_id on public.video_comments(user_id);

create trigger trg_video_comments_updated_at
before update on public.video_comments
for each row
execute function public.set_updated_at();
15. Trigger cập nhật comment_count và reply_count
create or replace function public.handle_comment_insert()
returns trigger
language plpgsql
as $$
begin
  update public.videos
  set comment_count = comment_count + 1
  where id = new.video_id;

  if new.parent_id is not null then
    update public.video_comments
    set reply_count = reply_count + 1
    where id = new.parent_id;
  end if;

  return new;
end;
$$;

create or replace function public.handle_comment_delete()
returns trigger
language plpgsql
as $$
begin
  update public.videos
  set comment_count = greatest(comment_count - 1, 0)
  where id = old.video_id;

  if old.parent_id is not null then
    update public.video_comments
    set reply_count = greatest(reply_count - 1, 0)
    where id = old.parent_id;
  end if;

  return old;
end;
$$;

create trigger trg_video_comments_insert
after insert on public.video_comments
for each row
execute function public.handle_comment_insert();

create trigger trg_video_comments_delete
after delete on public.video_comments
for each row
execute function public.handle_comment_delete();
16. Shops
create table if not exists public.shops (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null unique references public.profiles(id) on delete cascade,
  shop_name text not null,
  shop_slug text not null unique,
  description text,
  logo_path text,
  cover_path text,
  rating_avg numeric(3,2) not null default 0,
  rating_count integer not null default 0,
  product_count integer not null default 0,
  follower_count integer not null default 0,
  status text not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint shops_status_check check (status in ('active', 'inactive', 'blocked'))
);

create index if not exists idx_shops_slug_trgm on public.shops using gin (shop_slug gin_trgm_ops);
create index if not exists idx_shops_name_trgm on public.shops using gin (shop_name gin_trgm_ops);

create trigger trg_shops_updated_at
before update on public.shops
for each row
execute function public.set_updated_at();
17. Product categories
create table if not exists public.product_categories (
  id uuid primary key default gen_random_uuid(),
  parent_id uuid references public.product_categories(id) on delete set null,
  name text not null,
  slug text not null unique,
  created_at timestamptz not null default now()
);
18. Products
create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id) on delete cascade,
  category_id uuid references public.product_categories(id) on delete set null,
  title text not null,
  description text,
  brand text,
  status text not null default 'active',
  price_min numeric(12,2) not null,
  price_max numeric(12,2) not null,
  currency text not null default 'VND',
  stock_total integer not null default 0,
  sold_count integer not null default 0,
  rating_avg numeric(3,2) not null default 0,
  rating_count integer not null default 0,
  cover_path text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint products_status_check check (status in ('draft', 'active', 'inactive', 'deleted')),
  constraint products_price_check check (price_min >= 0 and price_max >= price_min),
  constraint products_stock_check check (stock_total >= 0)
);

create index if not exists idx_products_shop_created on public.products(shop_id, created_at desc);
create index if not exists idx_products_category_id on public.products(category_id);
create index if not exists idx_products_title_trgm on public.products using gin (title gin_trgm_ops);
create index if not exists idx_products_brand_trgm on public.products using gin (brand gin_trgm_ops);

create trigger trg_products_updated_at
before update on public.products
for each row
execute function public.set_updated_at();
19. Trigger cập nhật product_count của shop
create or replace function public.handle_product_insert()
returns trigger
language plpgsql
as $$
begin
  update public.shops
  set product_count = product_count + 1
  where id = new.shop_id;

  return new;
end;
$$;

create or replace function public.handle_product_delete()
returns trigger
language plpgsql
as $$
begin
  update public.shops
  set product_count = greatest(product_count - 1, 0)
  where id = old.shop_id;

  return old;
end;
$$;

create trigger trg_products_insert
after insert on public.products
for each row
execute function public.handle_product_insert();

create trigger trg_products_delete
after delete on public.products
for each row
execute function public.handle_product_delete();
20. Product media
create table if not exists public.product_media (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete cascade,
  media_type text not null,
  storage_path text not null,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  constraint product_media_type_check check (media_type in ('image', 'video'))
);

create index if not exists idx_product_media_product_id on public.product_media(product_id, sort_order);
21. Product variants
create table if not exists public.product_variants (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete cascade,
  sku text unique,
  variant_name text,
  price numeric(12,2) not null,
  compare_at_price numeric(12,2),
  stock_qty integer not null default 0,
  weight_grams integer,
  status text not null default 'active',
  created_at timestamptz not null default now(),
  constraint product_variants_status_check check (status in ('active', 'inactive')),
  constraint product_variants_price_check check (price >= 0),
  constraint product_variants_stock_check check (stock_qty >= 0)
);

create index if not exists idx_product_variants_product_id on public.product_variants(product_id);

create table if not exists public.product_variant_options (
  id uuid primary key default gen_random_uuid(),
  variant_id uuid not null references public.product_variants(id) on delete cascade,
  option_name text not null,
  option_value text not null
);

create index if not exists idx_product_variant_options_variant_id on public.product_variant_options(variant_id);
22. Video product tags
create table if not exists public.video_product_tags (
  video_id uuid not null references public.videos(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete cascade,
  sort_order integer not null default 0,
  primary key (video_id, product_id)
);

create index if not exists idx_video_product_tags_product_id on public.video_product_tags(product_id);
23. Trigger cập nhật product_tag_count
create or replace function public.handle_video_product_tag_insert()
returns trigger
language plpgsql
as $$
begin
  update public.videos
  set product_tag_count = product_tag_count + 1
  where id = new.video_id;

  return new;
end;
$$;

create or replace function public.handle_video_product_tag_delete()
returns trigger
language plpgsql
as $$
begin
  update public.videos
  set product_tag_count = greatest(product_tag_count - 1, 0)
  where id = old.video_id;

  return old;
end;
$$;

create trigger trg_video_product_tags_insert
after insert on public.video_product_tags
for each row
execute function public.handle_video_product_tag_insert();

create trigger trg_video_product_tags_delete
after delete on public.video_product_tags
for each row
execute function public.handle_video_product_tag_delete();
24. Carts và auto create cart
create table if not exists public.carts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references public.profiles(id) on delete cascade,
  updated_at timestamptz not null default now()
);

create trigger trg_carts_updated_at
before update on public.carts
for each row
execute function public.set_updated_at();

create table if not exists public.cart_items (
  id uuid primary key default gen_random_uuid(),
  cart_id uuid not null references public.carts(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete cascade,
  variant_id uuid references public.product_variants(id) on delete set null,
  qty integer not null,
  unit_price numeric(12,2) not null,
  created_at timestamptz not null default now(),
  constraint cart_items_qty_check check (qty > 0),
  constraint cart_items_unit_price_check check (unit_price >= 0)
);

create index if not exists idx_cart_items_cart_id on public.cart_items(cart_id);
create index if not exists idx_cart_items_product_id on public.cart_items(product_id);

create or replace function public.handle_create_cart_for_user()
returns trigger
language plpgsql
as $$
begin
  insert into public.carts (user_id)
  values (new.id)
  on conflict (user_id) do nothing;

  return new;
end;
$$;

create trigger trg_profiles_create_cart
after insert on public.profiles
for each row
execute function public.handle_create_cart_for_user();
25. User addresses
create table if not exists public.user_addresses (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  full_name text not null,
  phone text not null,
  province text,
  district text,
  ward text,
  address_line text not null,
  postal_code text,
  is_default boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists idx_user_addresses_user_id on public.user_addresses(user_id);
26. Orders
create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  buyer_id uuid not null references public.profiles(id) on delete restrict,
  shop_id uuid not null references public.shops(id) on delete restrict,
  order_code text not null unique,
  status text not null default 'pending',
  subtotal_amount numeric(12,2) not null,
  discount_amount numeric(12,2) not null default 0,
  shipping_amount numeric(12,2) not null default 0,
  total_amount numeric(12,2) not null,
  currency text not null default 'VND',
  address_snapshot jsonb not null,
  note text,
  placed_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint orders_status_check check (
    status in ('pending', 'paid', 'packed', 'shipping', 'completed', 'cancelled', 'refunded')
  ),
  constraint orders_money_check check (
    subtotal_amount >= 0 and
    discount_amount >= 0 and
    shipping_amount >= 0 and
    total_amount >= 0
  )
);

create index if not exists idx_orders_buyer_placed on public.orders(buyer_id, placed_at desc);
create index if not exists idx_orders_shop_placed on public.orders(shop_id, placed_at desc);
create index if not exists idx_orders_status on public.orders(status);

create trigger trg_orders_updated_at
before update on public.orders
for each row
execute function public.set_updated_at();

create table if not exists public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete restrict,
  variant_id uuid references public.product_variants(id) on delete set null,
  shop_id uuid not null references public.shops(id) on delete restrict,
  title_snapshot text not null,
  variant_snapshot text,
  unit_price numeric(12,2) not null,
  qty integer not null,
  line_total numeric(12,2) not null,
  constraint order_items_qty_check check (qty > 0),
  constraint order_items_money_check check (unit_price >= 0 and line_total >= 0)
);

create index if not exists idx_order_items_order_id on public.order_items(order_id);
create index if not exists idx_order_items_product_id on public.order_items(product_id);
27. Payments
create table if not exists public.payments (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null unique references public.orders(id) on delete cascade,
  provider text not null,
  provider_ref text,
  amount numeric(12,2) not null,
  currency text not null default 'VND',
  status text not null default 'initiated',
  payload jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint payments_status_check check (
    status in ('initiated', 'pending', 'paid', 'failed', 'refunded')
  )
);

create index if not exists idx_payments_provider_ref on public.payments(provider_ref);

create trigger trg_payments_updated_at
before update on public.payments
for each row
execute function public.set_updated_at();
28. Product reviews
create table if not exists public.product_reviews (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete cascade,
  order_item_id uuid unique references public.order_items(id) on delete set null,
  user_id uuid not null references public.profiles(id) on delete cascade,
  rating integer not null,
  content text,
  created_at timestamptz not null default now(),
  constraint product_reviews_rating_check check (rating between 1 and 5)
);

create index if not exists idx_product_reviews_product_id on public.product_reviews(product_id, created_at desc);
create index if not exists idx_product_reviews_user_id on public.product_reviews(user_id);
29. Trigger cập nhật rating sản phẩm và shop
create or replace function public.refresh_product_rating(p_product_id uuid)
returns void
language plpgsql
as $$
declare
  v_shop_id uuid;
begin
  update public.products p
  set
    rating_avg = coalesce(r.avg_rating, 0),
    rating_count = coalesce(r.rating_count, 0)
  from (
    select
      product_id,
      avg(rating)::numeric(3,2) as avg_rating,
      count(*)::int as rating_count
    from public.product_reviews
    where product_id = p_product_id
    group by product_id
  ) r
  where p.id = r.product_id;

  update public.products
  set rating_avg = 0, rating_count = 0
  where id = p_product_id
    and not exists (
      select 1 from public.product_reviews where product_id = p_product_id
    );

  select shop_id into v_shop_id
  from public.products
  where id = p_product_id;

  if v_shop_id is not null then
    update public.shops s
    set
      rating_avg = coalesce(x.avg_rating, 0),
      rating_count = coalesce(x.rating_count, 0)
    from (
      select
        p.shop_id,
        avg(pr.rating)::numeric(3,2) as avg_rating,
        count(pr.id)::int as rating_count
      from public.products p
      left join public.product_reviews pr on pr.product_id = p.id
      where p.shop_id = v_shop_id
      group by p.shop_id
    ) x
    where s.id = x.shop_id;
  end if;
end;
$$;

create or replace function public.handle_product_review_change()
returns trigger
language plpgsql
as $$
declare
  v_product_id uuid;
begin
  v_product_id := coalesce(new.product_id, old.product_id);
  perform public.refresh_product_rating(v_product_id);
  return coalesce(new, old);
end;
$$;

create trigger trg_product_reviews_after_insert
after insert on public.product_reviews
for each row
execute function public.handle_product_review_change();

create trigger trg_product_reviews_after_update
after update on public.product_reviews
for each row
execute function public.handle_product_review_change();

create trigger trg_product_reviews_after_delete
after delete on public.product_reviews
for each row
execute function public.handle_product_review_change();
30. Notifications
create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  type text not null,
  title text,
  body text,
  data jsonb,
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists idx_notifications_user_created on public.notifications(user_id, created_at desc);
create index if not exists idx_notifications_user_read on public.notifications(user_id, is_read);
31. Chat
create table if not exists public.conversations (
  id uuid primary key default gen_random_uuid(),
  type text not null default 'direct',
  created_by uuid references public.profiles(id) on delete set null,
  direct_key text unique,
  last_message text,
  last_message_at timestamptz,
  last_sender_id uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint conversations_type_check check (type in ('direct', 'group')),
  constraint conversations_direct_key_check check (
    (type = 'direct' and direct_key is not null)
    or (type = 'group' and direct_key is null)
  )
);

create index if not exists idx_conversations_updated_at on public.conversations(updated_at desc);
create index if not exists idx_conversations_last_message_at on public.conversations(last_message_at desc);

create trigger trg_conversations_updated_at
before update on public.conversations
for each row
execute function public.set_updated_at();

create table if not exists public.conversation_participants (
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role text not null default 'member',
  last_read_at timestamptz,
  is_muted boolean not null default false,
  joined_at timestamptz not null default now(),
  primary key (conversation_id, user_id),
  constraint conversation_participants_role_check check (role in ('owner', 'member'))
);

create index if not exists idx_conversation_participants_user on public.conversation_participants(user_id, conversation_id);
create index if not exists idx_conversation_participants_conversation on public.conversation_participants(conversation_id);

create or replace function public.is_conversation_participant(
  p_conversation_id uuid,
  p_user_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.conversation_participants cp
    where cp.conversation_id = p_conversation_id
      and cp.user_id = p_user_id
  );
$$;

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  type text not null default 'text',
  content text,
  media_url text,
  reply_to_id uuid references public.messages(id) on delete set null,
  is_deleted boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint messages_type_check check (type in ('text', 'image', 'video', 'sticker', 'gift')),
  constraint messages_body_check check (
    is_deleted
    or content is not null
    or media_url is not null
  )
);

create index if not exists idx_messages_conversation_created on public.messages(conversation_id, created_at desc);
create index if not exists idx_messages_sender_created on public.messages(sender_id, created_at desc);
create index if not exists idx_messages_reply_to on public.messages(reply_to_id);

create trigger trg_messages_updated_at
before update on public.messages
for each row
execute function public.set_updated_at();

create or replace function public.handle_message_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.conversations
  set
    last_message = case
      when new.is_deleted then null
      when new.type = 'text' then new.content
      when new.type = 'image' then '[image]'
      when new.type = 'video' then '[video]'
      when new.type = 'sticker' then coalesce(new.content, '[sticker]')
      when new.type = 'gift' then '[gift]'
      else coalesce(new.content, '[message]')
    end,
    last_message_at = new.created_at,
    last_sender_id = new.sender_id
  where id = new.conversation_id;

  return new;
end;
$$;

create trigger trg_messages_after_insert
after insert on public.messages
for each row
execute function public.handle_message_insert();

create or replace function public.handle_message_update()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.is_deleted
     and old.is_deleted = false
     and exists (
       select 1
       from public.conversations c
       where c.id = new.conversation_id
         and c.last_message_at = old.created_at
         and c.last_sender_id = old.sender_id
     ) then
    update public.conversations
    set last_message = 'Message deleted'
    where id = new.conversation_id;
  end if;

  return new;
end;
$$;

create trigger trg_messages_after_update
after update of is_deleted on public.messages
for each row
execute function public.handle_message_update();
32. Reports / moderation
create table if not exists public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.profiles(id) on delete cascade,
  target_type text not null,
  target_id uuid not null,
  reason text not null,
  details text,
  status text not null default 'open',
  created_at timestamptz not null default now(),
  constraint reports_status_check check (status in ('open', 'reviewing', 'resolved', 'rejected'))
);
33. Enable RLS
alter table public.profiles enable row level security;
alter table public.user_follows enable row level security;
alter table public.hashtags enable row level security;
alter table public.videos enable row level security;
alter table public.video_hashtags enable row level security;
alter table public.video_likes enable row level security;
alter table public.video_comments enable row level security;
alter table public.shops enable row level security;
alter table public.product_categories enable row level security;
alter table public.products enable row level security;
alter table public.product_media enable row level security;
alter table public.product_variants enable row level security;
alter table public.product_variant_options enable row level security;
alter table public.video_product_tags enable row level security;
alter table public.carts enable row level security;
alter table public.cart_items enable row level security;
alter table public.user_addresses enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.payments enable row level security;
alter table public.product_reviews enable row level security;
alter table public.notifications enable row level security;
alter table public.conversations enable row level security;
alter table public.conversation_participants enable row level security;
alter table public.messages enable row level security;
alter table public.reports enable row level security;
34. Policy cơ bản
create policy "profiles_public_read"
on public.profiles
for select
using (true);

create policy "profiles_insert_own"
on public.profiles
for insert
with check (auth.uid() = id);

create policy "profiles_update_own"
on public.profiles
for update
using (auth.uid() = id)
with check (auth.uid() = id);

create policy "user_follows_read"
on public.user_follows
for select
using (true);

create policy "user_follows_insert_own"
on public.user_follows
for insert
with check (auth.uid() = follower_id);

create policy "user_follows_delete_own"
on public.user_follows
for delete
using (auth.uid() = follower_id);

create policy "hashtags_public_read"
on public.hashtags
for select
using (true);

create policy "videos_public_read"
on public.videos
for select
using (
  status = 'published'
  and (
    visibility = 'public'
    or author_id = auth.uid()
  )
);

create policy "videos_insert_own"
on public.videos
for insert
with check (auth.uid() = author_id);

create policy "videos_update_own"
on public.videos
for update
using (auth.uid() = author_id)
with check (auth.uid() = author_id);

create policy "videos_delete_own"
on public.videos
for delete
using (auth.uid() = author_id);

create policy "video_hashtags_read"
on public.video_hashtags
for select
using (true);

create policy "video_hashtags_manage_owner"
on public.video_hashtags
for all
using (
  exists (
    select 1 from public.videos v
    where v.id = video_id and v.author_id = auth.uid()
  )
)
with check (
  exists (
    select 1 from public.videos v
    where v.id = video_id and v.author_id = auth.uid()
  )
);

create policy "video_likes_read"
on public.video_likes
for select
using (true);

create policy "video_likes_insert_own"
on public.video_likes
for insert
with check (auth.uid() = user_id);

create policy "video_likes_delete_own"
on public.video_likes
for delete
using (auth.uid() = user_id);

create policy "video_comments_read"
on public.video_comments
for select
using (status = 'visible');

create policy "video_comments_insert_own"
on public.video_comments
for insert
with check (auth.uid() = user_id);

create policy "video_comments_update_own"
on public.video_comments
for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

create policy "video_comments_delete_own"
on public.video_comments
for delete
using (auth.uid() = user_id);

create policy "shops_public_read"
on public.shops
for select
using (status = 'active' or owner_id = auth.uid());

create policy "shops_insert_own"
on public.shops
for insert
with check (auth.uid() = owner_id);

create policy "shops_update_own"
on public.shops
for update
using (auth.uid() = owner_id)
with check (auth.uid() = owner_id);

create policy "product_categories_public_read"
on public.product_categories
for select
using (true);

create policy "product_categories_insert_auth"
on public.product_categories
for insert
to authenticated
with check (true);

create policy "products_public_read"
on public.products
for select
using (
  status = 'active'
  or exists (
    select 1
    from public.shops s
    where s.id = shop_id and s.owner_id = auth.uid()
  )
);

create policy "products_manage_by_shop_owner"
on public.products
for all
using (
  exists (
    select 1
    from public.shops s
    where s.id = shop_id and s.owner_id = auth.uid()
  )
)
with check (
  exists (
    select 1
    from public.shops s
    where s.id = shop_id and s.owner_id = auth.uid()
  )
);

create policy "product_media_read"
on public.product_media
for select
using (true);

create policy "product_media_manage_by_owner"
on public.product_media
for all
using (
  exists (
    select 1
    from public.products p
    join public.shops s on s.id = p.shop_id
    where p.id = product_id and s.owner_id = auth.uid()
  )
)
with check (
  exists (
    select 1
    from public.products p
    join public.shops s on s.id = p.shop_id
    where p.id = product_id and s.owner_id = auth.uid()
  )
);

create policy "product_variants_read"
on public.product_variants
for select
using (true);

create policy "product_variants_manage_by_owner"
on public.product_variants
for all
using (
  exists (
    select 1
    from public.products p
    join public.shops s on s.id = p.shop_id
    where p.id = product_id and s.owner_id = auth.uid()
  )
)
with check (
  exists (
    select 1
    from public.products p
    join public.shops s on s.id = p.shop_id
    where p.id = product_id and s.owner_id = auth.uid()
  )
);

create policy "product_variant_options_read"
on public.product_variant_options
for select
using (true);

create policy "product_variant_options_manage_by_owner"
on public.product_variant_options
for all
using (
  exists (
    select 1
    from public.product_variants pv
    join public.products p on p.id = pv.product_id
    join public.shops s on s.id = p.shop_id
    where pv.id = variant_id and s.owner_id = auth.uid()
  )
)
with check (
  exists (
    select 1
    from public.product_variants pv
    join public.products p on p.id = pv.product_id
    join public.shops s on s.id = p.shop_id
    where pv.id = variant_id and s.owner_id = auth.uid()
  )
);

create policy "video_product_tags_read"
on public.video_product_tags
for select
using (true);

create policy "video_product_tags_manage_owner"
on public.video_product_tags
for all
using (
  exists (
    select 1
    from public.videos v
    where v.id = video_id and v.author_id = auth.uid()
  )
)
with check (
  exists (
    select 1
    from public.videos v
    where v.id = video_id and v.author_id = auth.uid()
  )
);

create policy "carts_read_own"
on public.carts
for select
using (auth.uid() = user_id);

create policy "carts_insert_own"
on public.carts
for insert
with check (auth.uid() = user_id);

create policy "carts_update_own"
on public.carts
for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

create policy "cart_items_read_own"
on public.cart_items
for select
using (
  exists (
    select 1 from public.carts c
    where c.id = cart_id and c.user_id = auth.uid()
  )
);

create policy "cart_items_manage_own"
on public.cart_items
for all
using (
  exists (
    select 1 from public.carts c
    where c.id = cart_id and c.user_id = auth.uid()
  )
)
with check (
  exists (
    select 1 from public.carts c
    where c.id = cart_id and c.user_id = auth.uid()
  )
);

create policy "user_addresses_read_own"
on public.user_addresses
for select
using (auth.uid() = user_id);

create policy "user_addresses_manage_own"
on public.user_addresses
for all
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

create policy "orders_read_buyer_or_shop_owner"
on public.orders
for select
using (
  auth.uid() = buyer_id
  or exists (
    select 1
    from public.shops s
    where s.id = shop_id and s.owner_id = auth.uid()
  )
);

create policy "order_items_read_related"
on public.order_items
for select
using (
  exists (
    select 1
    from public.orders o
    join public.shops s on s.id = o.shop_id
    where o.id = order_id
      and (o.buyer_id = auth.uid() or s.owner_id = auth.uid())
  )
);

create policy "payments_read_related"
on public.payments
for select
using (
  exists (
    select 1
    from public.orders o
    join public.shops s on s.id = o.shop_id
    where o.id = order_id
      and (o.buyer_id = auth.uid() or s.owner_id = auth.uid())
  )
);

create policy "product_reviews_public_read"
on public.product_reviews
for select
using (true);

create policy "product_reviews_insert_own"
on public.product_reviews
for insert
with check (auth.uid() = user_id);

create policy "product_reviews_update_own"
on public.product_reviews
for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

create policy "product_reviews_delete_own"
on public.product_reviews
for delete
using (auth.uid() = user_id);

create policy "notifications_read_own"
on public.notifications
for select
using (auth.uid() = user_id);

create policy "notifications_update_own"
on public.notifications
for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

create policy "conversations_read_participant"
on public.conversations
for select
using (public.is_conversation_participant(id, auth.uid()));

create policy "conversation_participants_read_related"
on public.conversation_participants
for select
using (public.is_conversation_participant(conversation_id, auth.uid()));

create policy "conversation_participants_update_self"
on public.conversation_participants
for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

create policy "messages_read_participant"
on public.messages
for select
using (public.is_conversation_participant(conversation_id, auth.uid()));

create policy "messages_insert_participant"
on public.messages
for insert
with check (
  auth.uid() = sender_id
  and public.is_conversation_participant(conversation_id, auth.uid())
);

create policy "messages_update_sender"
on public.messages
for update
using (auth.uid() = sender_id)
with check (
  auth.uid() = sender_id
  and public.is_conversation_participant(conversation_id, auth.uid())
);

create policy "reports_insert_own"
on public.reports
for insert
with check (auth.uid() = reporter_id);

create policy "reports_read_own"
on public.reports
for select
using (auth.uid() = reporter_id);
35. RPC hữu ích
create or replace function public.get_following_feed(
  p_limit integer default 20,
  p_offset integer default 0
)
returns setof public.videos
language sql
stable
as $$
  select v.*
  from public.videos v
  join public.user_follows uf on uf.following_id = v.author_id
  where uf.follower_id = auth.uid()
    and v.status = 'published'
    and v.visibility = 'public'
  order by v.published_at desc nulls last, v.created_at desc
  limit p_limit
  offset p_offset;
$$;

create or replace function public.toggle_video_like(p_video_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
  v_exists boolean;
begin
  v_user_id := auth.uid();

  if v_user_id is null then
    raise exception 'Unauthenticated';
  end if;

  select exists(
    select 1 from public.video_likes
    where user_id = v_user_id and video_id = p_video_id
  ) into v_exists;

  if v_exists then
    delete from public.video_likes
    where user_id = v_user_id and video_id = p_video_id;
    return false;
  else
    insert into public.video_likes(user_id, video_id)
    values (v_user_id, p_video_id);
    return true;
  end if;
end;
$$;

create or replace function public.get_or_create_conversation(other_user_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
  v_conversation_id uuid;
  v_direct_key text;
begin
  v_user_id := auth.uid();

  if v_user_id is null then
    raise exception 'Unauthenticated';
  end if;

  if other_user_id is null then
    raise exception 'other_user_id is required';
  end if;

  if other_user_id = v_user_id then
    raise exception 'Cannot create a conversation with yourself';
  end if;

  if not exists (select 1 from public.profiles where id = other_user_id) then
    raise exception 'User not found';
  end if;

  v_direct_key := least(v_user_id::text, other_user_id::text)
    || ':'
    || greatest(v_user_id::text, other_user_id::text);

  insert into public.conversations (type, created_by, direct_key)
  values ('direct', v_user_id, v_direct_key)
  on conflict (direct_key) do update
    set updated_at = public.conversations.updated_at
  returning id into v_conversation_id;

  insert into public.conversation_participants (
    conversation_id,
    user_id,
    role,
    last_read_at
  )
  values
    (v_conversation_id, v_user_id, 'owner', now()),
    (v_conversation_id, other_user_id, 'member', null)
  on conflict (conversation_id, user_id) do nothing;

  return v_conversation_id;
end;
$$;

create or replace function public.mark_conversation_read(p_conversation_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
begin
  v_user_id := auth.uid();

  if v_user_id is null then
    raise exception 'Unauthenticated';
  end if;

  update public.conversation_participants
  set last_read_at = now()
  where conversation_id = p_conversation_id
    and user_id = v_user_id;

  if not found then
    raise exception 'Conversation not found';
  end if;
end;
$$;
36. Gợi ý bucket Storage
- avatars
- video-originals
- video-thumbnails
- product-media
- review-media
- chat-attachments

Quy ước path:
- avatars/{user_id}/avatar.jpg
- video-originals/{user_id}/{video_id}.mp4
- video-thumbnails/{user_id}/{video_id}.jpg
<<<<<<< Updated upstream
- product-media/{shop_id}/{product_id}/...
=======
- product-media/{shop_id}/{product_id}/...
37. Những phần nên làm bằng Edge Function
- tạo order từ cart
- tạo payment intent
- nhận webhook thanh toán
- cập nhật orders.status
- trừ tồn kho
- hoàn tiền
- moderation/admin actions
38. Lưu ý thực chiến
1. Orders không nên cho client insert trực tiếp nếu sau này có payment thật.
2. Counter như like_count, comment_count, follower_count phải cập nhật bằng trigger hoặc server logic.
3. Feed “For You” không nên query raw từ app; nên có recommendation layer riêng.
4. Nên tách migration file theo domain để dễ rollback và review.
39. Kết luận
Bộ schema này phù hợp để khởi động một dự án Flutter đa nền tảng theo mô hình TikTok + TikTok Shop trên Supabase. Bạn có thể tách từng phần thành migration riêng hoặc dùng tài liệu này như bản master để rà soát kiến trúc trước khi triển khai.
Bước tiếp theo: tách file migration chuẩn Supabase CLI, hoặc sinh Dart models và repositories cho Flutter từ schema này.
>>>>>>> Stashed changes


-- ==========================================================================
-- SECTION: SEED E-COMMERCE DATA
-- FILENAME: seed_ecommerce.sql
-- ==========================================================================

-- Seed sample ecommerce data for Shareco with Multiple Shops (Apple, Samsung, Zara, Nike).
-- Run this in Supabase SQL Editor after at least one user has registered.

do $$
declare
  v_owner_id uuid;
  v_shop_apple uuid;
  v_shop_samsung uuid;
  v_shop_zara uuid;
  v_shop_nike uuid;
  v_category_accessories uuid;
  v_category_electronics uuid;
  v_category_fashion uuid;
begin
  -- 1. Get the first registered profile to own all these demo shops
  select id
  into v_owner_id
  from public.profiles
  order by created_at asc
  limit 1;

  if v_owner_id is null then
    raise exception 'No profile found. Register/login once first so public.profiles has at least one row.';
  end if;

  -- 2. Remove the unique constraint on owner_id to allow a single user to own multiple shops for testing purposes
  alter table public.shops drop constraint if exists shops_owner_id_key;

  -- 2b. Clean up old Shareco shops and their orders/order items/reviews/products to avoid foreign key errors
  delete from public.order_items where shop_id in (
    select id from public.shops where shop_slug like '%shareco%' or shop_name like '%Shareco%'
  );
  delete from public.orders where shop_id in (
    select id from public.shops where shop_slug like '%shareco%' or shop_name like '%Shareco%'
  );
  delete from public.product_reviews where product_id in (
    select id from public.products where shop_id in (
      select id from public.shops where shop_slug like '%shareco%' or shop_name like '%Shareco%'
    )
  );
  delete from public.products where shop_id in (
    select id from public.shops where shop_slug like '%shareco%' or shop_name like '%Shareco%'
  );
  delete from public.shops
  where shop_slug like '%shareco%' or shop_name like '%Shareco%';

  -- 3. Seed Category
  insert into public.product_categories (name, slug)
  values
    ('Phụ kiện', 'phone-accessories'),
    ('Điện tử', 'electronics'),
    ('Thời trang', 'fashion')
  on conflict (slug) do update
  set name = excluded.name;

  select id into v_category_accessories
  from public.product_categories
  where slug = 'phone-accessories';

  select id into v_category_electronics
  from public.product_categories
  where slug = 'electronics';

  select id into v_category_fashion
  from public.product_categories
  where slug = 'fashion';

  -- 4. Seed Shop: Apple Official Store
  insert into public.shops (
    owner_id,
    shop_name,
    shop_slug,
    description,
    logo_path,
    cover_path,
    rating_avg,
    rating_count,
    follower_count,
    status
  )
  values (
    v_owner_id,
    'Apple Official Store',
    'apple-official',
    'Gian hàng chính hãng phân phối các sản phẩm Apple tại Việt Nam.',
    'https://images.unsplash.com/photo-1611186871348-b1ce696e52c9?w=200&h=200&fit=crop',
    'https://images.unsplash.com/photo-1510557880182-3d4d3cba35a5?w=800&h=400&fit=crop',
    4.9,
    1542,
    98200,
    'active'
  )
  on conflict (shop_slug) do update
  set
    shop_name = excluded.shop_name,
    description = excluded.description,
    logo_path = excluded.logo_path,
    cover_path = excluded.cover_path
  returning id into v_shop_apple;

  -- 5. Seed Shop: Samsung Galaxy Store
  insert into public.shops (
    owner_id,
    shop_name,
    shop_slug,
    description,
    logo_path,
    cover_path,
    rating_avg,
    rating_count,
    follower_count,
    status
  )
  values (
    v_owner_id,
    'Samsung Galaxy Store',
    'samsung-galaxy',
    'Trải nghiệm công nghệ đỉnh cao từ Samsung chính hiệu.',
    'https://images.unsplash.com/photo-1610945265064-0e34e5519bbf?w=200&h=200&fit=crop',
    'https://images.unsplash.com/photo-1610945415295-d9b226b15d50?w=800&h=400&fit=crop',
    4.8,
    942,
    64000,
    'active'
  )
  on conflict (shop_slug) do update
  set
    shop_name = excluded.shop_name,
    description = excluded.description,
    logo_path = excluded.logo_path,
    cover_path = excluded.cover_path
  returning id into v_shop_samsung;

  -- 6. Seed Shop: Zara Apparel
  insert into public.shops (
    owner_id,
    shop_name,
    shop_slug,
    description,
    logo_path,
    cover_path,
    rating_avg,
    rating_count,
    follower_count,
    status
  )
  values (
    v_owner_id,
    'Zara Apparel',
    'zara-apparel',
    'Thương hiệu thời trang quốc tế dẫn đầu xu hướng.',
    'https://images.unsplash.com/photo-1544816155-12df9643f363?w=200&h=200&fit=crop',
    'https://images.unsplash.com/photo-1441986300917-64674bd600d8?w=800&h=400&fit=crop',
    4.7,
    428,
    31200,
    'active'
  )
  on conflict (shop_slug) do update
  set
    shop_name = excluded.shop_name,
    description = excluded.description,
    logo_path = excluded.logo_path,
    cover_path = excluded.cover_path
  returning id into v_shop_zara;

  -- 7. Seed Shop: Nike Sportswear
  insert into public.shops (
    owner_id,
    shop_name,
    shop_slug,
    description,
    logo_path,
    cover_path,
    rating_avg,
    rating_count,
    follower_count,
    status
  )
  values (
    v_owner_id,
    'Nike Sportswear',
    'nike-sportswear',
    'Cửa hàng phân phối giày dép và quần áo thể thao Nike chính hãng.',
    'https://images.unsplash.com/photo-1542291026-7eec264c27ff?w=200&h=200&fit=crop',
    'https://images.unsplash.com/photo-1482440308425-276ad0f28b19?w=800&h=400&fit=crop',
    4.8,
    1102,
    78500,
    'active'
  )
  on conflict (shop_slug) do update
  set
    shop_name = excluded.shop_name,
    description = excluded.description,
    logo_path = excluded.logo_path,
    cover_path = excluded.cover_path
  returning id into v_shop_nike;

  -- 8. Seed Products & Brand Linkages
  insert into public.products (
    id,
    shop_id,
    category_id,
    title,
    description,
    brand,
    status,
    price_min,
    price_max,
    currency,
    stock_total,
    sold_count,
    rating_avg,
    rating_count,
    cover_path
  )
  values
    -- APPLE SHOP PRODUCTS
    (
      '11111111-1111-4111-8111-111111111111',
      v_shop_apple,
      v_category_electronics,
      'iPhone 15 Pro Max 256GB Chính Hãng',
      'Điện thoại cao cấp thế hệ mới vỏ Titan, chip A17 Pro mạnh mẽ, camera zoom 5x sắc nét.',
      'Apple',
      'active',
      28990000,
      28990000,
      'VND',
      120,
      1580,
      4.9,
      328,
      'https://placehold.co/900x900/F6F6F6/111111?text=iPhone+15+Pro+Max'
    ),
    (
      '22222222-2222-4222-8222-222222222222',
      v_shop_apple,
      v_category_electronics,
      'iPad Air 6 M2 11-inch Liquid Retina',
      'Máy tính bảng mỏng nhẹ trang bị siêu chip Apple M2, hỗ trợ bút Apple Pencil Pro mới.',
      'Apple',
      'active',
      16990000,
      16990000,
      'VND',
      80,
      412,
      4.8,
      184,
      'https://placehold.co/900x900/E7E9EF/111111?text=iPad+Air+M2'
    ),
    -- SAMSUNG SHOP PRODUCTS
    (
      '33333333-3333-4333-8333-333333333333',
      v_shop_samsung,
      v_category_electronics,
      'Samsung Galaxy S24 Ultra 5G AI',
      'Kỷ nguyên Galaxy AI thế hệ mới, camera 200MP zoom không gian, kèm bút S Pen đa năng.',
      'Samsung',
      'active',
      25990000,
      25990000,
      'VND',
      95,
      641,
      4.8,
      276,
      'https://placehold.co/900x900/F2ECEC/111111?text=Galaxy+S24+Ultra'
    ),
    (
      '44444444-4444-4444-8444-444444444444',
      v_shop_samsung,
      v_category_accessories,
      'Tai Nghe Samsung Galaxy Buds FE',
      'Tai nghe bluetooth chống ồn chủ động ANC thông minh, âm bass sâu lắng, pin 30 giờ.',
      'Samsung',
      'active',
      1590000,
      1590000,
      'VND',
      240,
      952,
      4.6,
      152,
      'https://placehold.co/900x900/EDE7E1/111111?text=Galaxy+Buds+FE'
    ),
    -- ZARA SHOP PRODUCTS
    (
      '55555555-5555-4555-8555-555555555555',
      v_shop_zara,
      v_category_fashion,
      'Áo Thun Cotton Zara Oversize Unisex',
      'Chất vải thun cotton 100% dày dặn đứng form, thoáng khí, phong cách tối giản thanh lịch.',
      'Zara',
      'active',
      350000,
      350000,
      'VND',
      450,
      2140,
      4.7,
      96,
      'https://placehold.co/900x1200/CB1F2D/FFFFFF?text=Zara+Oversize+Tee'
    ),
    -- NIKE SHOP PRODUCTS
    (
      '66666666-6666-4666-8666-666666666666',
      v_shop_nike,
      v_category_fashion,
      'Giày Sneaker Nike Air Force 1 All White',
      'Mẫu giày quốc dân bất hủ chất liệu da cao cấp dễ phối mọi trang phục, đế đệm khí êm chân.',
      'Nike',
      'active',
      2990000,
      2990000,
      'VND',
      60,
      1200,
      4.9,
      412,
      'https://placehold.co/900x1200/1F1F1F/FFFFFF?text=Air+Force+1'
    ),
    (
      '77777777-7777-4777-8777-777777777777',
      v_shop_nike,
      v_category_fashion,
      'Túi Đeo Chéo Thể Thao Nike Heritage',
      'Túi đeo chéo mini vải poly kháng nước, nhiều ngăn khóa kéo tiện lợi khi dạo phố hay tập luyện.',
      'Nike',
      'active',
      650000,
      650000,
      'VND',
      180,
      890,
      4.7,
      233,
      'https://placehold.co/900x1200/F9F1E7/111111?text=Nike+Heritage+Bag'
    )
  on conflict (id) do update
  set
    shop_id = excluded.shop_id,
    category_id = excluded.category_id,
    title = excluded.title,
    description = excluded.description,
    brand = excluded.brand,
    status = excluded.status,
    price_min = excluded.price_min,
    price_max = excluded.price_max,
    currency = excluded.currency,
    stock_total = excluded.stock_total,
    sold_count = excluded.sold_count,
    rating_avg = excluded.rating_avg,
    rating_count = excluded.rating_count,
    cover_path = excluded.cover_path;

  -- 9. Re-seed Product Media
  insert into public.product_media (
    id,
    product_id,
    media_type,
    storage_path,
    sort_order
  )
  values
    ('11111111-1111-5111-8111-111111111111', '11111111-1111-4111-8111-111111111111', 'image', 'https://placehold.co/900x900/F6F6F6/111111?text=iPhone+15+Pro+Max', 0),
    ('22222222-2222-5222-8222-222222222222', '22222222-2222-4222-8222-222222222222', 'image', 'https://placehold.co/900x900/E7E9EF/111111?text=iPad+Air+M2', 0),
    ('33333333-3333-5333-8333-333333333333', '33333333-3333-4333-8333-333333333333', 'image', 'https://placehold.co/900x900/F2ECEC/111111?text=Galaxy+S24+Ultra', 0),
    ('44444444-4444-5444-8444-444444444444', '44444444-4444-4444-8444-444444444444', 'image', 'https://placehold.co/900x900/EDE7E1/111111?text=Galaxy+Buds+FE', 0),
    ('55555555-5555-5555-8555-555555555555', '55555555-5555-4555-8555-555555555555', 'image', 'https://placehold.co/900x1200/CB1F2D/FFFFFF?text=Zara+Oversize+Tee', 0),
    ('66666666-6666-5666-8666-666666666666', '66666666-6666-4666-8666-666666666666', 'image', 'https://placehold.co/900x1200/1F1F1F/FFFFFF?text=Air+Force+1', 0),
    ('77777777-7777-5777-8777-777777777777', '77777777-7777-4777-8777-777777777777', 'image', 'https://placehold.co/900x1200/F9F1E7/111111?text=Nike+Heritage+Bag', 0)
  on conflict (id) do update
  set
    product_id = excluded.product_id,
    media_type = excluded.media_type,
    storage_path = excluded.storage_path,
    sort_order = excluded.sort_order;

  -- 10. Re-seed Product Variants
  insert into public.product_variants (
    id,
    product_id,
    sku,
    variant_name,
    price,
    compare_at_price,
    stock_qty,
    weight_grams,
    status
  )
  values
    ('11111111-aaaa-4111-8111-111111111111', '11111111-1111-4111-8111-111111111111', 'IPHONE-256G-TITAN', 'Titan tự nhiên', 28990000, 31990000, 120, 221, 'active'),
    ('22222222-aaaa-4222-8222-222222222222', '22222222-2222-4222-8222-222222222222', 'IPAD-AIR-M2-11', 'Xám không gian', 16990000, 18990000, 80, 462, 'active'),
    ('33333333-aaaa-4333-8333-333333333333', '33333333-3333-4333-8333-333333333333', 'S24-ULTRA-512G', 'Titan xám', 25990000, 29990000, 95, 232, 'active'),
    ('44444444-aaaa-4444-8444-444444444444', '44444444-4444-4444-8444-444444444444', 'BUDS-FE-WHITE', 'Trắng', 1590000, 1990000, 240, 50, 'active'),
    ('55555555-aaaa-4555-8555-555555555555', '55555555-5555-4555-8555-555555555555', 'ZARA-TEE-L', 'Size L', 350000, 500000, 450, 180, 'active'),
    ('66666666-aaaa-4666-8666-666666666666', '66666666-6666-4666-8666-666666666666', 'NIKE-AF1-WHITE', 'Trắng 42', 2990000, 3290000, 60, 950, 'active'),
    ('77777777-aaaa-4777-8777-777777777777', '77777777-7777-4777-8777-777777777777', 'NIKE-BAG-BLACK', 'Đen', 650000, 750000, 180, 120, 'active')
  on conflict (id) do update
  set
    product_id = excluded.product_id,
    sku = excluded.sku,
    variant_name = excluded.variant_name,
    price = excluded.price,
    compare_at_price = excluded.compare_at_price,
    stock_qty = excluded.stock_qty,
    weight_grams = excluded.weight_grams,
    status = excluded.status;

  -- 11. Recalculate product_count dynamically for all shops
  update public.shops s
  set product_count = (
    select count(*)::int
    from public.products
    where shop_id = s.id and status = 'active'
  );

  -- 12. Recalculate average shop rating dynamically for all shops
  update public.shops s
  set 
    rating_avg = coalesce(x.avg_rating, 0),
    rating_count = coalesce(x.rating_count, 0)
  from (
    select 
      p.shop_id,
      coalesce(avg(pr.rating)::numeric(3,2), 0) as avg_rating,
      count(pr.id)::int as rating_count
    from public.products p
    left join public.product_reviews pr on pr.product_id = p.id
    group by p.shop_id
  ) x
  where s.id = x.shop_id;
end $$;


-- ==========================================================================
-- SECTION: ADMIN ORDERS POLICY PATCH
-- FILENAME: admin_orders_policy_patch.sql
-- ==========================================================================

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


-- ==========================================================================
-- SECTION: ADMIN WEB SHOPS BADGE PATCH
-- FILENAME: admin_web_shops_badge_patch.sql
-- ==========================================================================

-- SQL Patch: Add has_blue_badge to shops table for platform admin verified tick checkmark.
-- Execute this script in your Supabase SQL Editor.

-- 1. Add column if it does not exist
ALTER TABLE public.shops 
ADD COLUMN IF NOT EXISTS has_blue_badge boolean NOT NULL DEFAULT false;

-- 2. Grant read/write access to authenticated users and service role (for safety)
ALTER TABLE public.shops ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Shops are insertable by authenticated users" ON public.shops;
CREATE POLICY "Shops are insertable by authenticated users" 
ON public.shops 
FOR INSERT 
TO authenticated 
WITH CHECK (auth.uid() = owner_id);

DROP POLICY IF EXISTS "Shops are updatable by owners or admins" ON public.shops;
CREATE POLICY "Shops are updatable by owners or admins" 
ON public.shops 
FOR UPDATE 
TO authenticated 
USING (auth.uid() = owner_id OR (select exists (select 1 from public.profiles where id = auth.uid() AND is_verified = true)));


-- ==========================================================================
-- SECTION: CHECKOUT MVP POLICIES PATCH
-- FILENAME: checkout_mvp_policies.sql
-- ==========================================================================

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


-- ==========================================================================
-- SECTION: PRODUCT DISCOUNT PATCH
-- FILENAME: product_discount_patch.sql
-- ==========================================================================

-- PATCH TO SUPPORT DYNAMIC DISCOUNTS IN SHARECO
-- Run this script in your Supabase SQL Editor to update your tables and enable discount rendering on the mobile app.

-- 1. Add 'original_price' column to 'products' table
alter table public.products 
add column if not exists original_price numeric(15,2) default null;

-- 2. Add 'original_price' column to 'product_variants' table
alter table public.product_variants 
add column if not exists original_price numeric(15,2) default null;

-- 3. Seed some sample discount prices for current seed products
-- Apple: Samsung Galaxy Buds FE (ID: 44444444-4444-4444-8444-444444444444)
-- Price is 1.590.000, set original price to 1.890.000 (~16% off)
update public.products 
set original_price = 1890000 
where id = '44444444-4444-4444-8444-444444444444';

-- Samsung: Galaxy S24 Ultra (ID: 33333333-3333-4333-8333-333333333333)
-- Price is 25.990.000, set original price to 29.990.000 (~13% off)
update public.products 
set original_price = 29990000 
where id = '33333333-3333-4333-8333-333333333333';

-- Zara: Áo Thun Cotton Zara Oversize Unisex (ID: 55555555-5555-4555-8555-555555555555)
-- Price is 350.000, set original price to 490.000 (~29% off)
update public.products 
set original_price = 490000 
where id = '55555555-5555-4555-8555-555555555555';


-- ==========================================================================
-- SECTION: USER ORDER ACTIONS PATCH
-- FILENAME: user_order_actions.sql
-- ==========================================================================

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
