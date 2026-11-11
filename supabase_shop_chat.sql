-- ==============================================================================
-- Migration: Tách biệt nhắn tin giữa Shop với Người mua (Shop CSKH Chat)
-- Mô hình tương tự TikTok Shop / Shopee CSKH
-- ==============================================================================

-- 1. Bổ sung cột shop_id vào bảng conversations (nếu chưa có)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'conversations' AND column_name = 'shop_id'
  ) THEN
    ALTER TABLE public.conversations
    ADD COLUMN shop_id UUID REFERENCES public.shops(id) ON DELETE CASCADE;
  END IF;
END $$;

-- 2. Đảm bảo cột type cho phép giá trị 'shop'
DO $$
BEGIN
  -- Xoá constraint cũ nếu có để cập nhật
  ALTER TABLE public.conversations DROP CONSTRAINT IF EXISTS conversations_type_check;
  ALTER TABLE public.conversations
    ADD CONSTRAINT conversations_type_check
    CHECK (type IN ('direct', 'group', 'shop'));
EXCEPTION
  WHEN OTHERS THEN NULL;
END $$;

-- 3. Tạo index tìm kiếm nhanh cho shop_id
CREATE INDEX IF NOT EXISTS idx_conversations_shop_id ON public.conversations(shop_id);
CREATE INDEX IF NOT EXISTS idx_conversations_type ON public.conversations(type);

-- 4. RPC: get_or_create_shop_conversation
-- Nhận vào p_shop_id, tự động liên kết Người mua (auth.uid()) và Chủ gian hàng (shops.owner_id)
CREATE OR REPLACE FUNCTION public.get_or_create_shop_conversation(
  p_shop_id UUID
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_buyer_id UUID := auth.uid();
  v_shop_owner_id UUID;
  v_conv_id UUID;
  v_direct_key TEXT;
BEGIN
  IF v_buyer_id IS NULL THEN
    RAISE EXCEPTION 'Vui lòng đăng nhập để nhắn tin với Shop.';
  END IF;

  -- Lấy chủ sở hữu của shop
  SELECT owner_id INTO v_shop_owner_id
  FROM public.shops
  WHERE id = p_shop_id;

  IF v_shop_owner_id IS NULL THEN
    RAISE EXCEPTION 'Gian hàng không tồn tại hoặc đã ngừng hoạt động.';
  END IF;

  -- Định danh duy nhất cho cuộc trò chuyện giữa Shop này và Người mua này
  v_direct_key := 'shop:' || p_shop_id::text || ':' || v_buyer_id::text;

  -- Tìm conversation đã tồn tại
  SELECT id INTO v_conv_id
  FROM public.conversations
  WHERE (type = 'shop' AND shop_id = p_shop_id AND direct_key = v_direct_key)
     OR (type = 'shop' AND shop_id = p_shop_id AND id IN (
          SELECT conversation_id FROM public.conversation_participants WHERE user_id = v_buyer_id
        ))
  LIMIT 1;

  -- Nếu chưa có thì tạo mới
  IF v_conv_id IS NULL THEN
    INSERT INTO public.conversations (
      type,
      shop_id,
      direct_key,
      created_at,
      updated_at
    ) VALUES (
      'shop',
      p_shop_id,
      v_direct_key,
      NOW(),
      NOW()
    )
    RETURNING id INTO v_conv_id;

    -- Thêm người mua vào conversation_participants
    INSERT INTO public.conversation_participants (conversation_id, user_id, last_read_at)
    VALUES (v_conv_id, v_buyer_id, NOW())
    ON CONFLICT (conversation_id, user_id) DO NOTHING;

    -- Thêm chủ sở hữu shop vào conversation_participants (nếu khác người mua)
    IF v_shop_owner_id <> v_buyer_id THEN
      INSERT INTO public.conversation_participants (conversation_id, user_id, last_read_at)
      VALUES (v_conv_id, v_shop_owner_id, NOW())
      ON CONFLICT (conversation_id, user_id) DO NOTHING;
    END IF;
  END IF;

  RETURN v_conv_id;
END;
$$;

-- Cấp quyền gọi RPC cho authenticated users
GRANT EXECUTE ON FUNCTION public.get_or_create_shop_conversation(UUID) TO authenticated;

-- ==============================================================================
-- Thông báo hoàn thành migration
-- ==============================================================================
COMMENT ON FUNCTION public.get_or_create_shop_conversation(UUID)
  IS 'Tạo hoặc lấy cuộc hội thoại CSKH riêng biệt giữa người mua và gian hàng shop.';

