import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  static String get supabaseUrl {
    final url = dotenv.env['SUPABASE_URL'];
    if (url == null || url.isEmpty){
      throw Exception("Supabase Url not found!");
    }
    return url;
  }
  static String get supabaseAnonKey {
    final anonKey = dotenv.env['SUPABASE_ANON_KEY'];
    if (anonKey == null || anonKey.isEmpty){
      throw Exception("Supabase anon key not found!");
    }
    return anonKey;
  }

  // ── Storage buckets (khớp với Supabase Dashboard → Storage) ──────────────
  static const bucketAvatars        = 'avatars';
  static const bucketVideoOriginals = 'video-originals';
  static const bucketVideoThumbs    = 'video-thumbnails';
  static const bucketProductMedia   = 'product-media';
  static const bucketReviewMedia    = 'review-media';
  static const bucketChatAttach     = 'chat-attachments';

  // ── Storage path conventions ──────────────────────────────────────────────
  static String avatarPath(String userId) => '$userId/avatar.jpg';
  static String videoOriginalPath(String userId, String videoId) =>
      '$userId/$videoId.mp4';
  static String videoThumbPath(String userId, String videoId) =>
      '$userId/$videoId.jpg';
  static String productMediaPath(
      String shopId, String productId, String fileName) =>
      '$shopId/$productId/$fileName';

  // ── Pagination defaults ───────────────────────────────────────────────────
  static const defaultPageSize = 10;
  static const videoPageSize   = 7;
  static const commentPageSize = 20;
  static const notifPageSize   = 20;
  static const productPageSize = 12;
  static const orderPageSize   = 10;

  static String get cloudinaryCloudName {
    final name = dotenv.env['CLOUDINARY_CLOUD_NAME'];
    if (name == null || name.isEmpty){
      throw Exception("Cloudinary name not found!");
    }
    return name;
  }

  static String get cloudinaryApiKey{
    final key = dotenv.env['CLOUDINARY_API_KEY'];
    if (key == null || key.isEmpty){
      throw Exception("Cloudinary key not found!");
    }
    return key;
  }

  static String get cloudinaryApiSecret{
    final secret = dotenv.env['CLOUDINARY_API_SECRET'];
    if (secret == null || secret.isEmpty){
      throw Exception("Cloudinary secret not found!");
    }
    return secret;
  }

  static String get cloudinaryUploadPreset{
    final preset = dotenv.env['CLOUDINARY_UPLOAD_PRESET'];
    if (preset == null || preset.isEmpty){
      throw Exception("Cloudinary upload preset not found!");
    }
    return preset;
  }

}