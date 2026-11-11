-- ============================================================================
-- SHARECO: HỆ THỐNG ĐẶT HÀNG, THEO DÕI VỊ TRÍ ĐƠN HÀNG REALTIME (SHOPEE/TIKTOK)
--          & HỆ SINH THÁI KÊNH NGƯỜI BÁN (SELLER CENTER)
-- Cách dùng: Copy toàn bộ nội dung file này vào Supabase Dashboard -> SQL Editor -> Run
-- ============================================================================

-- 1. CẬP NHẬT BẢNG SHOPS (THÔNG TIN NGƯỜI BÁN, ĐỊA CHỈ KHO LẤY HÀNG, DOANH THU)
ALTER TABLE public.shops DROP CONSTRAINT IF EXISTS shops_owner_id_key;

ALTER TABLE public.shops
  ADD COLUMN IF NOT EXISTS contact_phone text,
  ADD COLUMN IF NOT EXISTS contact_email text,
  ADD COLUMN IF NOT EXISTS business_type text NOT NULL DEFAULT 'individual',
  ADD COLUMN IF NOT EXISTS pickup_province text,
  ADD COLUMN IF NOT EXISTS pickup_district text,
  ADD COLUMN IF NOT EXISTS pickup_ward text,
  ADD COLUMN IF NOT EXISTS pickup_address text,
  ADD COLUMN IF NOT EXISTS default_carrier text NOT NULL DEFAULT 'SPX Express',
  ADD COLUMN IF NOT EXISTS is_verified boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS has_blue_badge boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS settled_revenue numeric(15,2) NOT NULL DEFAULT 0;

-- Đồng bộ cờ xác minh nếu trước đó dùng has_blue_badge
UPDATE public.shops
SET is_verified = true
WHERE has_blue_badge = true AND is_verified = false;

-- Gán kho mẫu cho các shop demo nếu chưa có địa chỉ lấy hàng
UPDATE public.shops
SET
  pickup_province = COALESCE(pickup_province, 'Thành phố Hồ Chí Minh'),
  pickup_district = COALESCE(pickup_district, 'Quận 1'),
  pickup_ward = COALESCE(pickup_ward, 'Phường Bến Nghé'),
  pickup_address = COALESCE(pickup_address, 'Kho trung tâm ShareCo Mall - 72 Lê Thánh Tôn'),
  contact_phone = COALESCE(contact_phone, '1900 6868')
WHERE pickup_province IS NULL;

-- Đảm bảo RLS cho shops (chủ shop đọc/tạo/sửa được tất cả shop của mình)
ALTER TABLE public.shops ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS shops_public_read ON public.shops;
CREATE POLICY shops_public_read
  ON public.shops FOR SELECT TO public
  USING (status = 'active' OR auth.uid() = owner_id);

DROP POLICY IF EXISTS "Shops are insertable by authenticated users" ON public.shops;
DROP POLICY IF EXISTS shops_insert_own ON public.shops;
CREATE POLICY shops_insert_own
  ON public.shops FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = owner_id);

DROP POLICY IF EXISTS "Shops are updatable by owners or admins" ON public.shops;
DROP POLICY IF EXISTS shops_update_own ON public.shops;
CREATE POLICY shops_update_own
  ON public.shops FOR UPDATE TO authenticated
  USING (
    auth.uid() = owner_id
    OR EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.is_verified = true)
  )
  WITH CHECK (
    auth.uid() = owner_id
    OR EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.is_verified = true)
  );

-- 2. CẬP NHẬT BẢNG ORDERS (THÔNG TIN VẬN CHUYỂN & VỊ TRÍ HIỆN TẠI)
ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS shipping_carrier text,
  ADD COLUMN IF NOT EXISTS shipping_service text DEFAULT 'fast',
  ADD COLUMN IF NOT EXISTS tracking_code text,
  ADD COLUMN IF NOT EXISTS current_location text,
  ADD COLUMN IF NOT EXISTS pickup_location text,
  ADD COLUMN IF NOT EXISTS estimated_delivery_at timestamptz,
  ADD COLUMN IF NOT EXISTS confirmed_at timestamptz,
  ADD COLUMN IF NOT EXISTS shipped_at timestamptz,
  ADD COLUMN IF NOT EXISTS delivered_at timestamptz,
  ADD COLUMN IF NOT EXISTS cancel_reason text;

CREATE INDEX IF NOT EXISTS idx_orders_tracking_code
  ON public.orders (tracking_code)
  WHERE tracking_code IS NOT NULL;

-- Cho phép chủ shop & người mua cập nhật đơn hàng hợp lệ qua RLS
DROP POLICY IF EXISTS orders_update_shop_owner ON public.orders;
CREATE POLICY orders_update_shop_owner
  ON public.orders FOR UPDATE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.shops s
      WHERE s.id = orders.shop_id AND s.owner_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.shops s
      WHERE s.id = orders.shop_id AND s.owner_id = auth.uid()
    )
  );

-- Cho phép người mua tạo & xem bản ghi payments của chính đơn hàng mình
DROP POLICY IF EXISTS payments_insert_own_order ON public.payments;
CREATE POLICY payments_insert_own_order
  ON public.payments FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.orders o
      WHERE o.id = order_id AND o.buyer_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS payments_update_related ON public.payments;
CREATE POLICY payments_update_related
  ON public.payments FOR UPDATE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.orders o
      JOIN public.shops s ON s.id = o.shop_id
      WHERE o.id = order_id AND (o.buyer_id = auth.uid() OR s.owner_id = auth.uid())
    )
  );

-- 3. BẢNG LỊCH SỬ HÀNH TRÌNH & VỊ TRÍ ĐƠN HÀNG (ORDER_TRACKING_EVENTS)
CREATE TABLE IF NOT EXISTS public.order_tracking_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
  status text NOT NULL,
  title text NOT NULL,
  description text,
  location text,
  carrier_name text,
  lat double precision,
  lng double precision,
  actor_role text NOT NULL DEFAULT 'system',
  created_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_order_tracking_events_order_created
  ON public.order_tracking_events (order_id, created_at DESC);

ALTER TABLE public.order_tracking_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS order_tracking_read_related ON public.order_tracking_events;
CREATE POLICY order_tracking_read_related
  ON public.order_tracking_events FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.orders o
      JOIN public.shops s ON s.id = o.shop_id
      WHERE o.id = order_id
        AND (
          o.buyer_id = auth.uid()
          OR s.owner_id = auth.uid()
          OR EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.is_verified = true)
        )
    )
  );

DROP POLICY IF EXISTS order_tracking_insert_related ON public.order_tracking_events;
CREATE POLICY order_tracking_insert_related
  ON public.order_tracking_events FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.orders o
      JOIN public.shops s ON s.id = o.shop_id
      WHERE o.id = order_id
        AND (
          o.buyer_id = auth.uid()
          OR s.owner_id = auth.uid()
          OR EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.is_verified = true)
        )
    )
  );

-- Bật Supabase Realtime cho orders & order_tracking_events
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    BEGIN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.orders;
    EXCEPTION WHEN duplicate_object THEN NULL;
    END;
    BEGIN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.order_tracking_events;
    EXCEPTION WHEN duplicate_object THEN NULL;
    END;
  END IF;
END $$;

-- 4. ĐẢM BẢO HÀM EMIT_APP_NOTIFICATION TỒN TẠI (NẾU CHƯA CHẠY SUPABASE_NOTIFICATIONS.SQL)
CREATE OR REPLACE FUNCTION public.emit_app_notification(
  p_user_id uuid,
  p_actor_id uuid,
  p_type text,
  p_title text,
  p_body text,
  p_data jsonb DEFAULT '{}'::jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_dedupe text;
BEGIN
  IF p_user_id IS NULL THEN
    RETURN;
  END IF;

  IF p_actor_id IS NOT NULL AND p_user_id = p_actor_id THEN
    RETURN;
  END IF;

  v_dedupe := COALESCE(p_data->>'dedupe_key', '');
  IF v_dedupe <> '' THEN
    IF EXISTS (
      SELECT 1
      FROM public.notifications n
      WHERE n.user_id = p_user_id
        AND n.type = p_type
        AND COALESCE(n.data->>'dedupe_key', '') = v_dedupe
        AND n.created_at > now() - interval '30 seconds'
    ) THEN
      RETURN;
    END IF;
  END IF;

  INSERT INTO public.notifications (user_id, type, title, body, data)
  VALUES (p_user_id, p_type, p_title, p_body, COALESCE(p_data, '{}'::jsonb));
END;
$$;

-- 5. HÀM FORMAT ĐỊA CHỈ KHO CỦA SHOP
CREATE OR REPLACE FUNCTION public._format_shop_pickup_location(p_shop_id uuid)
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(
    NULLIF(
      CONCAT_WS(', ',
        NULLIF(TRIM(pickup_ward), ''),
        NULLIF(TRIM(pickup_district), ''),
        NULLIF(TRIM(pickup_province), '')
      ),
      ''
    ),
    NULLIF(TRIM(pickup_address), ''),
    'Kho người bán ShareCo'
  )
  FROM public.shops
  WHERE id = p_shop_id;
$$;

-- 6. RPC 1: TRỪ TỒN KHO AN TOÀN (VƯỢT RLS), TẠO PAYMENT & KHỞI TẠO HÀNH TRÌNH ĐƠN HÀNG
CREATE OR REPLACE FUNCTION public.deduct_order_stock_and_init_tracking(
  p_order_id uuid,
  p_payment_method text DEFAULT 'cod',
  p_payment_status text DEFAULT 'pending',
  p_shipping_service text DEFAULT 'fast'
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_order public.orders%rowtype;
  v_shop public.shops%rowtype;
  v_item record;
  v_pickup text;
  v_eta timestamptz;
  v_pay_status text;
  v_init_title text;
  v_init_desc text;
  v_buyer_loc text;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Vui lòng đăng nhập để tiếp tục';
  END IF;

  SELECT * INTO v_order
  FROM public.orders
  WHERE id = p_order_id
  FOR UPDATE;

  IF NOT FOUND OR v_order.buyer_id <> v_uid THEN
    RAISE EXCEPTION 'Không tìm thấy đơn hàng hợp lệ';
  END IF;

  SELECT * INTO v_shop
  FROM public.shops
  WHERE id = v_order.shop_id;

  IF NOT FOUND OR v_shop.status <> 'active' THEN
    RAISE EXCEPTION 'Cửa hàng hiện đang tạm ngưng hoạt động';
  END IF;

  -- Trừ tồn kho từng sản phẩm & biến thể trong đơn hàng (chỉ trừ 1 lần dựa vào chưa có tracking event)
  IF NOT EXISTS (SELECT 1 FROM public.order_tracking_events WHERE order_id = p_order_id) THEN
    FOR v_item IN
      SELECT product_id, variant_id, qty
      FROM public.order_items
      WHERE order_id = p_order_id
    LOOP
      IF v_item.variant_id IS NOT NULL THEN
        UPDATE public.product_variants
        SET stock_qty = GREATEST(0, stock_qty - v_item.qty)
        WHERE id = v_item.variant_id;
      END IF;

      UPDATE public.products
      SET
        stock_total = GREATEST(0, stock_total - v_item.qty),
        sold_count = sold_count + v_item.qty
      WHERE id = v_item.product_id;
    END LOOP;
  END IF;

  v_pickup := public._format_shop_pickup_location(v_order.shop_id);
  v_eta := CASE COALESCE(NULLIF(p_shipping_service, ''), v_order.shipping_service, 'fast')
    WHEN 'express' THEN now() + interval '1 day'
    WHEN 'standard' THEN now() + interval '5 days'
    ELSE now() + interval '3 days'
  END;

  v_pay_status := CASE
    WHEN p_payment_status IN ('initiated', 'pending', 'paid', 'failed', 'refunded') THEN p_payment_status
    WHEN p_payment_method IN ('card', 'qr') THEN 'paid'
    ELSE 'pending'
  END;

  -- Cập nhật metadata vận chuyển ban đầu cho order
  UPDATE public.orders
  SET
    shipping_carrier = COALESCE(NULLIF(shipping_carrier, ''), v_shop.default_carrier, 'SPX Express'),
    shipping_service = COALESCE(NULLIF(p_shipping_service, ''), shipping_service, 'fast'),
    pickup_location = COALESCE(NULLIF(pickup_location, ''), v_pickup),
    current_location = COALESCE(NULLIF(current_location, ''), 'Chờ người bán xác nhận • ' || v_pickup),
    estimated_delivery_at = COALESCE(estimated_delivery_at, v_eta),
    status = CASE WHEN v_pay_status = 'paid' AND status = 'pending' THEN 'paid' ELSE status END
  WHERE id = p_order_id;

  -- Ghi bản ghi thanh toán
  INSERT INTO public.payments (order_id, provider, provider_ref, amount, currency, status, payload)
  VALUES (
    p_order_id,
    COALESCE(NULLIF(p_payment_method, ''), 'cod'),
    v_order.order_code,
    v_order.total_amount,
    v_order.currency,
    v_pay_status,
    jsonb_build_object(
      'method', COALESCE(NULLIF(p_payment_method, ''), 'cod'),
      'shipping_service', COALESCE(NULLIF(p_shipping_service, ''), 'fast'),
      'initialized_at', now()
    )
  )
  ON CONFLICT (order_id) DO UPDATE
  SET
    provider = EXCLUDED.provider,
    amount = EXCLUDED.amount,
    status = EXCLUDED.status,
    payload = EXCLUDED.payload,
    updated_at = now();

  v_buyer_loc := NULLIF(
    CONCAT_WS(', ',
      NULLIF(TRIM(v_order.address_snapshot->>'district'), ''),
      NULLIF(TRIM(v_order.address_snapshot->>'province'), '')
    ),
    ''
  );

  IF v_pay_status = 'paid' THEN
    v_init_title := 'Đặt hàng & Thanh toán thành công';
    v_init_desc := 'Thanh toán qua ' ||
      CASE p_payment_method WHEN 'card' THEN 'Thẻ tín dụng' WHEN 'qr' THEN 'VietQR' ELSE 'Ví/Trả trước' END ||
      ' đã được xác nhận. Đang chờ ' || COALESCE(v_shop.shop_name, 'người bán') || ' đóng gói.';
  ELSE
    v_init_title := 'Đơn hàng đã được đặt thành công';
    v_init_desc := 'Đơn hàng COD đang chờ ' || COALESCE(v_shop.shop_name, 'người bán') || ' xác nhận chuẩn bị hàng.';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.order_tracking_events WHERE order_id = p_order_id) THEN
    INSERT INTO public.order_tracking_events (
      order_id, status, title, description, location, carrier_name, actor_role, created_by
    ) VALUES (
      p_order_id,
      CASE WHEN v_pay_status = 'paid' THEN 'paid' ELSE 'pending' END,
      v_init_title,
      v_init_desc,
      COALESCE(v_buyer_loc, v_pickup),
      COALESCE(v_order.shipping_carrier, v_shop.default_carrier, 'SPX Express'),
      'buyer',
      v_uid
    );
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.deduct_order_stock_and_init_tracking(uuid, text, text, text) TO authenticated;

-- 7. RPC 2: HỦY ĐƠN HÀNG (CHO NGƯỜI MUA HOẶC CHỦ SHOP) + HOÀN TỒN KHO + HOÀN TIỀN PAYMENT
DROP FUNCTION IF EXISTS public.cancel_order(uuid);

CREATE OR REPLACE FUNCTION public.cancel_order(
  p_order_id uuid,
  p_reason text DEFAULT 'Người mua yêu cầu hủy đơn'
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_order public.orders%rowtype;
  v_shop_owner uuid;
  v_is_buyer boolean := false;
  v_is_seller boolean := false;
  v_item record;
  v_clean_reason text;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Vui lòng đăng nhập để hủy đơn hàng';
  END IF;

  SELECT * INTO v_order
  FROM public.orders
  WHERE id = p_order_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Không tìm thấy đơn hàng';
  END IF;

  SELECT owner_id INTO v_shop_owner
  FROM public.shops
  WHERE id = v_order.shop_id;

  v_is_buyer := (v_order.buyer_id = v_uid);
  v_is_seller := (v_shop_owner = v_uid);

  IF NOT v_is_buyer AND NOT v_is_seller THEN
    RAISE EXCEPTION 'Bạn không có quyền hủy đơn hàng này';
  END IF;

  IF v_is_buyer AND NOT v_is_seller AND v_order.status NOT IN ('pending', 'paid') THEN
    RAISE EXCEPTION 'Chỉ có thể hủy đơn khi người bán chưa đóng gói hoặc giao hàng';
  END IF;

  IF v_is_seller AND v_order.status NOT IN ('pending', 'paid', 'packed') THEN
    RAISE EXCEPTION 'Không thể hủy đơn hàng đã bàn giao cho đơn vị vận chuyển hoặc đã hoàn tất';
  END IF;

  IF v_order.status IN ('cancelled', 'refunded') THEN
    RETURN;
  END IF;

  v_clean_reason := COALESCE(
    NULLIF(TRIM(p_reason), ''),
    CASE WHEN v_is_seller THEN 'Người bán hủy đơn hàng' ELSE 'Người mua yêu cầu hủy đơn' END
  );

  -- Hoàn lại tồn kho sản phẩm & biến thể
  FOR v_item IN
    SELECT product_id, variant_id, qty
    FROM public.order_items
    WHERE order_id = p_order_id
  LOOP
    IF v_item.variant_id IS NOT NULL THEN
      UPDATE public.product_variants
      SET stock_qty = stock_qty + v_item.qty
      WHERE id = v_item.variant_id;
    END IF;

    UPDATE public.products
    SET
      stock_total = stock_total + v_item.qty,
      sold_count = GREATEST(0, sold_count - v_item.qty)
    WHERE id = v_item.product_id;
  END LOOP;

  -- Nếu đã thanh toán trước, cập nhật payments -> refunded
  UPDATE public.payments
  SET
    status = CASE WHEN status = 'paid' THEN 'refunded' ELSE 'failed' END,
    updated_at = now()
  WHERE order_id = p_order_id;

  UPDATE public.orders
  SET
    status = 'cancelled',
    cancel_reason = v_clean_reason,
    current_location = 'Đơn hàng đã bị hủy',
    updated_at = now()
  WHERE id = p_order_id;

  INSERT INTO public.order_tracking_events (
    order_id, status, title, description, location, carrier_name, actor_role, created_by
  ) VALUES (
    p_order_id,
    'cancelled',
    CASE WHEN v_is_seller THEN 'Người bán đã hủy đơn hàng' ELSE 'Người mua đã hủy đơn hàng' END,
    'Lý do: ' || v_clean_reason || '. Tồn kho đã được hoàn lại tự động.',
    COALESCE(v_order.pickup_location, 'Hệ thống ShareCo'),
    v_order.shipping_carrier,
    CASE WHEN v_is_seller THEN 'seller' ELSE 'buyer' END,
    v_uid
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.cancel_order(uuid, text) TO authenticated;

-- 8. RPC 3: NGƯỜI BÁN XÁC NHẬN & ĐÓNG GÓI ĐƠN HÀNG (PACKED)
CREATE OR REPLACE FUNCTION public.seller_confirm_pack_order(
  p_order_id uuid,
  p_note text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_order public.orders%rowtype;
  v_shop public.shops%rowtype;
  v_pickup text;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Vui lòng đăng nhập';
  END IF;

  SELECT * INTO v_order
  FROM public.orders
  WHERE id = p_order_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Không tìm thấy đơn hàng';
  END IF;

  SELECT * INTO v_shop
  FROM public.shops
  WHERE id = v_order.shop_id;

  IF NOT FOUND OR v_shop.owner_id <> v_uid THEN
    RAISE EXCEPTION 'Bạn không phải chủ cửa hàng của đơn hàng này';
  END IF;

  IF v_order.status NOT IN ('pending', 'paid') THEN
    RAISE EXCEPTION 'Đơn hàng đang ở trạng thái "%" nên không thể xác nhận đóng gói', v_order.status;
  END IF;

  v_pickup := COALESCE(NULLIF(v_order.pickup_location, ''), public._format_shop_pickup_location(v_shop.id));

  UPDATE public.orders
  SET
    status = 'packed',
    confirmed_at = COALESCE(confirmed_at, now()),
    pickup_location = v_pickup,
    current_location = 'Đang đóng gói tại kho ' || v_shop.shop_name || ' (' || v_pickup || ')',
    updated_at = now()
  WHERE id = p_order_id;

  INSERT INTO public.order_tracking_events (
    order_id, status, title, description, location, carrier_name, actor_role, created_by
  ) VALUES (
    p_order_id,
    'packed',
    'Người bán đang chuẩn bị & đóng gói hàng',
    COALESCE(
      NULLIF(TRIM(p_note), ''),
      v_shop.shop_name || ' đã xác nhận đơn và hoàn tất đóng gói, sẵn sàng bàn giao cho đơn vị vận chuyển.'
    ),
    v_pickup,
    COALESCE(v_order.shipping_carrier, v_shop.default_carrier, 'SPX Express'),
    'seller',
    v_uid
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.seller_confirm_pack_order(uuid, text) TO authenticated;

-- 9. RPC 4: NGƯỜI BÁN BÀN GIAO CHO ĐƠN VỊ VẬN CHUYỂN (SHIPPING + TẠO MÃ VẬN ĐƠN + VỊ TRÍ ĐẦU)
CREATE OR REPLACE FUNCTION public.seller_handover_to_carrier(
  p_order_id uuid,
  p_carrier text,
  p_tracking_code text DEFAULT NULL,
  p_pickup_hub text DEFAULT NULL
)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_order public.orders%rowtype;
  v_shop public.shops%rowtype;
  v_carrier text;
  v_prefix text;
  v_tracking text;
  v_hub text;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Vui lòng đăng nhập';
  END IF;

  SELECT * INTO v_order
  FROM public.orders
  WHERE id = p_order_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Không tìm thấy đơn hàng';
  END IF;

  SELECT * INTO v_shop
  FROM public.shops
  WHERE id = v_order.shop_id;

  IF NOT FOUND OR v_shop.owner_id <> v_uid THEN
    RAISE EXCEPTION 'Bạn không phải chủ cửa hàng của đơn hàng này';
  END IF;

  IF v_order.status NOT IN ('pending', 'paid', 'packed') THEN
    RAISE EXCEPTION 'Đơn hàng đang ở trạng thái "%" không thể giao vận', v_order.status;
  END IF;

  v_carrier := COALESCE(NULLIF(TRIM(p_carrier), ''), v_order.shipping_carrier, v_shop.default_carrier, 'SPX Express');

  v_prefix := CASE
    WHEN v_carrier ILIKE '%SPX%' THEN 'SPXVN'
    WHEN v_carrier ILIKE '%GHN%' OR v_carrier ILIKE '%Giao Hàng Nhanh%' THEN 'GHNVN'
    WHEN v_carrier ILIKE '%J&T%' THEN 'JT84'
    WHEN v_carrier ILIKE '%Viettel%' THEN 'VTP'
    WHEN v_carrier ILIKE '%Ninja%' THEN 'NJV'
    ELSE 'SHC'
  END;

  v_tracking := COALESCE(
    NULLIF(TRIM(p_tracking_code), ''),
    NULLIF(TRIM(v_order.tracking_code), ''),
    v_prefix || to_char(now(), 'YYMMDD') || upper(substr(replace(v_order.id::text, '-', ''), 1, 6))
  );

  v_hub := COALESCE(
    NULLIF(TRIM(p_pickup_hub), ''),
    'Bưu cục lấy hàng ' || COALESCE(NULLIF(TRIM(v_shop.pickup_district), ''), 'Trung tâm') ||
      CASE WHEN NULLIF(TRIM(v_shop.pickup_province), '') IS NOT NULL THEN ', ' || v_shop.pickup_province ELSE '' END
  );

  -- Nếu trước đó chưa đóng gói (chuyển thẳng từ pending/paid -> shipping), chèn 1 log packed trước
  IF v_order.status IN ('pending', 'paid') THEN
    INSERT INTO public.order_tracking_events (
      order_id, status, title, description, location, carrier_name, actor_role, created_by
    ) VALUES (
      p_order_id,
      'packed',
      'Người bán đã xác nhận & đóng gói hoàn tất',
      v_shop.shop_name || ' đã đóng gói kiện hàng sẵn sàng bàn giao.',
      COALESCE(NULLIF(v_order.pickup_location, ''), public._format_shop_pickup_location(v_shop.id)),
      v_carrier,
      'seller',
      v_uid
    );
  END IF;

  UPDATE public.orders
  SET
    status = 'shipping',
    shipping_carrier = v_carrier,
    tracking_code = v_tracking,
    confirmed_at = COALESCE(confirmed_at, now()),
    shipped_at = now(),
    pickup_location = COALESCE(NULLIF(pickup_location, ''), public._format_shop_pickup_location(v_shop.id)),
    current_location = v_hub,
    estimated_delivery_at = COALESCE(estimated_delivery_at, now() + interval '3 days'),
    updated_at = now()
  WHERE id = p_order_id;

  INSERT INTO public.order_tracking_events (
    order_id, status, title, description, location, carrier_name, actor_role, created_by
  ) VALUES (
    p_order_id,
    'picked_up',
    'Đơn vị vận chuyển đã lấy hàng thành công',
    'Bưu tá ' || v_carrier || ' đã nhận kiện hàng từ ' || v_shop.shop_name || '. Mã vận đơn: ' || v_tracking,
    v_hub,
    v_carrier,
    'carrier',
    v_uid
  );

  RETURN v_tracking;
END;
$$;

GRANT EXECUTE ON FUNCTION public.seller_handover_to_carrier(uuid, text, text, text) TO authenticated;

-- 10. RPC 5: CẬP NHẬT VỊ TRÍ ĐƠN HÀNG THEO CHẶNG VẬN CHUYỂN (NHƯ SHOPEE / TIKTOK SHOP)
CREATE OR REPLACE FUNCTION public.advance_order_location(
  p_order_id uuid,
  p_step_status text,
  p_title text,
  p_location text,
  p_description text DEFAULT NULL,
  p_lat double precision DEFAULT NULL,
  p_lng double precision DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_order public.orders%rowtype;
  v_shop public.shops%rowtype;
  v_is_admin boolean := false;
  v_next_order_status text;
  v_clean_location text;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Vui lòng đăng nhập';
  END IF;

  SELECT * INTO v_order
  FROM public.orders
  WHERE id = p_order_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Không tìm thấy đơn hàng';
  END IF;

  SELECT * INTO v_shop
  FROM public.shops
  WHERE id = v_order.shop_id;

  SELECT EXISTS (
    SELECT 1 FROM public.profiles WHERE id = v_uid AND is_verified = true
  ) INTO v_is_admin;

  IF (v_shop.owner_id IS DISTINCT FROM v_uid) AND NOT v_is_admin THEN
    RAISE EXCEPTION 'Bạn không có quyền cập nhật vị trí đơn hàng này';
  END IF;

  IF v_order.status IN ('cancelled', 'refunded', 'completed') THEN
    RAISE EXCEPTION 'Đơn hàng đã kết thúc, không thể cập nhật thêm vị trí';
  END IF;

  v_clean_location := COALESCE(NULLIF(TRIM(p_location), ''), v_order.current_location, 'Kho trung chuyển ShareCo');

  v_next_order_status := CASE
    WHEN p_step_status = 'completed' THEN 'completed'
    ELSE 'shipping'
  END;

  UPDATE public.orders
  SET
    status = v_next_order_status,
    current_location = v_clean_location,
    shipped_at = COALESCE(shipped_at, now()),
    delivered_at = CASE WHEN v_next_order_status = 'completed' THEN now() ELSE delivered_at END,
    updated_at = now()
  WHERE id = p_order_id;

  -- Nếu giao thành công: hoàn tất payment COD & cộng doanh thu quyết toán cho shop
  IF v_next_order_status = 'completed' THEN
    UPDATE public.payments
    SET status = 'paid', updated_at = now()
    WHERE order_id = p_order_id AND status <> 'paid';

    UPDATE public.shops
    SET settled_revenue = COALESCE(settled_revenue, 0) + v_order.total_amount
    WHERE id = v_order.shop_id;
  END IF;

  INSERT INTO public.order_tracking_events (
    order_id, status, title, description, location, carrier_name, lat, lng, actor_role, created_by
  ) VALUES (
    p_order_id,
    COALESCE(NULLIF(TRIM(p_step_status), ''), 'in_transit'),
    COALESCE(NULLIF(TRIM(p_title), ''), 'Cập nhật vị trí vận chuyển'),
    COALESCE(NULLIF(TRIM(p_description), ''), 'Đơn hàng đang được vận chuyển qua ' || v_clean_location),
    v_clean_location,
    COALESCE(v_order.shipping_carrier, v_shop.default_carrier, 'SPX Express'),
    p_lat,
    p_lng,
    'carrier',
    v_uid
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.advance_order_location(uuid, text, text, text, text, double precision, double precision) TO authenticated;

-- 11. RPC 6: NGƯỜI MUA XÁC NHẬN ĐÃ NHẬN ĐƯỢC HÀNG (SHIPPING -> COMPLETED)
CREATE OR REPLACE FUNCTION public.confirm_order_delivered(p_order_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_order public.orders%rowtype;
  v_buyer_loc text;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Vui lòng đăng nhập';
  END IF;

  SELECT * INTO v_order
  FROM public.orders
  WHERE id = p_order_id
  FOR UPDATE;

  IF NOT FOUND OR v_order.buyer_id <> v_uid THEN
    RAISE EXCEPTION 'Bạn không có quyền xác nhận đơn hàng này';
  END IF;

  IF v_order.status = 'completed' THEN
    RETURN;
  END IF;

  IF v_order.status <> 'shipping' THEN
    RAISE EXCEPTION 'Chỉ có thể xác nhận nhận hàng khi đơn đang được giao';
  END IF;

  v_buyer_loc := COALESCE(
    NULLIF(
      CONCAT_WS(', ',
        NULLIF(TRIM(v_order.address_snapshot->>'ward'), ''),
        NULLIF(TRIM(v_order.address_snapshot->>'district'), ''),
        NULLIF(TRIM(v_order.address_snapshot->>'province'), '')
      ),
      ''
    ),
    'Địa chỉ người nhận'
  );

  UPDATE public.orders
  SET
    status = 'completed',
    delivered_at = now(),
    current_location = 'Đã giao thành công • ' || v_buyer_loc,
    updated_at = now()
  WHERE id = p_order_id;

  UPDATE public.payments
  SET status = 'paid', updated_at = now()
  WHERE order_id = p_order_id AND status <> 'paid';

  UPDATE public.shops
  SET settled_revenue = COALESCE(settled_revenue, 0) + v_order.total_amount
  WHERE id = v_order.shop_id;

  INSERT INTO public.order_tracking_events (
    order_id, status, title, description, location, carrier_name, actor_role, created_by
  ) VALUES (
    p_order_id,
    'completed',
    'Giao hàng thành công',
    'Người mua đã xác nhận nhận được hàng nguyên vẹn. Bạn có thể đánh giá sản phẩm ngay!',
    v_buyer_loc,
    COALESCE(v_order.shipping_carrier, 'SPX Express'),
    'buyer',
    v_uid
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.confirm_order_delivered(uuid) TO authenticated;

-- 12. CẬP NHẬT TRIGGER THÔNG BÁO ĐƠN HÀNG & VỊ TRÍ VẬN ĐƠN REALTIME
CREATE OR REPLACE FUNCTION public.trg_fn_notify_order_events()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_shop record;
  v_short_id text := COALESCE(NULLIF(NEW.order_code, ''), upper(left(NEW.id::text, 8)));
  v_status_title text;
  v_status_body text;
BEGIN
  SELECT id, owner_id, shop_name
  INTO v_shop
  FROM public.shops
  WHERE id = NEW.shop_id;

  IF TG_OP = 'INSERT' THEN
    IF v_shop.owner_id IS NOT NULL AND v_shop.owner_id <> NEW.buyer_id THEN
      PERFORM public.emit_app_notification(
        v_shop.owner_id,
        NEW.buyer_id,
        'new_order',
        '🛒 Đơn hàng mới #' || v_short_id,
        'Shop ' || COALESCE(v_shop.shop_name, '') || ' vừa có đơn đặt mới. Hãy xác nhận và đóng gói ngay!',
        jsonb_build_object(
          'order_id', NEW.id,
          'shop_id', NEW.shop_id,
          'role', 'seller',
          'dedupe_key', 'new_order_' || NEW.id::text
        )
      );
    END IF;

    PERFORM public.emit_app_notification(
      NEW.buyer_id,
      NULL,
      'order',
      '📦 Đặt hàng thành công #' || v_short_id,
      'Đơn hàng của bạn đã được chuyển tới ' || COALESCE(v_shop.shop_name, 'cửa hàng') || '.',
      jsonb_build_object(
        'order_id', NEW.id,
        'status', NEW.status,
        'dedupe_key', 'order_created_' || NEW.id::text
      )
    );
  ELSIF TG_OP = 'UPDATE' AND OLD.status IS DISTINCT FROM NEW.status THEN
    IF NEW.status = 'completed' AND v_shop.owner_id IS NOT NULL AND v_shop.owner_id <> NEW.buyer_id THEN
      PERFORM public.emit_app_notification(
        v_shop.owner_id,
        NEW.buyer_id,
        'new_order',
        '✅ Khách đã nhận đơn #' || v_short_id,
        'Đơn #' || v_short_id || ' đã hoàn tất giao hàng và ghi nhận doanh thu cho ' || COALESCE(v_shop.shop_name, 'Shop') || '.',
        jsonb_build_object(
          'order_id', NEW.id,
          'shop_id', NEW.shop_id,
          'status', NEW.status,
          'role', 'seller',
          'dedupe_key', 'seller_order_done_' || NEW.id::text
        )
      );
    END IF;

    v_status_title := CASE NEW.status
      WHEN 'paid' THEN '💳 Thanh toán thành công #' || v_short_id
      WHEN 'packed' THEN '📦 Người bán đang chuẩn bị hàng #' || v_short_id
      WHEN 'shipping' THEN '🚚 Đã bàn giao cho ' || COALESCE(NEW.shipping_carrier, 'đơn vị vận chuyển')
      WHEN 'completed' THEN '🎉 Giao hàng thành công #' || v_short_id
      WHEN 'cancelled' THEN '❌ Đơn hàng #' || v_short_id || ' đã bị hủy'
      WHEN 'refunded' THEN '💸 Đã hoàn tiền đơn #' || v_short_id
      ELSE '🚚 Cập nhật đơn hàng #' || v_short_id
    END;

    v_status_body := CASE NEW.status
      WHEN 'shipping' THEN 'Mã vận đơn: ' || COALESCE(NEW.tracking_code, v_short_id) ||
        CASE WHEN NEW.current_location IS NOT NULL THEN ' • Vị trí: ' || NEW.current_location ELSE '' END
      WHEN 'completed' THEN 'Cảm ơn bạn đã mua sắm tại ShareCo! Hãy đánh giá sản phẩm để nhận xu nhé.'
      WHEN 'cancelled' THEN COALESCE('Lý do: ' || NEW.cancel_reason, 'Đơn hàng đã chuyển sang trạng thái đã hủy.')
      ELSE 'Đơn hàng #' || v_short_id || ' hiện ở trạng thái: ' || NEW.status
    END;

    PERFORM public.emit_app_notification(
      NEW.buyer_id,
      NULL,
      'order_status',
      v_status_title,
      v_status_body,
      jsonb_build_object(
        'order_id', NEW.id,
        'status', NEW.status,
        'tracking_code', NEW.tracking_code,
        'carrier', NEW.shipping_carrier,
        'location', NEW.current_location,
        'dedupe_key', 'order_status_' || NEW.id::text || '_' || NEW.status
      )
    );
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_order_events ON public.orders;
CREATE TRIGGER trg_notify_order_events
AFTER INSERT OR UPDATE OF status ON public.orders
FOR EACH ROW
EXECUTE FUNCTION public.trg_fn_notify_order_events();

-- Trigger thông báo mỗi khi ĐVVC cập nhật mốc vị trí vận đơn trung gian
CREATE OR REPLACE FUNCTION public.trg_fn_notify_order_location()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_order public.orders%rowtype;
  v_short_id text;
BEGIN
  IF NEW.status NOT IN ('in_transit', 'arrived_hub', 'out_for_delivery') THEN
    RETURN NEW;
  END IF;

  SELECT * INTO v_order
  FROM public.orders
  WHERE id = NEW.order_id;

  IF NOT FOUND THEN
    RETURN NEW;
  END IF;

  v_short_id := COALESCE(NULLIF(v_order.order_code, ''), upper(left(v_order.id::text, 8)));

  PERFORM public.emit_app_notification(
    v_order.buyer_id,
    NULL,
    'order_status',
    '📍 Vận đơn #' || v_short_id || ': ' || NEW.title,
    CASE
      WHEN COALESCE(NEW.location, '') <> '' THEN 'Vị trí: ' || NEW.location || COALESCE(' — ' || NULLIF(NEW.description, ''), '')
      ELSE COALESCE(NEW.description, 'Đơn hàng đang tiếp tục di chuyển tới bạn.')
    END,
    jsonb_build_object(
      'order_id', v_order.id,
      'tracking_event_id', NEW.id,
      'status', NEW.status,
      'location', NEW.location,
      'dedupe_key', 'loc_' || NEW.id::text
    )
  );

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_order_location ON public.order_tracking_events;
CREATE TRIGGER trg_notify_order_location
AFTER INSERT ON public.order_tracking_events
FOR EACH ROW
EXECUTE FUNCTION public.trg_fn_notify_order_location();

