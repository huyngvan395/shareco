-- ============================================================================
-- SHARECO: SQL CẬP NHẬT DATABASE CHO CHỨC NĂNG LIVESTREAM, GIỎ HÀNG LIVE,
-- NẠP XU, TẶNG QUÀ LIVESTREAM & RÚT TIỀN (VÍ XU)
-- Cách dùng: Copy toàn bộ nội dung file này vào Supabase Dashboard -> SQL Editor -> Run
-- ============================================================================

-- 1. THÊM CỘT SỐ DƯ XU VÀ DOANH THU QUÀ TẶNG VÀO BẢNG PROFILES
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS coin_balance bigint NOT NULL DEFAULT 0 CHECK (coin_balance >= 0),
  ADD COLUMN IF NOT EXISTS earnings_balance bigint NOT NULL DEFAULT 0 CHECK (earnings_balance >= 0);

-- 2. BẢNG DANH MỤC QUÀ TẶNG (GIFT CATALOG)
CREATE TABLE IF NOT EXISTS public.gift_catalog (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  icon text NOT NULL,
  coin_price integer NOT NULL CHECK (coin_price > 0),
  sort_order integer NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Seed dữ liệu quà tặng mặc định (nếu bảng đang trống)
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

-- 3. BẢNG PHIÊN LIVESTREAM (LIVESTREAMS)
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

-- 4. BẢNG GIỎ HÀNG GẮN TRONG LIVESTREAM (LIVESTREAM PRODUCTS)
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

-- 5. BẢNG BÌNH LUẬN & THÔNG BÁO TRONG LIVESTREAM (LIVESTREAM COMMENTS)
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

-- 6. BẢNG LỊCH SỬ TẶNG QUÀ LIVESTREAM (LIVESTREAM GIFTS)
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

-- 7. BẢNG LỊCH SỬ GIAO DỊCH XU (COIN TRANSACTIONS)
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

-- 8. BẢNG YÊU CẦU RÚT TIỀN (WITHDRAWAL REQUESTS)
-- Ngưỡng rút tối thiểu: 1.000 xu (quy đổi 1 xu = 100 VNĐ -> 1.000 xu = 100.000 VNĐ)
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

-- ============================================================================
-- 9. THIẾT LẬP ROW LEVEL SECURITY (RLS) CHO CÁC BẢNG MỚI
-- ============================================================================

-- 9.1. gift_catalog
ALTER TABLE public.gift_catalog ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS gift_catalog_public_read ON public.gift_catalog;
CREATE POLICY gift_catalog_public_read
  ON public.gift_catalog FOR SELECT TO public
  USING (true);

-- 9.2. livestreams
ALTER TABLE public.livestreams ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS livestreams_public_read ON public.livestreams;
DROP POLICY IF EXISTS livestreams_host_insert ON public.livestreams;
DROP POLICY IF EXISTS livestreams_host_update ON public.livestreams;
DROP POLICY IF EXISTS livestreams_host_delete ON public.livestreams;

CREATE POLICY livestreams_public_read
  ON public.livestreams FOR SELECT TO public
  USING (true);

CREATE POLICY livestreams_host_insert
  ON public.livestreams FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = host_id);

CREATE POLICY livestreams_host_update
  ON public.livestreams FOR UPDATE TO authenticated
  USING (auth.uid() = host_id)
  WITH CHECK (auth.uid() = host_id);

CREATE POLICY livestreams_host_delete
  ON public.livestreams FOR DELETE TO authenticated
  USING (auth.uid() = host_id);

-- 9.3. livestream_products
ALTER TABLE public.livestream_products ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS livestream_products_public_read ON public.livestream_products;
DROP POLICY IF EXISTS livestream_products_host_manage ON public.livestream_products;

CREATE POLICY livestream_products_public_read
  ON public.livestream_products FOR SELECT TO public
  USING (true);

CREATE POLICY livestream_products_host_manage
  ON public.livestream_products FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.livestreams l
      WHERE l.id = livestream_products.livestream_id
        AND l.host_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.livestreams l
      WHERE l.id = livestream_products.livestream_id
        AND l.host_id = auth.uid()
    )
  );

-- 9.4. livestream_comments
ALTER TABLE public.livestream_comments ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS livestream_comments_public_read ON public.livestream_comments;
DROP POLICY IF EXISTS livestream_comments_auth_insert ON public.livestream_comments;

CREATE POLICY livestream_comments_public_read
  ON public.livestream_comments FOR SELECT TO public
  USING (true);

CREATE POLICY livestream_comments_auth_insert
  ON public.livestream_comments FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- 9.5. livestream_gifts
ALTER TABLE public.livestream_gifts ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS livestream_gifts_public_read ON public.livestream_gifts;
DROP POLICY IF EXISTS livestream_gifts_sender_insert ON public.livestream_gifts;

CREATE POLICY livestream_gifts_public_read
  ON public.livestream_gifts FOR SELECT TO public
  USING (true);

CREATE POLICY livestream_gifts_sender_insert
  ON public.livestream_gifts FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = sender_id);

-- 9.6. coin_transactions
ALTER TABLE public.coin_transactions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS coin_transactions_read_own ON public.coin_transactions;
DROP POLICY IF EXISTS coin_transactions_insert_own ON public.coin_transactions;

CREATE POLICY coin_transactions_read_own
  ON public.coin_transactions FOR SELECT TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY coin_transactions_insert_own
  ON public.coin_transactions FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- 9.7. withdrawal_requests
ALTER TABLE public.withdrawal_requests ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS withdrawal_requests_read_own ON public.withdrawal_requests;
DROP POLICY IF EXISTS withdrawal_requests_insert_own ON public.withdrawal_requests;
DROP POLICY IF EXISTS withdrawal_requests_admin_all ON public.withdrawal_requests;

CREATE POLICY withdrawal_requests_read_own
  ON public.withdrawal_requests FOR SELECT TO public
  USING (true);

CREATE POLICY withdrawal_requests_insert_own
  ON public.withdrawal_requests FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY withdrawal_requests_admin_all
  ON public.withdrawal_requests FOR UPDATE TO public
  USING (true)
  WITH CHECK (true);

-- ============================================================================
-- 10. CÁC HÀM RPC XỬ LÝ GIAO DỊCH AN TOÀN (SECURITY DEFINER)
-- ============================================================================

-- 10.1. RPC: Nạp xu vào ví (topup_coins)
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

  INSERT INTO public.coin_transactions (
    user_id, type, amount, balance_after, description
  ) VALUES (
    v_user_id,
    'topup',
    p_coins,
    v_new_balance,
    'Nạp ' || p_coins || ' xu qua ' || COALESCE(p_method, 'Ví điện tử')
  );

  RETURN jsonb_build_object(
    'coin_balance', v_new_balance,
    'earnings_balance', v_earnings
  );
END;
$$;

-- 10.2. RPC: Tặng quà trong Livestream (send_livestream_gift)
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

  SELECT id, name, icon, coin_price
  INTO v_gift
  FROM public.gift_catalog
  WHERE id = p_gift_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Quà tặng không tồn tại';
  END IF;

  SELECT host_id
  INTO v_host_id
  FROM public.livestreams
  WHERE id = p_livestream_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Phiên livestream không tồn tại hoặc đã kết thúc';
  END IF;

  v_total_coins := (v_gift.coin_price::bigint) * (p_quantity::bigint);

  -- Kiểm tra và khóa dòng profile của người gửi
  SELECT coin_balance
  INTO v_sender_balance
  FROM public.profiles
  WHERE id = v_sender_id
  FOR UPDATE;

  IF COALESCE(v_sender_balance, 0) < v_total_coins THEN
    RAISE EXCEPTION 'Số dư xu không đủ (cần % xu, hiện có % xu). Vui lòng nạp thêm xu!', v_total_coins, COALESCE(v_sender_balance, 0);
  END IF;

  -- Trừ xu người gửi
  UPDATE public.profiles
  SET coin_balance = coin_balance - v_total_coins,
      updated_at = now()
  WHERE id = v_sender_id
  RETURNING coin_balance INTO v_sender_balance;

  -- Cộng xu và doanh thu quà tặng cho Host
  UPDATE public.profiles
  SET coin_balance = coin_balance + v_total_coins,
      earnings_balance = earnings_balance + v_total_coins,
      updated_at = now()
  WHERE id = v_host_id
  RETURNING coin_balance INTO v_host_balance;

  -- Cập nhật tổng xu quà tặng của phiên livestream
  UPDATE public.livestreams
  SET total_gift_coins = total_gift_coins + v_total_coins,
      updated_at = now()
  WHERE id = p_livestream_id
  RETURNING total_gift_coins INTO v_stream_coins;

  -- Lưu lịch sử quà tặng livestream
  INSERT INTO public.livestream_gifts (
    livestream_id, sender_id, receiver_id, gift_id, gift_name, gift_icon, quantity, total_coins
  ) VALUES (
    p_livestream_id, v_sender_id, v_host_id, v_gift.id, v_gift.name, v_gift.icon, p_quantity, v_total_coins
  ) RETURNING id INTO v_gift_tx_id;

  -- Phát thông báo quà tặng vào luồng chat livestream
  INSERT INTO public.livestream_comments (
    livestream_id, user_id, content, type, gift_name, gift_icon, gift_quantity, gift_coins
  ) VALUES (
    p_livestream_id,
    v_sender_id,
    'đã tặng ' || p_quantity || 'x ' || v_gift.icon || ' ' || v_gift.name || ' (' || v_total_coins || ' xu)',
    'gift',
    v_gift.name,
    v_gift.icon,
    p_quantity,
    v_total_coins::integer
  );

  -- Lưu lịch sử giao dịch xu cho người gửi
  INSERT INTO public.coin_transactions (
    user_id, type, amount, balance_after, reference_id, description
  ) VALUES (
    v_sender_id,
    'gift_sent',
    -v_total_coins,
    v_sender_balance,
    v_gift_tx_id,
    'Tặng ' || p_quantity || 'x ' || v_gift.icon || ' ' || v_gift.name || ' trong Livestream'
  );

  -- Lưu lịch sử giao dịch xu cho Host (nếu người gửi khác Host)
  IF v_host_id <> v_sender_id THEN
    INSERT INTO public.coin_transactions (
      user_id, type, amount, balance_after, reference_id, description
    ) VALUES (
      v_host_id,
      'gift_received',
      v_total_coins,
      v_host_balance,
      v_gift_tx_id,
      'Nhận ' || p_quantity || 'x ' || v_gift.icon || ' ' || v_gift.name || ' từ Livestream'
    );
  END IF;

  RETURN jsonb_build_object(
    'coin_balance', v_sender_balance,
    'total_gift_coins', v_stream_coins,
    'gift_id', v_gift_tx_id
  );
END;
$$;

-- 10.3. RPC: Yêu cầu rút tiền khi đủ số xu tối thiểu (request_coin_withdrawal)
-- Quy định: Tối thiểu 1.000 xu mới được rút. Tỷ lệ quy đổi: 1 xu = 100 VNĐ (1.000 xu = 100.000 VNĐ)
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

  SELECT coin_balance
  INTO v_current_balance
  FROM public.profiles
  WHERE id = v_user_id
  FOR UPDATE;

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

  INSERT INTO public.withdrawal_requests (
    user_id, coin_amount, vnd_amount, bank_name, account_number, account_name, status
  ) VALUES (
    v_user_id, p_coin_amount, v_vnd_amount, trim(p_bank_name), trim(p_account_number), upper(trim(p_account_name)), 'pending'
  ) RETURNING id INTO v_req_id;

  INSERT INTO public.coin_transactions (
    user_id, type, amount, balance_after, reference_id, description
  ) VALUES (
    v_user_id,
    'withdraw',
    -p_coin_amount,
    v_new_balance,
    v_req_id,
    'Rút ' || p_coin_amount || ' xu (' || v_vnd_amount || 'đ) về ' || trim(p_bank_name) || ' - ' || trim(p_account_number)
  );

  RETURN jsonb_build_object(
    'request_id', v_req_id,
    'coin_balance', v_new_balance,
    'earnings_balance', v_new_earnings,
    'vnd_amount', v_vnd_amount
  );
END;
$$;

-- 10.4. RPC: Tham gia / Rời phòng / Thả tim Livestream (Không tính chủ phòng vào viewer_count)
ALTER TABLE public.livestreams ALTER COLUMN viewer_count SET DEFAULT 0;

CREATE OR REPLACE FUNCTION public.join_livestream(p_livestream_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.livestreams
  SET viewer_count = viewer_count + 1,
      updated_at = now()
  WHERE id = p_livestream_id
    AND status = 'live'
    AND (auth.uid() IS NULL OR host_id <> auth.uid());
END;
$$;

CREATE OR REPLACE FUNCTION public.leave_livestream(p_livestream_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.livestreams
  SET viewer_count = GREATEST(0, viewer_count - 1),
      updated_at = now()
  WHERE id = p_livestream_id
    AND (auth.uid() IS NULL OR host_id <> auth.uid());
END;
$$;

CREATE OR REPLACE FUNCTION public.like_livestream(p_livestream_id uuid, p_count integer DEFAULT 1)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.livestreams
  SET like_count = like_count + GREATEST(1, COALESCE(p_count, 1)),
      updated_at = now()
  WHERE id = p_livestream_id AND status = 'live';
END;
$$;

-- ============================================================================
-- 11. BẬT SUPABASE REALTIME CHO CÁC BẢNG LIVESTREAM
-- ============================================================================
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    BEGIN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.livestreams;
    EXCEPTION WHEN duplicate_object THEN NULL;
    END;
    BEGIN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.livestream_products;
    EXCEPTION WHEN duplicate_object THEN NULL;
    END;
    BEGIN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.livestream_comments;
    EXCEPTION WHEN duplicate_object THEN NULL;
    END;
    BEGIN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.livestream_gifts;
    EXCEPTION WHEN duplicate_object THEN NULL;
    END;
  END IF;
END $$;

