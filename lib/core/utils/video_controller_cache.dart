import 'dart:async';
import 'package:video_player/video_player.dart';
import 'storage_image.dart';

/// Bộ quản lý bộ nhớ đệm [VideoPlayerController] an toàn tham chiếu (Reference-Counted)
/// và giới hạn số lượng bộ giải mã phần cứng MediaCodec để chống tràn RAM / crash khi lướt nhanh.
class VideoControllerCache {
  static final Set<VideoControllerCache> _activeCaches =
      <VideoControllerCache>{};
  static final Expando<bool> _disposedFlag = Expando<bool>('disposedVideoCtrl');

  /// Kiểm tra một [VideoPlayerController] đã bị giải phóng hay chưa.
  static bool isControllerDisposed(VideoPlayerController? ctrl) {
    if (ctrl == null) return true;
    return _disposedFlag[ctrl] == true;
  }

  /// Tạm dừng toàn bộ video đang phát trên mọi màn hình và dọn các controller nhàn rỗi.
  static void pauseAllGlobal({VideoControllerCache? except}) {
    for (final cache in List<VideoControllerCache>.from(_activeCaches)) {
      if (cache == except) continue;
      cache.pauseAll();
      cache.evictIdle();
    }
  }

  final int maxControllers;
  final Map<String, VideoPlayerController> _cache = {};
  final Map<String, Future<VideoPlayerController>> _pending = {};
  final Map<String, int> _refCounts = {};
  Future<void> _initGate = Future<void>.value();
  bool _isDisposedAll = false;

  /// Giới hạn mặc định 3 bộ giải mã phần cứng (active + next + prev) an toàn cho mọi máy Android.
  VideoControllerCache({this.maxControllers = 3}) {
    _activeCaches.add(this);
  }

  /// Mượn và ghim (pin) một controller cho [VideoItem] đang hiển thị.
  /// Controller đang được ghim (`refCount > 0`) sẽ KHÔNG BAO GIỜ bị dispose ngầm.
  Future<VideoPlayerController> acquire(String path) async {
    final url = StorageImage.videoUrl(path);
    _refCounts[url] = (_refCounts[url] ?? 0) + 1;
    try {
      final ctrl = await _getOrCreateInternal(url, highPriority: true);
      if (_isDisposedAll) {
        await _safeDisposeController(ctrl);
        throw StateError('Cache disposed');
      }
      return ctrl;
    } catch (e) {
      _decrementRef(url);
      rethrow;
    }
  }

  /// Trả lại tham chiếu sau khi [VideoItem] đã gỡ [VideoPlayer] khỏi cây Widget.
  void release(String path) {
    final url = StorageImage.videoUrl(path);
    final ctrl = _cache[url];
    if (ctrl != null && !isControllerDisposed(ctrl)) {
      try {
        ctrl.pause();
      } catch (_) {}
    }
    _decrementRef(url);
    _evictUnreferencedIfNeeded();
  }

  /// Tải trước (preload) an toàn cho video kế tiếp, tự nuốt lỗi nếu mạng chập chờn hoặc huỷ.
  Future<void> preload(String path) async {
    if (_isDisposedAll) return;
    final url = StorageImage.videoUrl(path);
    if (_cache.containsKey(url) || _pending.containsKey(url)) return;

    // Không preload nếu số controller đang ghim đã chạm trần phần cứng
    final pinnedCount =
        _refCounts.values.where((count) => count > 0).length;
    if (pinnedCount >= maxControllers) return;

    try {
      await _getOrCreateInternal(url, highPriority: false);
    } catch (_) {}
  }

  /// Giữ tương thích ngược cho các lời gọi cũ.
  Future<VideoPlayerController> getOrCreate(String path) {
    final url = StorageImage.videoUrl(path);
    return _getOrCreateInternal(url, highPriority: true);
  }

  Future<VideoPlayerController> _getOrCreateInternal(
    String url, {
    required bool highPriority,
  }) async {
    final existing = _cache[url];
    if (existing != null && !isControllerDisposed(existing)) {
      // Làm mới thứ tự LRU
      _cache.remove(url);
      _cache[url] = existing;
      return existing;
    } else if (existing != null) {
      _cache.remove(url);
    }

    if (_pending.containsKey(url)) {
      return _pending[url]!;
    }

    final future = _createSerialized(url, highPriority: highPriority);
    _pending[url] = future;
    return future;
  }

  Future<VideoPlayerController> _createSerialized(
    String url, {
    required bool highPriority,
  }) async {
    // Tuần tự hóa bước khởi tạo MediaCodec để tránh cấp phát đồng thời nhiều decoder 1080p/4K gây crash
    final previousGate = _initGate;
    final gateCompleter = Completer<void>();
    _initGate = gateCompleter.future;

    if (!highPriority) {
      await previousGate.catchError((_) {});
    }

    try {
      await _evictUnreferencedIfNeeded(reserveSlotForNew: true);

      final ctrl = VideoPlayerController.networkUrl(
        Uri.parse(url),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );

      try {
        await ctrl.initialize().timeout(const Duration(seconds: 15));
        await ctrl.setLooping(true);
        _cache[url] = ctrl;
        await _evictUnreferencedIfNeeded();
        return ctrl;
      } catch (e) {
        await _safeDisposeController(ctrl);
        rethrow;
      }
    } finally {
      _pending.remove(url);
      if (!gateCompleter.isCompleted) {
        gateCompleter.complete();
      }
    }
  }

  void _decrementRef(String url) {
    final current = _refCounts[url] ?? 0;
    if (current <= 1) {
      _refCounts.remove(url);
    } else {
      _refCounts[url] = current - 1;
    }
  }

  Future<void> _evictUnreferencedIfNeeded({
    bool reserveSlotForNew = false,
  }) async {
    final limit = reserveSlotForNew ? (maxControllers - 1) : maxControllers;
    if (_cache.length <= limit) return;

    final candidates = <String>[];
    for (final key in _cache.keys) {
      if ((_refCounts[key] ?? 0) <= 0) {
        candidates.add(key);
      }
    }

    for (final key in candidates) {
      if (_cache.length <= limit) break;
      final oldCtrl = _cache.remove(key);
      await _safeDisposeController(oldCtrl);
    }
  }

  /// Giải phóng ngay các controller không còn gắn với [VideoItem] nào (tiết kiệm RAM khi chuyển màn hình).
  Future<void> evictIdle() async {
    final idleKeys = _cache.keys
        .where((key) => (_refCounts[key] ?? 0) <= 0)
        .toList();
    for (final key in idleKeys) {
      final ctrl = _cache.remove(key);
      await _safeDisposeController(ctrl);
    }
  }

  Future<void> _safeDisposeController(VideoPlayerController? ctrl) async {
    if (ctrl == null || isControllerDisposed(ctrl)) return;
    _disposedFlag[ctrl] = true;
    try {
      await ctrl.pause();
    } catch (_) {}
    try {
      await ctrl.dispose();
    } catch (_) {}
  }

  void pauseAll() {
    for (final c in List<VideoPlayerController>.from(_cache.values)) {
      if (!isControllerDisposed(c)) {
        try {
          c.pause();
        } catch (_) {}
      }
    }
  }

  Future<void> disposeAll() async {
    _isDisposedAll = true;
    _activeCaches.remove(this);
    final all = List<VideoPlayerController>.from(_cache.values);
    _cache.clear();
    _pending.clear();
    _refCounts.clear();
    for (final c in all) {
      await _safeDisposeController(c);
    }
  }
}
