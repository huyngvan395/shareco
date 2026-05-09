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
