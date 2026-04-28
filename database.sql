Flutter đa nền tảng
Cơ sở dữ liệu TikTok + TikTok Shop
trên Supabase
Tài liệu tổng hợp schema SQL, RLS, trigger, RPC và lưu ý triển khai MVP+
Mục tiêu	Một bộ schema thực dụng để build app kiểu TikTok + TikTok Shop bằng Flutter và Supabase.
Phạm vi	Auth, hồ sơ người dùng, video, comment, like, shop, sản phẩm, giỏ hàng, đơn hàng, thanh toán, review, notification, report.
Ghi chú	Tài liệu này gom toàn bộ nội dung đã thảo luận thành một file Word để tiện lưu trữ và copy sang Supabase migrations.


1. Tổng quan kiến trúc
Thiết kế này ưu tiên tính thực dụng cho Flutter đa nền tảng và Supabase: Postgres làm nguồn dữ liệu chính, Auth cho định danh, Storage cho media, RLS cho bảo mật và Edge Functions cho nghiệp vụ nhạy cảm.
Social: hồ sơ, follow, video, hashtag, like, comment.
Commerce: shop, sản phẩm, variant, cart, địa chỉ, order, payment, review.
System: notifications, reports, counters, trigger, RPC cơ bản.
2. Thứ tự chạy migrations
001_extensions.sql
002_profiles.sql
003_social.sql
004_videos.sql
005_shop.sql
006_orders.sql
007_reviews_notifications.sql
008_triggers.sql
009_rls.sql
010_rpc.sql
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
31. Reports / moderation
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
32. Enable RLS
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
alter table public.reports enable row level security;
33. Policy cơ bản
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

create policy "reports_insert_own"
on public.reports
for insert
with check (auth.uid() = reporter_id);

create policy "reports_read_own"
on public.reports
for select
using (auth.uid() = reporter_id);
34. RPC hữu ích
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
35. Gợi ý bucket Storage
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
- product-media/{shop_id}/{product_id}/...
36. Những phần nên làm bằng Edge Function
- tạo order từ cart
- tạo payment intent
- nhận webhook thanh toán
- cập nhật orders.status
- trừ tồn kho
- hoàn tiền
- moderation/admin actions
37. Lưu ý thực chiến
1. Orders không nên cho client insert trực tiếp nếu sau này có payment thật.
2. Counter như like_count, comment_count, follower_count phải cập nhật bằng trigger hoặc server logic.
3. Feed “For You” không nên query raw từ app; nên có recommendation layer riêng.
4. Nên tách migration file theo domain để dễ rollback và review.
38. Kết luận
Bộ schema này phù hợp để khởi động một dự án Flutter đa nền tảng theo mô hình TikTok + TikTok Shop trên Supabase. Bạn có thể tách từng phần thành migration riêng hoặc dùng tài liệu này như bản master để rà soát kiến trúc trước khi triển khai.
Bước tiếp theo: tách file migration chuẩn Supabase CLI, hoặc sinh Dart models và repositories cho Flutter từ schema này.