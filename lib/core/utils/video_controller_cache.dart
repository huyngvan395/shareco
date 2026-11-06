import 'package:video_player/video_player.dart';
import 'storage_image.dart';

/// Shared LRU-like cache for [VideoPlayerController] instances across
/// [FeedScreen], [SearchFeedScreen], and [ProfileFeedScreen].
class VideoControllerCache {
  final Map<String, VideoPlayerController> _cache = {};
  final Map<String, Future<VideoPlayerController>> _pending = {};
  static const int _max = 5;

  Future<VideoPlayerController> getOrCreate(String path) async {
    final url = StorageImage.videoUrl(path);
    if (_cache.containsKey(url)) {
      // Refresh LRU order so active/recently used controllers are not evicted
      final ctrl = _cache.remove(url)!;
      _cache[url] = ctrl;
      return ctrl;
    }
    if (_pending.containsKey(url)) return _pending[url]!;

    final future = _create(url);
    _pending[url] = future;
    return future;
  }

  Future<VideoPlayerController> _create(String url) async {
    if (_cache.length >= _max) {
      final old = _cache.keys.first;
      final oldCtrl = _cache.remove(old);
      await oldCtrl?.dispose();
    }
    final ctrl = VideoPlayerController.networkUrl(
      Uri.parse(url),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    try {
      await ctrl.initialize();
      await ctrl.setLooping(true);
      _cache[url] = ctrl;
      return ctrl;
    } catch (e) {
      await ctrl.dispose();
      rethrow;
    } finally {
      _pending.remove(url);
    }
  }

  void pauseAll() {
    for (final c in _cache.values) {
      c.pause();
    }
  }

  Future<void> disposeAll() async {
    for (final c in _cache.values) {
      await c.dispose();
    }
    _cache.clear();
    _pending.clear();
  }
}

