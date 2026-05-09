import '../services/supabase/index.dart';
import '../constants/env.dart';

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

  /// Resolve Supabase Storage path → public URL
  static String videoUrl(String path) {
    if (path.startsWith('http')) return path;
    return SupabaseService.publicUrl(Env.bucketVideoOriginals, path);
  }

  static String thumbnailUrl(String path) {
    if (path.startsWith('http')) return path;
    return SupabaseService.publicUrl(Env.bucketVideoThumbs, path);
  }

  static String avatarUrl(String path) {
    if (path.startsWith('http')) return path;
    return SupabaseService.publicUrl(Env.bucketAvatars, path);
  }

  static String productMediaUrl(String path) {
    if (path.startsWith('http')) return path;
    return SupabaseService.publicUrl(Env.bucketProductMedia, path);
  }

  /// Format large numbers: 1200 → "1.2K", 1_200_000 → "1.2M"
  static String formatCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }

  /// Format currency in VND
  static String formatVnd(double amount) {
    if (amount >= 1000000) return '${(amount / 1000000).toStringAsFixed(1)}M₫';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(0)}K₫';
    return '${amount.toStringAsFixed(0)}₫';
  }
}

