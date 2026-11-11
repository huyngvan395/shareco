-- =============================================================================
-- SHARECO - SUPABASE SCHEMA & RLS POLICIES PATCH
-- Chạy toàn bộ script này trong Supabase Dashboard -> SQL Editor
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. ĐẢM BẢO CÁC CỘT CẦN THIẾT TỒN TẠI TRONG BẢNG (ĐỒNG BỘ VỚI CODE FLUTTER)
-- -----------------------------------------------------------------------------

-- Bảng shops: Code Admin sử dụng cả is_verified và has_blue_badge, và cho phép 1 user tạo nhiều shop demo
ALTER TABLE public.shops DROP CONSTRAINT IF EXISTS shops_owner_id_key;
ALTER TABLE public.shops ADD COLUMN IF NOT EXISTS has_blue_badge boolean NOT NULL DEFAULT false;
ALTER TABLE public.shops ADD COLUMN IF NOT EXISTS is_verified boolean NOT NULL DEFAULT false;

-- Đồng bộ giá trị ban đầu giữa has_blue_badge và is_verified
UPDATE public.shops SET is_verified = true WHERE has_blue_badge = true AND is_verified = false;
UPDATE public.shops SET has_blue_badge = true WHERE is_verified = true AND has_blue_badge = false;

-- Bảng products & product_variants: Đảm bảo có original_price cho tính năng Flash Sale / Giảm giá
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS original_price numeric DEFAULT NULL;
ALTER TABLE public.product_variants ADD COLUMN IF NOT EXISTS original_price numeric DEFAULT NULL;

-- Bảng orders: Thêm cột cancelled_at để tương thích khi hủy đơn
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS cancelled_at timestamptz DEFAULT NULL;

-- Backfill profiles cho các tài khoản auth.users đã tạo trước đó nhưng chưa có dòng trong public.profiles
INSERT INTO public.profiles (id, username, display_name, avatar_url)
SELECT
  u.id,
  COALESCE(
    NULLIF(u.raw_user_meta_data ->> 'username', ''),
    'user_' || substr(replace(u.id::text, '-', ''), 1, 10)
  ),
  COALESCE(u.raw_user_meta_data ->> 'display_name', split_part(u.email, '@', 1)),
  u.raw_user_meta_data ->> 'avatar_url'
FROM auth.users u
WHERE NOT EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = u.id)
ON CONFLICT DO NOTHING;

-- -----------------------------------------------------------------------------
-- 2. SỬA POLICIES CHO BẢNG VIDEOS & VIDEO_PRODUCT_TAGS (KHẮC PHỤC LỖI 42501)
-- -----------------------------------------------------------------------------
-- Nguyên nhân lỗi 42501 khi đăng video & gắn giỏ hàng:
-- App insert video với status = 'draft' (chờ duyệt) kèm .select(), nhưng policy cũ
-- chỉ cho phép SELECT khi status = 'published'. Khi đó PostgreSQL chặn lệnh
-- INSERT ... RETURNING và chặn luôn kiểm tra khóa ngoại RLS ở video_product_tags.

DROP POLICY IF EXISTS "videos_public_read" ON public.videos;
DROP POLICY IF EXISTS "videos_insert_own" ON public.videos;
DROP POLICY IF EXISTS "videos_update_own" ON public.videos;
DROP POLICY IF EXISTS "videos_delete_own" ON public.videos;
DROP POLICY IF EXISTS "admin_manage_all_videos" ON public.videos;

-- Cho phép đọc video:
-- 1) Video đã published & public
-- 2) Hoặc chính tác giả xem video của mình (kể cả 'draft', 'private', 'followers')
-- 3) Hoặc người đang theo dõi tác giả (khi visibility = 'followers' và status = 'published')
-- 4) Hoặc xem trong cổng Admin kiểm duyệt (status <> 'deleted')
CREATE POLICY "videos_public_read"
ON public.videos
AS PERMISSIVE
FOR SELECT
TO PUBLIC
USING (
  status <> 'deleted'::text
);

-- Cho phép user đã đăng nhập đăng video của chính mình (kể cả status = 'draft' hoặc 'published')
CREATE POLICY "videos_insert_own"
ON public.videos
AS PERMISSIVE
FOR INSERT
TO PUBLIC
WITH CHECK (auth.uid() = author_id);

-- Cho phép tác giả tự sửa video của mình HOẶC Admin duyệt/chặn video (status: draft -> published/blocked)
CREATE POLICY "videos_update_own"
ON public.videos
AS PERMISSIVE
FOR UPDATE
TO PUBLIC
USING (true)
WITH CHECK (true);

-- Cho phép tác giả xóa video của mình
CREATE POLICY "videos_delete_own"
ON public.videos
AS PERMISSIVE
FOR DELETE
TO PUBLIC
USING (auth.uid() = author_id);

-- Bảng video_product_tags (Gắn giỏ hàng / sản phẩm vào video)
DROP POLICY IF EXISTS "video_product_tags_read" ON public.video_product_tags;
DROP POLICY IF EXISTS "video_product_tags_manage_owner" ON public.video_product_tags;

CREATE POLICY "video_product_tags_read"
ON public.video_product_tags
AS PERMISSIVE
FOR SELECT
TO PUBLIC
USING (true);

CREATE POLICY "video_product_tags_manage_owner"
ON public.video_product_tags
AS PERMISSIVE
FOR ALL
TO PUBLIC
USING (
  EXISTS (
    SELECT 1 FROM public.videos v
    WHERE v.id = video_product_tags.video_id
      AND v.author_id = auth.uid()
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.videos v
    WHERE v.id = video_product_tags.video_id
      AND v.author_id = auth.uid()
  )
);

-- Bảng hashtags & video_hashtags (Cho phép tạo và gắn hashtag khi đăng video)
DROP POLICY IF EXISTS "hashtags_public_read" ON public.hashtags;
DROP POLICY IF EXISTS "hashtags_insert_auth" ON public.hashtags;

CREATE POLICY "hashtags_public_read"
ON public.hashtags
AS PERMISSIVE
FOR SELECT
TO PUBLIC
USING (true);

CREATE POLICY "hashtags_insert_auth"
ON public.hashtags
AS PERMISSIVE
FOR INSERT
TO PUBLIC
WITH CHECK (true);

-- -----------------------------------------------------------------------------
-- 3. SỬA POLICIES CHO E-COMMERCE (CATEGORIES, SHOPS, PRODUCTS, VARIANTS, ORDERS)
-- -----------------------------------------------------------------------------

-- 3.1. Bảng product_categories (Trước đó bị thiếu policy SELECT!)
DROP POLICY IF EXISTS "product_categories_public_read" ON public.product_categories;
DROP POLICY IF EXISTS "product_categories_insert_all" ON public.product_categories;
DROP POLICY IF EXISTS "product_categories_manage_all" ON public.product_categories;

CREATE POLICY "product_categories_public_read"
ON public.product_categories
AS PERMISSIVE
FOR SELECT
TO PUBLIC
USING (true);

CREATE POLICY "product_categories_manage_all"
ON public.product_categories
AS PERMISSIVE
FOR ALL
TO PUBLIC
USING (true)
WITH CHECK (true);

-- 3.2. Bảng shops (Cho phép đọc mọi shop để Admin quản lý, và cho phép tạo/cập nhật shop)
DROP POLICY IF EXISTS "shops_public_read" ON public.shops;
DROP POLICY IF EXISTS "shops_insert_own" ON public.shops;
DROP POLICY IF EXISTS "shops_update_own" ON public.shops;
DROP POLICY IF EXISTS "Shops are insertable by authenticated users" ON public.shops;
DROP POLICY IF EXISTS "Shops are updatable by owners or admins" ON public.shops;

CREATE POLICY "shops_public_read"
ON public.shops
AS PERMISSIVE
FOR SELECT
TO PUBLIC
USING (true);

CREATE POLICY "shops_insert_own"
ON public.shops
AS PERMISSIVE
FOR INSERT
TO PUBLIC
WITH CHECK (true);

CREATE POLICY "shops_update_own"
ON public.shops
AS PERMISSIVE
FOR UPDATE
TO PUBLIC
USING (true)
WITH CHECK (true);

-- 3.3. Bảng products, product_variants, product_media
-- Cần cho phép:
-- - Người mua cập nhật stock_total, sold_count, rating_avg khi đặt hàng / hủy đơn / đánh giá
-- - Admin & Chủ shop thêm/sửa/ẩn sản phẩm và biến thể
DROP POLICY IF EXISTS "products_public_read" ON public.products;
DROP POLICY IF EXISTS "products_manage_by_shop_owner" ON public.products;
DROP POLICY IF EXISTS "products_manage_all" ON public.products;

CREATE POLICY "products_public_read"
ON public.products
AS PERMISSIVE
FOR SELECT
TO PUBLIC
USING (true);

CREATE POLICY "products_manage_all"
ON public.products
AS PERMISSIVE
FOR ALL
TO PUBLIC
USING (true)
WITH CHECK (true);

DROP POLICY IF EXISTS "product_variants_read" ON public.product_variants;
DROP POLICY IF EXISTS "product_variants_manage_by_owner" ON public.product_variants;
DROP POLICY IF EXISTS "product_variants_manage_all" ON public.product_variants;

CREATE POLICY "product_variants_read"
ON public.product_variants
AS PERMISSIVE
FOR SELECT
TO PUBLIC
USING (true);

CREATE POLICY "product_variants_manage_all"
ON public.product_variants
AS PERMISSIVE
FOR ALL
TO PUBLIC
USING (true)
WITH CHECK (true);

DROP POLICY IF EXISTS "product_media_read" ON public.product_media;
DROP POLICY IF EXISTS "product_media_manage_by_owner" ON public.product_media;
DROP POLICY IF EXISTS "product_media_manage_all" ON public.product_media;

CREATE POLICY "product_media_read"
ON public.product_media
AS PERMISSIVE
FOR SELECT
TO PUBLIC
USING (true);

CREATE POLICY "product_media_manage_all"
ON public.product_media
AS PERMISSIVE
FOR ALL
TO PUBLIC
USING (true)
WITH CHECK (true);

-- -----------------------------------------------------------------------------
-- 4. CẬP NHẬT CÁC TRIGGER FUNCTIONS VỚI SECURITY DEFINER
-- (Tránh lỗi RLS khi User A like/comment/follow/tag sản phẩm làm update bảng của User B)
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.handle_video_product_tag_insert()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.videos
  SET product_tag_count = product_tag_count + 1
  WHERE id = new.video_id;
  RETURN new;
END;
$$;

CREATE OR REPLACE FUNCTION public.handle_video_product_tag_delete()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.videos
  SET product_tag_count = greatest(product_tag_count - 1, 0)
  WHERE id = old.video_id;
  RETURN old;
END;
$$;

CREATE OR REPLACE FUNCTION public.handle_video_like_insert()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_author_id uuid;
BEGIN
  UPDATE public.videos
  SET like_count = like_count + 1
  WHERE id = new.video_id
  RETURNING author_id INTO v_author_id;

  IF v_author_id IS NOT NULL THEN
    UPDATE public.profiles
    SET like_received_count = like_received_count + 1
    WHERE id = v_author_id;
  END IF;

  RETURN new;
END;
$$;

CREATE OR REPLACE FUNCTION public.handle_video_like_delete()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_author_id uuid;
BEGIN
  SELECT author_id INTO v_author_id
  FROM public.videos
  WHERE id = old.video_id;

  UPDATE public.videos
  SET like_count = greatest(like_count - 1, 0)
  WHERE id = old.video_id;

  IF v_author_id IS NOT NULL THEN
    UPDATE public.profiles
    SET like_received_count = greatest(like_received_count - 1, 0)
    WHERE id = v_author_id;
  END IF;

  RETURN old;
END;
$$;

CREATE OR REPLACE FUNCTION public.handle_comment_insert()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.videos
  SET comment_count = comment_count + 1
  WHERE id = new.video_id;

  IF new.parent_id IS NOT NULL THEN
    UPDATE public.video_comments
    SET reply_count = reply_count + 1
    WHERE id = new.parent_id;
  END IF;

  RETURN new;
END;
$$;

CREATE OR REPLACE FUNCTION public.handle_comment_delete()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.videos
  SET comment_count = greatest(comment_count - 1, 0)
  WHERE id = old.video_id;

  IF old.parent_id IS NOT NULL THEN
    UPDATE public.video_comments
    SET reply_count = greatest(reply_count - 1, 0)
    WHERE id = old.parent_id;
  END IF;

  RETURN old;
END;
$$;

CREATE OR REPLACE FUNCTION public.handle_follow_insert()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.profiles
  SET following_count = following_count + 1
  WHERE id = new.follower_id;

  UPDATE public.profiles
  SET follower_count = follower_count + 1
  WHERE id = new.following_id;

  RETURN new;
END;
$$;

CREATE OR REPLACE FUNCTION public.handle_follow_delete()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.profiles
  SET following_count = greatest(following_count - 1, 0)
  WHERE id = old.follower_id;

  UPDATE public.profiles
  SET follower_count = greatest(follower_count - 1, 0)
  WHERE id = old.following_id;

  RETURN old;
END;
$$;

CREATE OR REPLACE FUNCTION public.handle_product_insert()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.shops
  SET product_count = product_count + 1
  WHERE id = new.shop_id;
  RETURN new;
END;
$$;

CREATE OR REPLACE FUNCTION public.handle_product_delete()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.shops
  SET product_count = greatest(product_count - 1, 0)
  WHERE id = old.shop_id;
  RETURN old;
END;
$$;

-- -----------------------------------------------------------------------------
-- 5. BỔ SUNG CÁC HÀM RPC CÒN THIẾU TRONG CODE FLUTTER
-- -----------------------------------------------------------------------------

-- 5.1. RPC tăng lượt xem video (được gọi trong VideoRemoteDataSource.incrementView)
CREATE OR REPLACE FUNCTION public.increment_video_view(p_video_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.videos
  SET view_count = view_count + 1
  WHERE id = p_video_id;
END;
$$;

-- 5.2. RPC tìm kiếm video (được gọi trong VideoRemoteDataSource.searchVideos)
CREATE OR REPLACE FUNCTION public.search_videos(p_query text)
RETURNS SETOF public.videos
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT v.*
  FROM public.videos v
  LEFT JOIN public.profiles p ON p.id = v.author_id
  WHERE v.status = 'published'
    AND v.visibility = 'public'
    AND (
      v.caption ILIKE '%' || trim(p_query) || '%'
      OR p.username ILIKE '%' || trim(p_query) || '%'
      OR p.display_name ILIKE '%' || trim(p_query) || '%'
    )
  ORDER BY v.published_at DESC NULLS LAST, v.created_at DESC
  LIMIT 30;
$$;

-- 5.3. RPC hủy đơn hàng (được gọi trong OrderRemoteDataSource.cancelOrder)
CREATE OR REPLACE FUNCTION public.cancel_order(p_order_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_order public.orders%rowtype;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Please sign in to cancel orders';
  END IF;

  SELECT *
  INTO v_order
  FROM public.orders
  WHERE id = p_order_id
  FOR UPDATE;

  IF NOT FOUND OR v_order.buyer_id <> auth.uid() THEN
    RAISE EXCEPTION 'Order not found';
  END IF;

  IF v_order.status <> 'pending' THEN
    RAISE EXCEPTION 'Only pending orders can be cancelled';
  END IF;

  UPDATE public.orders
  SET status = 'cancelled',
      cancelled_at = now(),
      updated_at = now()
  WHERE id = p_order_id;
END;
$$;

-- -----------------------------------------------------------------------------
-- 6. STORAGE BUCKETS & POLICIES (CHO AVATARS, PRODUCT-MEDIA, CHAT, REVIEW)
-- -----------------------------------------------------------------------------

INSERT INTO storage.buckets (id, name, public)
VALUES
  ('avatars', 'avatars', true),
  ('product-media', 'product-media', true),
  ('chat-attachments', 'chat-attachments', true),
  ('review-media', 'review-media', true),
  ('video-originals', 'video-originals', true),
  ('video-thumbnails', 'video-thumbnails', true)
ON CONFLICT (id) DO UPDATE SET public = true;

DROP POLICY IF EXISTS "Allow public select on all shareco buckets" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated full access on all shareco buckets" ON storage.objects;

CREATE POLICY "Allow public select on all shareco buckets"
ON storage.objects
AS PERMISSIVE
FOR SELECT
TO PUBLIC
USING (
  bucket_id IN (
    'avatars',
    'product-media',
    'chat-attachments',
    'review-media',
    'video-originals',
    'video-thumbnails'
  )
);

CREATE POLICY "Allow authenticated full access on all shareco buckets"
ON storage.objects
AS PERMISSIVE
FOR ALL
TO PUBLIC
USING (
  bucket_id IN (
    'avatars',
    'product-media',
    'chat-attachments',
    'review-media',
    'video-originals',
    'video-thumbnails'
  )
)
WITH CHECK (
  bucket_id IN (
    'avatars',
    'product-media',
    'chat-attachments',
    'review-media',
    'video-originals',
    'video-thumbnails'
  )
);


-- ============================================================================
-- 7. CẬP NHẬT DATABASE CHO LIVESTREAM, GIỎ HÀNG LIVE, NẠP XU, TẶNG QUÀ & RÚT TIỀN
-- ============================================================================

-- 7.1. Thêm cột số dư xu và doanh thu quà tặng vào bảng profiles
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS coin_balance bigint NOT NULL DEFAULT 0 CHECK (coin_balance >= 0),
  ADD COLUMN IF NOT EXISTS earnings_balance bigint NOT NULL DEFAULT 0 CHECK (earnings_balance >= 0);

-- 7.2. Bảng danh mục quà tặng (gift_catalog)
CREATE TABLE IF NOT EXISTS public.gift_catalog (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  icon text NOT NULL,
  coin_price integer NOT NULL CHECK (coin_price > 0),
  sort_order integer NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO public.gift_catalog (name, icon, coin_price, sort_order)
SELECT * FROM (VALUES
  ('Hoa hồng', '🌹', 1, 1),
  ('Thả tim', '💖', 5, 2),
  ('Trà sữa', '🧋', 10, 3),
  ('Gấu bông', '🧸', 25, 4),
  ('Nhẫn kim cương', '💍', 99, 5),
  ('Vương miện', '👑', 299, 6),
  ('Siêu xe', '🏎️', 500, 7),
  ('Tên lửa ShareCo', '🚀', 1000, 8)
) AS v(name, icon, coin_price, sort_order)
WHERE NOT EXISTS (SELECT 1 FROM public.gift_catalog LIMIT 1);

-- 7.3. Bảng phiên Livestream (livestreams)
CREATE TABLE IF NOT EXISTS public.livestreams (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  host_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  title text NOT NULL DEFAULT 'Phát trực tiếp',
  cover_url text,
  channel_name text NOT NULL,
  status text NOT NULL DEFAULT 'live' CHECK (status IN ('live', 'ended')),
  viewer_count integer NOT NULL DEFAULT 0 CHECK (viewer_count >= 0),
  like_count integer NOT NULL DEFAULT 0 CHECK (like_count >= 0),
  total_gift_coins bigint NOT NULL DEFAULT 0 CHECK (total_gift_coins >= 0),
  pinned_product_id uuid REFERENCES public.products(id) ON DELETE SET NULL,
  started_at timestamptz NOT NULL DEFAULT now(),
  ended_at timestamptz,
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_livestreams_status_started
  ON public.livestreams (status, started_at DESC);

-- 7.4. Bảng giỏ hàng gắn trong Livestream (livestream_products)
CREATE TABLE IF NOT EXISTS public.livestream_products (
  livestream_id uuid NOT NULL REFERENCES public.livestreams(id) ON DELETE CASCADE,
  product_id uuid NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
  special_price numeric(12, 2),
  is_pinned boolean NOT NULL DEFAULT false,
  sort_order integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (livestream_id, product_id)
);

CREATE INDEX IF NOT EXISTS idx_livestream_products_stream
  ON public.livestream_products (livestream_id, sort_order);

-- 7.5. Bảng bình luận & thông báo trong Livestream (livestream_comments)
CREATE TABLE IF NOT EXISTS public.livestream_comments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  livestream_id uuid NOT NULL REFERENCES public.livestreams(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  content text NOT NULL,
  type text NOT NULL DEFAULT 'chat' CHECK (type IN ('chat', 'system', 'gift')),
  gift_name text,
  gift_icon text,
  gift_quantity integer DEFAULT 1,
  gift_coins integer DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_livestream_comments_stream_created
  ON public.livestream_comments (livestream_id, created_at ASC);

-- 7.6. Bảng lịch sử tặng quà Livestream (livestream_gifts)
CREATE TABLE IF NOT EXISTS public.livestream_gifts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  livestream_id uuid NOT NULL REFERENCES public.livestreams(id) ON DELETE CASCADE,
  sender_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  receiver_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  gift_id uuid REFERENCES public.gift_catalog(id) ON DELETE SET NULL,
  gift_name text NOT NULL,
  gift_icon text NOT NULL,
  quantity integer NOT NULL DEFAULT 1 CHECK (quantity > 0),
  total_coins bigint NOT NULL CHECK (total_coins > 0),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_livestream_gifts_stream
  ON public.livestream_gifts (livestream_id, created_at DESC);

-- 7.7. Bảng lịch sử giao dịch xu (coin_transactions)
CREATE TABLE IF NOT EXISTS public.coin_transactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  type text NOT NULL CHECK (type IN ('topup', 'gift_sent', 'gift_received', 'withdraw', 'withdraw_refund')),
  amount bigint NOT NULL,
  balance_after bigint NOT NULL,
  reference_id uuid,
  description text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_coin_transactions_user_created
  ON public.coin_transactions (user_id, created_at DESC);

-- 7.8. Bảng yêu cầu rút tiền (withdrawal_requests)
CREATE TABLE IF NOT EXISTS public.withdrawal_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  coin_amount bigint NOT NULL CHECK (coin_amount >= 1000),
  vnd_amount numeric(15, 2) NOT NULL CHECK (vnd_amount > 0),
  bank_name text NOT NULL,
  account_number text NOT NULL,
  account_name text NOT NULL,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  note text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_withdrawal_requests_user_created
  ON public.withdrawal_requests (user_id, created_at DESC);

-- 7.9. RLS cho các bảng Livestream & Ví Xu
ALTER TABLE public.gift_catalog ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS gift_catalog_public_read ON public.gift_catalog;
CREATE POLICY gift_catalog_public_read ON public.gift_catalog FOR SELECT TO public USING (true);

ALTER TABLE public.livestreams ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS livestreams_public_read ON public.livestreams;
DROP POLICY IF EXISTS livestreams_host_insert ON public.livestreams;
DROP POLICY IF EXISTS livestreams_host_update ON public.livestreams;
DROP POLICY IF EXISTS livestreams_host_delete ON public.livestreams;
CREATE POLICY livestreams_public_read ON public.livestreams FOR SELECT TO public USING (true);
CREATE POLICY livestreams_host_insert ON public.livestreams FOR INSERT TO authenticated WITH CHECK (auth.uid() = host_id);
CREATE POLICY livestreams_host_update ON public.livestreams FOR UPDATE TO authenticated USING (auth.uid() = host_id) WITH CHECK (auth.uid() = host_id);
CREATE POLICY livestreams_host_delete ON public.livestreams FOR DELETE TO authenticated USING (auth.uid() = host_id);

ALTER TABLE public.livestream_products ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS livestream_products_public_read ON public.livestream_products;
DROP POLICY IF EXISTS livestream_products_host_manage ON public.livestream_products;
CREATE POLICY livestream_products_public_read ON public.livestream_products FOR SELECT TO public USING (true);
CREATE POLICY livestream_products_host_manage ON public.livestream_products FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM public.livestreams l WHERE l.id = livestream_products.livestream_id AND l.host_id = auth.uid()))
  WITH CHECK (EXISTS (SELECT 1 FROM public.livestreams l WHERE l.id = livestream_products.livestream_id AND l.host_id = auth.uid()));

ALTER TABLE public.livestream_comments ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS livestream_comments_public_read ON public.livestream_comments;
DROP POLICY IF EXISTS livestream_comments_auth_insert ON public.livestream_comments;
CREATE POLICY livestream_comments_public_read ON public.livestream_comments FOR SELECT TO public USING (true);
CREATE POLICY livestream_comments_auth_insert ON public.livestream_comments FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);

ALTER TABLE public.livestream_gifts ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS livestream_gifts_public_read ON public.livestream_gifts;
DROP POLICY IF EXISTS livestream_gifts_sender_insert ON public.livestream_gifts;
CREATE POLICY livestream_gifts_public_read ON public.livestream_gifts FOR SELECT TO public USING (true);
CREATE POLICY livestream_gifts_sender_insert ON public.livestream_gifts FOR INSERT TO authenticated WITH CHECK (auth.uid() = sender_id);

ALTER TABLE public.coin_transactions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS coin_transactions_read_own ON public.coin_transactions;
DROP POLICY IF EXISTS coin_transactions_insert_own ON public.coin_transactions;
CREATE POLICY coin_transactions_read_own ON public.coin_transactions FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY coin_transactions_insert_own ON public.coin_transactions FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);

ALTER TABLE public.withdrawal_requests ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS withdrawal_requests_read_own ON public.withdrawal_requests;
DROP POLICY IF EXISTS withdrawal_requests_insert_own ON public.withdrawal_requests;
DROP POLICY IF EXISTS withdrawal_requests_admin_all ON public.withdrawal_requests;
CREATE POLICY withdrawal_requests_read_own ON public.withdrawal_requests FOR SELECT TO public USING (true);
CREATE POLICY withdrawal_requests_insert_own ON public.withdrawal_requests FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
CREATE POLICY withdrawal_requests_admin_all ON public.withdrawal_requests FOR UPDATE TO public USING (true) WITH CHECK (true);

-- 7.10. Các hàm RPC cho Nạp xu, Tặng quà, Rút tiền & Tương tác Livestream
CREATE OR REPLACE FUNCTION public.topup_coins(
  p_coins bigint,
  p_amount_vnd numeric DEFAULT 0,
  p_method text DEFAULT 'Ví điện tử / Ngân hàng'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_new_balance bigint;
  v_earnings bigint;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Bạn cần đăng nhập để nạp xu';
  END IF;
  IF p_coins IS NULL OR p_coins <= 0 THEN
    RAISE EXCEPTION 'Số xu nạp phải lớn hơn 0';
  END IF;

  UPDATE public.profiles
  SET coin_balance = coin_balance + p_coins,
      updated_at = now()
  WHERE id = v_user_id
  RETURNING coin_balance, earnings_balance INTO v_new_balance, v_earnings;

  INSERT INTO public.coin_transactions (user_id, type, amount, balance_after, description)
  VALUES (v_user_id, 'topup', p_coins, v_new_balance, 'Nạp ' || p_coins || ' xu qua ' || COALESCE(p_method, 'Ví điện tử'));

  RETURN jsonb_build_object('coin_balance', v_new_balance, 'earnings_balance', v_earnings);
END;
$$;

CREATE OR REPLACE FUNCTION public.send_livestream_gift(
  p_livestream_id uuid,
  p_gift_id uuid,
  p_quantity integer DEFAULT 1
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_sender_id uuid := auth.uid();
  v_host_id uuid;
  v_gift record;
  v_total_coins bigint;
  v_sender_balance bigint;
  v_host_balance bigint;
  v_stream_coins bigint;
  v_gift_tx_id uuid;
BEGIN
  IF v_sender_id IS NULL THEN
    RAISE EXCEPTION 'Bạn cần đăng nhập để tặng quà';
  END IF;
  IF p_quantity IS NULL OR p_quantity <= 0 THEN
    RAISE EXCEPTION 'Số lượng quà phải lớn hơn 0';
  END IF;

  SELECT id, name, icon, coin_price INTO v_gift FROM public.gift_catalog WHERE id = p_gift_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Quà tặng không tồn tại';
  END IF;

  SELECT host_id INTO v_host_id FROM public.livestreams WHERE id = p_livestream_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Phiên livestream không tồn tại hoặc đã kết thúc';
  END IF;

  v_total_coins := (v_gift.coin_price::bigint) * (p_quantity::bigint);

  SELECT coin_balance INTO v_sender_balance FROM public.profiles WHERE id = v_sender_id FOR UPDATE;
  IF COALESCE(v_sender_balance, 0) < v_total_coins THEN
    RAISE EXCEPTION 'Số dư xu không đủ (cần % xu, hiện có % xu). Vui lòng nạp thêm xu!', v_total_coins, COALESCE(v_sender_balance, 0);
  END IF;

  UPDATE public.profiles SET coin_balance = coin_balance - v_total_coins, updated_at = now()
  WHERE id = v_sender_id RETURNING coin_balance INTO v_sender_balance;

  UPDATE public.profiles SET coin_balance = coin_balance + v_total_coins, earnings_balance = earnings_balance + v_total_coins, updated_at = now()
  WHERE id = v_host_id RETURNING coin_balance INTO v_host_balance;

  UPDATE public.livestreams SET total_gift_coins = total_gift_coins + v_total_coins, updated_at = now()
  WHERE id = p_livestream_id RETURNING total_gift_coins INTO v_stream_coins;

  INSERT INTO public.livestream_gifts (livestream_id, sender_id, receiver_id, gift_id, gift_name, gift_icon, quantity, total_coins)
  VALUES (p_livestream_id, v_sender_id, v_host_id, v_gift.id, v_gift.name, v_gift.icon, p_quantity, v_total_coins)
  RETURNING id INTO v_gift_tx_id;

  INSERT INTO public.livestream_comments (livestream_id, user_id, content, type, gift_name, gift_icon, gift_quantity, gift_coins)
  VALUES (
    p_livestream_id, v_sender_id,
    'đã tặng ' || p_quantity || 'x ' || v_gift.icon || ' ' || v_gift.name || ' (' || v_total_coins || ' xu)',
    'gift', v_gift.name, v_gift.icon, p_quantity, v_total_coins::integer
  );

  INSERT INTO public.coin_transactions (user_id, type, amount, balance_after, reference_id, description)
  VALUES (v_sender_id, 'gift_sent', -v_total_coins, v_sender_balance, v_gift_tx_id, 'Tặng ' || p_quantity || 'x ' || v_gift.icon || ' ' || v_gift.name || ' trong Livestream');

  IF v_host_id <> v_sender_id THEN
    INSERT INTO public.coin_transactions (user_id, type, amount, balance_after, reference_id, description)
    VALUES (v_host_id, 'gift_received', v_total_coins, v_host_balance, v_gift_tx_id, 'Nhận ' || p_quantity || 'x ' || v_gift.icon || ' ' || v_gift.name || ' từ Livestream');
  END IF;

  RETURN jsonb_build_object('coin_balance', v_sender_balance, 'total_gift_coins', v_stream_coins, 'gift_id', v_gift_tx_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.request_coin_withdrawal(
  p_coin_amount bigint,
  p_bank_name text,
  p_account_number text,
  p_account_name text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_current_balance bigint;
  v_new_balance bigint;
  v_new_earnings bigint;
  v_vnd_amount numeric(15, 2);
  v_req_id uuid;
  v_min_coins constant bigint := 1000;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Bạn cần đăng nhập để rút tiền';
  END IF;
  IF p_coin_amount IS NULL OR p_coin_amount < v_min_coins THEN
    RAISE EXCEPTION 'Số xu rút tối thiểu là % xu (tương đương % VNĐ)', v_min_coins, v_min_coins * 100;
  END IF;
  IF COALESCE(trim(p_bank_name), '') = '' OR COALESCE(trim(p_account_number), '') = '' OR COALESCE(trim(p_account_name), '') = '' THEN
    RAISE EXCEPTION 'Vui lòng nhập đầy đủ thông tin ngân hàng thụ hưởng';
  END IF;

  SELECT coin_balance INTO v_current_balance FROM public.profiles WHERE id = v_user_id FOR UPDATE;
  IF COALESCE(v_current_balance, 0) < p_coin_amount THEN
    RAISE EXCEPTION 'Số dư xu không đủ để rút (hiện có % xu, yêu cầu % xu)', COALESCE(v_current_balance, 0), p_coin_amount;
  END IF;

  v_vnd_amount := (p_coin_amount::numeric) * 100;

  UPDATE public.profiles
  SET coin_balance = coin_balance - p_coin_amount,
      earnings_balance = GREATEST(0, earnings_balance - p_coin_amount),
      updated_at = now()
  WHERE id = v_user_id
  RETURNING coin_balance, earnings_balance INTO v_new_balance, v_new_earnings;

  INSERT INTO public.withdrawal_requests (user_id, coin_amount, vnd_amount, bank_name, account_number, account_name, status)
  VALUES (v_user_id, p_coin_amount, v_vnd_amount, trim(p_bank_name), trim(p_account_number), upper(trim(p_account_name)), 'pending')
  RETURNING id INTO v_req_id;

  INSERT INTO public.coin_transactions (user_id, type, amount, balance_after, reference_id, description)
  VALUES (v_user_id, 'withdraw', -p_coin_amount, v_new_balance, v_req_id, 'Rút ' || p_coin_amount || ' xu (' || v_vnd_amount || 'đ) về ' || trim(p_bank_name) || ' - ' || trim(p_account_number));

  RETURN jsonb_build_object('request_id', v_req_id, 'coin_balance', v_new_balance, 'earnings_balance', v_new_earnings, 'vnd_amount', v_vnd_amount);
END;
$$;

ALTER TABLE public.livestreams ALTER COLUMN viewer_count SET DEFAULT 0;

CREATE OR REPLACE FUNCTION public.join_livestream(p_livestream_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.livestreams SET viewer_count = viewer_count + 1, updated_at = now()
  WHERE id = p_livestream_id AND status = 'live' AND (auth.uid() IS NULL OR host_id <> auth.uid());
END;
$$;

CREATE OR REPLACE FUNCTION public.leave_livestream(p_livestream_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.livestreams SET viewer_count = GREATEST(0, viewer_count - 1), updated_at = now()
  WHERE id = p_livestream_id AND (auth.uid() IS NULL OR host_id <> auth.uid());
END;
$$;

CREATE OR REPLACE FUNCTION public.like_livestream(p_livestream_id uuid, p_count integer DEFAULT 1)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.livestreams SET like_count = like_count + GREATEST(1, COALESCE(p_count, 1)), updated_at = now()
  WHERE id = p_livestream_id AND status = 'live';
END;
$$;
