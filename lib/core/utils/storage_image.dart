import '../services/supabase/index.dart';

abstract class StorageBuckets {
  static const productMedia = 'product-media';
  static const avatars = 'avatars';
  static const videoThumbnails = 'video-thumbnails';
  static const reviewMedia = 'review-media';
  static const chatAttachments = 'chat-attachments';
}

abstract class StorageImage {
  static String? publicUrl(
    String? path, {
    String bucket = StorageBuckets.productMedia,
  }) {
    final value = path?.trim();
    if (value == null || value.isEmpty) return null;
    if (_isNetworkUrl(value)) return value;

    final normalizedPath = _normalizePath(value, bucket);
    if (normalizedPath.isEmpty) return null;

    try {
      return SupabaseService.storage.from(bucket).getPublicUrl(normalizedPath);
    } catch (_) {
      return null;
    }
  }

  static bool _isNetworkUrl(String value) {
    return value.startsWith('http://') || value.startsWith('https://');
  }

  static String _normalizePath(String path, String bucket) {
    var normalized = path.replaceAll('\\', '/').trim();

    while (normalized.startsWith('/')) {
      normalized = normalized.substring(1);
    }

    final bucketPrefix = '$bucket/';
    if (normalized.startsWith(bucketPrefix)) {
      normalized = normalized.substring(bucketPrefix.length);
    }

    return normalized;
  }
}
