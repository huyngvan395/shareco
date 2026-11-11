-- ============================================================================
-- SHARECO: HỆ THỐNG THÔNG BÁO ĐẨY REALTIME (PUSH NOTIFICATIONS),
-- THẢ TIM BÌNH LUẬN (COMMENT LIKES), LƯU VIDEO (SAVED VIDEOS) & BÁO CÁO (REPORTS)
-- Cách dùng: Copy toàn bộ nội dung file này vào Supabase Dashboard -> SQL Editor -> Run
-- ============================================================================

-- 1. CẬP NHẬT RLS CHO BẢNG NOTIFICATIONS & REPORTS
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS notifications_read_own ON public.notifications;
CREATE POLICY notifications_read_own
  ON public.notifications FOR SELECT TO authenticated
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS notifications_update_own ON public.notifications;
CREATE POLICY notifications_update_own
  ON public.notifications FOR UPDATE TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS notifications_insert_authenticated ON public.notifications;
CREATE POLICY notifications_insert_authenticated
  ON public.notifications FOR INSERT TO authenticated
  WITH CHECK (true);

DROP POLICY IF EXISTS notifications_delete_own ON public.notifications;
CREATE POLICY notifications_delete_own
  ON public.notifications FOR DELETE TO authenticated
  USING (auth.uid() = user_id);

ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS reports_insert_own ON public.reports;
CREATE POLICY reports_insert_own
  ON public.reports FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = reporter_id);

DROP POLICY IF EXISTS reports_read_own ON public.reports;
CREATE POLICY reports_read_own
  ON public.reports FOR SELECT TO authenticated
  USING (auth.uid() = reporter_id);

-- 2. BẢNG THẢ TIM BÌNH LUẬN (VIDEO_COMMENT_LIKES) & RPC TOGGLE
CREATE TABLE IF NOT EXISTS public.video_comment_likes (
  comment_id uuid NOT NULL REFERENCES public.video_comments(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (comment_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_video_comment_likes_user
  ON public.video_comment_likes (user_id, comment_id);

ALTER TABLE public.video_comment_likes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS video_comment_likes_public_read ON public.video_comment_likes;
CREATE POLICY video_comment_likes_public_read
  ON public.video_comment_likes FOR SELECT TO public
  USING (true);

DROP POLICY IF EXISTS video_comment_likes_insert_own ON public.video_comment_likes;
CREATE POLICY video_comment_likes_insert_own
  ON public.video_comment_likes FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS video_comment_likes_delete_own ON public.video_comment_likes;
CREATE POLICY video_comment_likes_delete_own
  ON public.video_comment_likes FOR DELETE TO authenticated
  USING (auth.uid() = user_id);

CREATE OR REPLACE FUNCTION public.handle_comment_like_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE public.video_comments
    SET like_count = like_count + 1
    WHERE id = NEW.comment_id;
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE public.video_comments
    SET like_count = GREATEST(0, like_count - 1)
    WHERE id = OLD.comment_id;
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_video_comment_likes_change ON public.video_comment_likes;
CREATE TRIGGER trg_video_comment_likes_change
AFTER INSERT OR DELETE ON public.video_comment_likes
FOR EACH ROW
EXECUTE FUNCTION public.handle_comment_like_change();

CREATE OR REPLACE FUNCTION public.toggle_comment_like(p_comment_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_exists boolean;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Unauthenticated';
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM public.video_comment_likes
    WHERE comment_id = p_comment_id AND user_id = v_uid
  ) INTO v_exists;

  IF v_exists THEN
    DELETE FROM public.video_comment_likes
    WHERE comment_id = p_comment_id AND user_id = v_uid;
    RETURN false;
  ELSE
    INSERT INTO public.video_comment_likes (comment_id, user_id)
    VALUES (p_comment_id, v_uid)
    ON CONFLICT DO NOTHING;
    RETURN true;
  END IF;
END;
$$;

-- 3. BẢNG LƯU VIDEO (SAVED_VIDEOS) & RPC TOGGLE
CREATE TABLE IF NOT EXISTS public.saved_videos (
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  video_id uuid NOT NULL REFERENCES public.videos(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, video_id)
);

CREATE INDEX IF NOT EXISTS idx_saved_videos_user_created
  ON public.saved_videos (user_id, created_at DESC);

ALTER TABLE public.saved_videos ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS saved_videos_read_own ON public.saved_videos;
CREATE POLICY saved_videos_read_own
  ON public.saved_videos FOR SELECT TO authenticated
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS saved_videos_insert_own ON public.saved_videos;
CREATE POLICY saved_videos_insert_own
  ON public.saved_videos FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS saved_videos_delete_own ON public.saved_videos;
CREATE POLICY saved_videos_delete_own
  ON public.saved_videos FOR DELETE TO authenticated
  USING (auth.uid() = user_id);

CREATE OR REPLACE FUNCTION public.toggle_saved_video(p_video_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_exists boolean;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Unauthenticated';
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM public.saved_videos
    WHERE user_id = v_uid AND video_id = p_video_id
  ) INTO v_exists;

  IF v_exists THEN
    DELETE FROM public.saved_videos
    WHERE user_id = v_uid AND video_id = p_video_id;
    RETURN false;
  ELSE
    INSERT INTO public.saved_videos (user_id, video_id)
    VALUES (v_uid, p_video_id)
    ON CONFLICT DO NOTHING;
    RETURN true;
  END IF;
END;
$$;

-- 4. HÀM TRUNG TÂM PHÁT THÔNG BÁO (CHỐNG TRÙNG LẶP & KHÔNG GỬI CHO CHÍNH MÌNH)
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

  -- Không gửi thông báo tương tác cho chính người thực hiện
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

-- 5. TRIGGER 1: BÌNH LUẬN VIDEO, TRẢ LỜI BÌNH LUẬN & NHẮC ĐẾN (@MENTION) TRONG BÌNH LUẬN
CREATE OR REPLACE FUNCTION public.trg_fn_notify_video_comment()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_actor record;
  v_video record;
  v_parent_user_id uuid;
  v_snippet text;
  v_mention text;
  v_mentioned_user_id uuid;
BEGIN
  SELECT id, username, display_name, avatar_url
  INTO v_actor
  FROM public.profiles
  WHERE id = NEW.user_id;

  SELECT id, author_id, caption, thumbnail_path
  INTO v_video
  FROM public.videos
  WHERE id = NEW.video_id;

  v_snippet := left(COALESCE(NEW.content, ''), 80);

  -- 5.1. Nếu là phản hồi bình luận -> thông báo cho chủ bình luận gốc
  IF NEW.parent_id IS NOT NULL THEN
    SELECT user_id INTO v_parent_user_id
    FROM public.video_comments
    WHERE id = NEW.parent_id;

    IF v_parent_user_id IS NOT NULL AND v_parent_user_id <> NEW.user_id THEN
      PERFORM public.emit_app_notification(
        v_parent_user_id,
        NEW.user_id,
        'comment_reply',
        COALESCE(v_actor.display_name, '@' || v_actor.username, 'Ai đó') || ' đã trả lời bình luận của bạn',
        '"' || v_snippet || '"',
        jsonb_build_object(
          'video_id', NEW.video_id,
          'comment_id', NEW.id,
          'parent_id', NEW.parent_id,
          'actor_id', NEW.user_id,
          'actor_username', v_actor.username,
          'actor_avatar', v_actor.avatar_url,
          'thumbnail_url', v_video.thumbnail_path,
          'dedupe_key', 'reply_' || NEW.id::text
        )
      );
    END IF;
  END IF;

  -- 5.2. Thông báo cho chủ video (nếu khác người bình luận và chưa nhận thông báo reply trùng)
  IF v_video.author_id IS NOT NULL
     AND v_video.author_id <> NEW.user_id
     AND (v_parent_user_id IS NULL OR v_video.author_id <> v_parent_user_id) THEN
    PERFORM public.emit_app_notification(
      v_video.author_id,
      NEW.user_id,
      'comment',
      COALESCE(v_actor.display_name, '@' || v_actor.username, 'Ai đó') || ' đã bình luận video của bạn',
      '"' || v_snippet || '"',
      jsonb_build_object(
        'video_id', NEW.video_id,
        'comment_id', NEW.id,
        'actor_id', NEW.user_id,
        'actor_username', v_actor.username,
        'actor_avatar', v_actor.avatar_url,
        'thumbnail_url', v_video.thumbnail_path,
        'dedupe_key', 'comment_' || NEW.id::text
      )
    );
  END IF;

  -- 5.3. Quét các lượt nhắc tên @username trong nội dung bình luận
  IF NEW.content IS NOT NULL AND position('@' in NEW.content) > 0 THEN
    FOR v_mention IN
      SELECT DISTINCT lower(m[1])
      FROM regexp_matches(NEW.content, '@([a-zA-Z0-9_.]{2,32})', 'g') AS m
    LOOP
      SELECT id INTO v_mentioned_user_id
      FROM public.profiles
      WHERE lower(username) = v_mention
      LIMIT 1;

      IF v_mentioned_user_id IS NOT NULL
         AND v_mentioned_user_id <> NEW.user_id
         AND v_mentioned_user_id IS DISTINCT FROM v_parent_user_id THEN
        PERFORM public.emit_app_notification(
          v_mentioned_user_id,
          NEW.user_id,
          'mention',
          COALESCE(v_actor.display_name, '@' || v_actor.username, 'Ai đó') || ' đã nhắc đến bạn trong bình luận',
          '"' || v_snippet || '"',
          jsonb_build_object(
            'video_id', NEW.video_id,
            'comment_id', NEW.id,
            'actor_id', NEW.user_id,
            'actor_username', v_actor.username,
            'actor_avatar', v_actor.avatar_url,
            'thumbnail_url', v_video.thumbnail_path,
            'dedupe_key', 'mention_cmt_' || NEW.id::text || '_' || v_mentioned_user_id::text
          )
        );
      END IF;
    END LOOP;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_video_comment ON public.video_comments;
CREATE TRIGGER trg_notify_video_comment
AFTER INSERT ON public.video_comments
FOR EACH ROW
EXECUTE FUNCTION public.trg_fn_notify_video_comment();

-- 6. TRIGGER 2: THẢ TIM BÌNH LUẬN (COMMENT LIKE)
CREATE OR REPLACE FUNCTION public.trg_fn_notify_comment_like()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_actor record;
  v_comment record;
BEGIN
  SELECT id, username, display_name, avatar_url
  INTO v_actor
  FROM public.profiles
  WHERE id = NEW.user_id;

  SELECT id, user_id, video_id, content
  INTO v_comment
  FROM public.video_comments
  WHERE id = NEW.comment_id;

  IF v_comment.user_id IS NOT NULL AND v_comment.user_id <> NEW.user_id THEN
    PERFORM public.emit_app_notification(
      v_comment.user_id,
      NEW.user_id,
      'comment_like',
      COALESCE(v_actor.display_name, '@' || v_actor.username, 'Ai đó') || ' đã thả tim bình luận của bạn',
      '"' || left(COALESCE(v_comment.content, ''), 80) || '"',
      jsonb_build_object(
        'video_id', v_comment.video_id,
        'comment_id', v_comment.id,
        'actor_id', NEW.user_id,
        'actor_username', v_actor.username,
        'actor_avatar', v_actor.avatar_url,
        'dedupe_key', 'cmt_like_' || v_comment.id::text || '_' || NEW.user_id::text
      )
    );
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_comment_like ON public.video_comment_likes;
CREATE TRIGGER trg_notify_comment_like
AFTER INSERT ON public.video_comment_likes
FOR EACH ROW
EXECUTE FUNCTION public.trg_fn_notify_comment_like();

-- 7. TRIGGER 3: THẢ TIM VIDEO (VIDEO LIKE)
CREATE OR REPLACE FUNCTION public.trg_fn_notify_video_like()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_actor record;
  v_video record;
BEGIN
  SELECT id, username, display_name, avatar_url
  INTO v_actor
  FROM public.profiles
  WHERE id = NEW.user_id;

  SELECT id, author_id, caption, thumbnail_path
  INTO v_video
  FROM public.videos
  WHERE id = NEW.video_id;

  IF v_video.author_id IS NOT NULL AND v_video.author_id <> NEW.user_id THEN
    PERFORM public.emit_app_notification(
      v_video.author_id,
      NEW.user_id,
      'video_like',
      COALESCE(v_actor.display_name, '@' || v_actor.username, 'Ai đó') || ' đã thích video của bạn',
      CASE
        WHEN COALESCE(v_video.caption, '') <> '' THEN '"' || left(v_video.caption, 80) || '"'
        ELSE 'Nhấn để xem video của bạn'
      END,
      jsonb_build_object(
        'video_id', v_video.id,
        'actor_id', NEW.user_id,
        'actor_username', v_actor.username,
        'actor_avatar', v_actor.avatar_url,
        'thumbnail_url', v_video.thumbnail_path,
        'dedupe_key', 'vid_like_' || v_video.id::text || '_' || NEW.user_id::text
      )
    );
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_video_like ON public.video_likes;
CREATE TRIGGER trg_notify_video_like
AFTER INSERT ON public.video_likes
FOR EACH ROW
EXECUTE FUNCTION public.trg_fn_notify_video_like();

-- 8. TRIGGER 4: VIDEO MỚI TỪ NGƯỜI ĐÃ FOLLOW & GẮN THẺ (@MENTION) TRONG CAPTION VIDEO
CREATE OR REPLACE FUNCTION public.trg_fn_notify_video_events()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_actor record;
  v_mention text;
  v_mentioned_user_id uuid;
  v_follower_id uuid;
  v_is_newly_published boolean := false;
BEGIN
  SELECT id, username, display_name, avatar_url
  INTO v_actor
  FROM public.profiles
  WHERE id = NEW.author_id;

  v_is_newly_published := (
    NEW.status = 'published'
    AND NEW.visibility = 'public'
    AND (TG_OP = 'INSERT' OR OLD.status IS DISTINCT FROM 'published')
  );

  -- 8.1. Gắn thẻ @username trong mô tả video (khi đăng hoặc khi được duyệt công khai)
  IF NEW.caption IS NOT NULL
     AND position('@' in NEW.caption) > 0
     AND NEW.visibility <> 'private'
     AND (TG_OP = 'INSERT' OR OLD.caption IS DISTINCT FROM NEW.caption OR v_is_newly_published) THEN
    FOR v_mention IN
      SELECT DISTINCT lower(m[1])
      FROM regexp_matches(NEW.caption, '@([a-zA-Z0-9_.]{2,32})', 'g') AS m
    LOOP
      SELECT id INTO v_mentioned_user_id
      FROM public.profiles
      WHERE lower(username) = v_mention
      LIMIT 1;

      IF v_mentioned_user_id IS NOT NULL AND v_mentioned_user_id <> NEW.author_id THEN
        PERFORM public.emit_app_notification(
          v_mentioned_user_id,
          NEW.author_id,
          'mention',
          COALESCE(v_actor.display_name, '@' || v_actor.username, 'Ai đó') || ' đã gắn thẻ bạn trong một video',
          '"' || left(NEW.caption, 80) || '"',
          jsonb_build_object(
            'video_id', NEW.id,
            'actor_id', NEW.author_id,
            'actor_username', v_actor.username,
            'actor_avatar', v_actor.avatar_url,
            'thumbnail_url', NEW.thumbnail_path,
            'dedupe_key', 'mention_vid_' || NEW.id::text || '_' || v_mentioned_user_id::text
          )
        );
      END IF;
    END LOOP;
  END IF;

  -- 8.2. Thông báo video mới cho tất cả người đang theo dõi tác giả
  IF v_is_newly_published THEN
    FOR v_follower_id IN
      SELECT follower_id
      FROM public.user_follows
      WHERE following_id = NEW.author_id
    LOOP
      PERFORM public.emit_app_notification(
        v_follower_id,
        NEW.author_id,
        'new_video',
        COALESCE(v_actor.display_name, '@' || v_actor.username, 'Creator') || ' vừa đăng video mới',
        CASE
          WHEN COALESCE(NEW.caption, '') <> '' THEN left(NEW.caption, 90)
          ELSE 'Nhấn để xem ngay video mới nhất!'
        END,
        jsonb_build_object(
          'video_id', NEW.id,
          'actor_id', NEW.author_id,
          'actor_username', v_actor.username,
          'actor_avatar', v_actor.avatar_url,
          'thumbnail_url', NEW.thumbnail_path,
          'dedupe_key', 'new_vid_' || NEW.id::text || '_' || v_follower_id::text
        )
      );
    END LOOP;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_video_events ON public.videos;
CREATE TRIGGER trg_notify_video_events
AFTER INSERT OR UPDATE OF status, caption ON public.videos
FOR EACH ROW
EXECUTE FUNCTION public.trg_fn_notify_video_events();

-- 9. TRIGGER 5: THÔNG BÁO PHÁT TRỰC TIẾP (LIVESTREAM) CHO NGƯỜI ĐÃ FOLLOW
CREATE OR REPLACE FUNCTION public.trg_fn_notify_livestream_start()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_host record;
  v_follower_id uuid;
BEGIN
  IF NEW.status <> 'live' THEN
    RETURN NEW;
  END IF;

  SELECT id, username, display_name, avatar_url
  INTO v_host
  FROM public.profiles
  WHERE id = NEW.host_id;

  FOR v_follower_id IN
    SELECT follower_id
    FROM public.user_follows
    WHERE following_id = NEW.host_id
  LOOP
    PERFORM public.emit_app_notification(
      v_follower_id,
      NEW.host_id,
      'livestream',
      '🔴 ' || COALESCE(v_host.display_name, '@' || v_host.username, 'Creator') || ' đang phát trực tiếp!',
      COALESCE(NEW.title, 'Vào xem phiên Live ngay!'),
      jsonb_build_object(
        'livestream_id', NEW.id,
        'channel_name', NEW.channel_name,
        'host_id', NEW.host_id,
        'title', NEW.title,
        'actor_id', NEW.host_id,
        'actor_username', v_host.username,
        'actor_avatar', v_host.avatar_url,
        'dedupe_key', 'live_' || NEW.id::text || '_' || v_follower_id::text
      )
    );
  END LOOP;

  RETURN NEW;
END;
$$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'livestreams'
  ) THEN
    DROP TRIGGER IF EXISTS trg_notify_livestream_start ON public.livestreams;
    CREATE TRIGGER trg_notify_livestream_start
    AFTER INSERT ON public.livestreams
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_fn_notify_livestream_start();
  END IF;
END $$;

-- 10. TRIGGER 6: NGƯỜI THEO DÕI MỚI (NEW FOLLOWER)
CREATE OR REPLACE FUNCTION public.trg_fn_notify_new_follower()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_actor record;
BEGIN
  SELECT id, username, display_name, avatar_url
  INTO v_actor
  FROM public.profiles
  WHERE id = NEW.follower_id;

  PERFORM public.emit_app_notification(
    NEW.following_id,
    NEW.follower_id,
    'follow',
    'Người theo dõi mới',
    COALESCE(v_actor.display_name, '@' || v_actor.username, 'Ai đó') || ' đã bắt đầu theo dõi bạn',
    jsonb_build_object(
      'actor_id', NEW.follower_id,
      'actor_username', v_actor.username,
      'actor_avatar', v_actor.avatar_url,
      'dedupe_key', 'follow_' || NEW.follower_id::text || '_' || NEW.following_id::text
    )
  );

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_new_follower ON public.user_follows;
CREATE TRIGGER trg_notify_new_follower
AFTER INSERT ON public.user_follows
FOR EACH ROW
EXECUTE FUNCTION public.trg_fn_notify_new_follower();

-- 11. TRIGGER 7: NHẬN QUÀ TẶNG TRONG LIVESTREAM
CREATE OR REPLACE FUNCTION public.trg_fn_notify_livestream_gift()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_sender record;
BEGIN
  SELECT id, username, display_name, avatar_url
  INTO v_sender
  FROM public.profiles
  WHERE id = NEW.sender_id;

  PERFORM public.emit_app_notification(
    NEW.receiver_id,
    NEW.sender_id,
    'gift',
    '🎁 Bạn nhận được quà tặng Livestream!',
    COALESCE(v_sender.display_name, '@' || v_sender.username, 'Khán giả')
      || ' đã tặng ' || NEW.quantity || 'x ' || NEW.gift_icon || ' ' || NEW.gift_name
      || ' (+' || NEW.total_coins || ' xu)',
    jsonb_build_object(
      'livestream_id', NEW.livestream_id,
      'gift_id', NEW.id,
      'coins', NEW.total_coins,
      'actor_id', NEW.sender_id,
      'actor_username', v_sender.username,
      'actor_avatar', v_sender.avatar_url,
      'dedupe_key', 'gift_' || NEW.id::text
    )
  );

  RETURN NEW;
END;
$$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'livestream_gifts'
  ) THEN
    DROP TRIGGER IF EXISTS trg_notify_livestream_gift ON public.livestream_gifts;
    CREATE TRIGGER trg_notify_livestream_gift
    AFTER INSERT ON public.livestream_gifts
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_fn_notify_livestream_gift();
  END IF;
END $$;

-- 12. TRIGGER 8: ĐƠN HÀNG MỚI & CẬP NHẬT TRẠNG THÁI ĐƠN HÀNG
CREATE OR REPLACE FUNCTION public.trg_fn_notify_order_events()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_shop record;
  v_short_id text := upper(left(NEW.id::text, 8));
  v_status_label text;
BEGIN
  SELECT id, owner_id, shop_name
  INTO v_shop
  FROM public.shops
  WHERE id = NEW.shop_id;

  IF TG_OP = 'INSERT' THEN
    -- Thông báo cho Chủ shop có đơn mới
    IF v_shop.owner_id IS NOT NULL AND v_shop.owner_id <> NEW.buyer_id THEN
      PERFORM public.emit_app_notification(
        v_shop.owner_id,
        NEW.buyer_id,
        'new_order',
        '🛒 Đơn hàng mới #' || v_short_id,
        'Cửa hàng ' || COALESCE(v_shop.shop_name, '') || ' vừa nhận một đơn hàng mới.',
        jsonb_build_object(
          'order_id', NEW.id,
          'shop_id', NEW.shop_id,
          'dedupe_key', 'new_order_' || NEW.id::text
        )
      );
    END IF;

    -- Thông báo xác nhận cho Người mua
    PERFORM public.emit_app_notification(
      NEW.buyer_id,
      NULL,
      'order',
      '📦 Đặt hàng thành công #' || v_short_id,
      'Đơn hàng của bạn đã được ghi nhận và đang chờ người bán xác nhận.',
      jsonb_build_object(
        'order_id', NEW.id,
        'status', NEW.status,
        'dedupe_key', 'order_created_' || NEW.id::text
      )
    );
  ELSIF TG_OP = 'UPDATE' AND OLD.status IS DISTINCT FROM NEW.status THEN
    v_status_label := CASE NEW.status
      WHEN 'paid' THEN 'đã được xác nhận thanh toán'
      WHEN 'packed' THEN 'đã được đóng gói và chuẩn bị giao'
      WHEN 'shipping' THEN 'đang trên đường giao đến bạn'
      WHEN 'completed' THEN 'đã giao thành công. Hãy đánh giá sản phẩm nhé!'
      WHEN 'cancelled' THEN 'đã bị hủy'
      ELSE 'đã cập nhật trạng thái: ' || NEW.status
    END;

    PERFORM public.emit_app_notification(
      NEW.buyer_id,
      NULL,
      'order_status',
      '🚚 Cập nhật đơn hàng #' || v_short_id,
      'Đơn hàng #' || v_short_id || ' ' || v_status_label,
      jsonb_build_object(
        'order_id', NEW.id,
        'status', NEW.status,
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

-- 13. TRIGGER 9: CẬP NHẬT TRẠNG THÁI RÚT TIỀN VÍ XU
CREATE OR REPLACE FUNCTION public.trg_fn_notify_withdrawal_status()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF OLD.status IS DISTINCT FROM NEW.status THEN
    PERFORM public.emit_app_notification(
      NEW.user_id,
      NULL,
      'wallet',
      CASE NEW.status
        WHEN 'approved' THEN '💰 Yêu cầu rút tiền đã được duyệt'
        WHEN 'rejected' THEN '⚠️ Yêu cầu rút tiền bị từ chối'
        ELSE '💰 Cập nhật yêu cầu rút tiền'
      END,
      CASE NEW.status
        WHEN 'approved' THEN 'Khoản rút ' || NEW.coin_amount || ' xu về ' || NEW.bank_name || ' đã được xử lý thành công.'
        WHEN 'rejected' THEN 'Yêu cầu rút ' || NEW.coin_amount || ' xu không thành công.' || COALESCE(' Lý do: ' || NEW.note, '')
        ELSE 'Trạng thái yêu cầu rút ' || NEW.coin_amount || ' xu: ' || NEW.status
      END,
      jsonb_build_object(
        'withdrawal_id', NEW.id,
        'status', NEW.status,
        'dedupe_key', 'withdraw_' || NEW.id::text || '_' || NEW.status
      )
    );
  END IF;

  RETURN NEW;
END;
$$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'withdrawal_requests'
  ) THEN
    DROP TRIGGER IF EXISTS trg_notify_withdrawal_status ON public.withdrawal_requests;
    CREATE TRIGGER trg_notify_withdrawal_status
    AFTER UPDATE OF status ON public.withdrawal_requests
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_fn_notify_withdrawal_status();
  END IF;
END $$;

-- 14. BẬT SUPABASE REALTIME CHO BẢNG NOTIFICATIONS & MESSAGES
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    BEGIN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
    EXCEPTION WHEN duplicate_object THEN NULL;
    END;
    BEGIN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
    EXCEPTION WHEN duplicate_object THEN NULL;
    END;
  END IF;
END $$;

