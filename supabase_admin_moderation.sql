-- ==============================================================================
-- Migration: Quản Trị Hệ Thống Theo Chuẩn TikTok (TikTok Moderation & Admin System)
-- 1. Quản lý Người dùng: Tích xanh, Ban tài khoản, Cấm Livestream, Cảnh cáo vi phạm
-- 2. Kiểm duyệt Gian hàng Shop: Phê duyệt hồ sơ đăng ký shop, từ chối, cấp tích xanh shop
-- ==============================================================================

-- 1. Bổ sung các cột kiểm duyệt vào bảng profiles
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'is_banned') THEN
    ALTER TABLE public.profiles ADD COLUMN is_banned BOOLEAN DEFAULT FALSE;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'ban_reason') THEN
    ALTER TABLE public.profiles ADD COLUMN ban_reason TEXT;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'banned_at') THEN
    ALTER TABLE public.profiles ADD COLUMN banned_at TIMESTAMPTZ;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'banned_until') THEN
    ALTER TABLE public.profiles ADD COLUMN banned_until TIMESTAMPTZ;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'can_live') THEN
    ALTER TABLE public.profiles ADD COLUMN can_live BOOLEAN DEFAULT TRUE;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'can_comment') THEN
    ALTER TABLE public.profiles ADD COLUMN can_comment BOOLEAN DEFAULT TRUE;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'can_post_video') THEN
    ALTER TABLE public.profiles ADD COLUMN can_post_video BOOLEAN DEFAULT TRUE;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'strike_count') THEN
    ALTER TABLE public.profiles ADD COLUMN strike_count INTEGER DEFAULT 0;
  END IF;
END $$;

-- 2. Bổ sung các cột kiểm duyệt vào bảng shops
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'shops' AND column_name = 'rejection_reason') THEN
    ALTER TABLE public.shops ADD COLUMN rejection_reason TEXT;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'shops' AND column_name = 'approved_at') THEN
    ALTER TABLE public.shops ADD COLUMN approved_at TIMESTAMPTZ;
  END IF;
END $$;

-- 3. Đảm bảo ràng buộc trạng thái shop hỗ trợ 'pending', 'active', 'rejected', 'blocked'
DO $$
BEGIN
  ALTER TABLE public.shops DROP CONSTRAINT IF EXISTS shops_status_check;
  ALTER TABLE public.shops
    ADD CONSTRAINT shops_status_check
    CHECK (status IN ('pending', 'active', 'rejected', 'blocked'));
EXCEPTION
  WHEN OTHERS THEN NULL;
END $$;

-- 4. Tạo chỉ mục tìm kiếm nhanh cho kiểm duyệt
CREATE INDEX IF NOT EXISTS idx_profiles_is_banned ON public.profiles(is_banned);
CREATE INDEX IF NOT EXISTS idx_profiles_can_live ON public.profiles(can_live);
CREATE INDEX IF NOT EXISTS idx_shops_status ON public.shops(status);

-- 5. Cho phép người dùng xem thông tin và Admin cập nhật kiểm duyệt
DROP POLICY IF EXISTS "profiles_admin_update" ON public.profiles;
CREATE POLICY "profiles_admin_update"
ON public.profiles
AS PERMISSIVE
FOR UPDATE
TO PUBLIC
USING (true)
WITH CHECK (true);

-- Cho phép Admin cập nhật trạng thái phê duyệt gian hàng shop
DROP POLICY IF EXISTS "shops_admin_update" ON public.shops;
CREATE POLICY "shops_admin_update"
ON public.shops
AS PERMISSIVE
FOR UPDATE
TO PUBLIC
USING (true)
WITH CHECK (true);

