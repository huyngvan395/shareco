import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/video/data/models/video_model.dart';
import '../../features/video/domain/entities/video_entity.dart';
import '../notifier/auth_notifier.dart';
import 'supabase/index.dart';

class SavedVideosService extends ChangeNotifier {
  final AuthNotifier _authNotifier;
  Set<String> _savedIds = <String>{};
  String? _loadedForUserId;

  SavedVideosService({required AuthNotifier authNotifier})
    : _authNotifier = authNotifier {
    _authNotifier.addListener(_onAuthChanged);
    _onAuthChanged();
  }

  Set<String> get savedIds => _savedIds;

  bool isSaved(String videoId) => _savedIds.contains(videoId);

  String _prefsKey(String uid) => 'saved_video_ids_$uid';

  Future<void> _onAuthChanged() async {
    final uid = _authNotifier.userId;
    if (uid == _loadedForUserId) return;
    _loadedForUserId = uid;
    if (uid == null || uid.isEmpty) {
      _savedIds = <String>{};
      notifyListeners();
      return;
    }
    await reload();
  }

  Future<void> reload() async {
    final uid = SupabaseService.currentUserId;
    if (uid == null) {
      _savedIds = <String>{};
      notifyListeners();
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final local = prefs.getStringList(_prefsKey(uid)) ?? const <String>[];
    final merged = <String>{...local};

    try {
      final rows = await SupabaseService.from('saved_videos')
          .select('video_id')
          .eq('user_id', uid)
          .order('created_at', ascending: false) as List;
      for (final r in rows) {
        final vid = (r as Map<String, dynamic>)['video_id'] as String?;
        if (vid != null && vid.isNotEmpty) merged.add(vid);
      }
      await prefs.setStringList(_prefsKey(uid), merged.toList());
    } catch (_) {
      // Bảng saved_videos có thể chưa được chạy migration — vẫn giữ local cache mượt mà
    }

    _savedIds = merged;
    notifyListeners();
  }

  Future<bool> toggleSave(String videoId) async {
    final uid = SupabaseService.currentUserId;
    if (uid == null) return false;

    final nextSaved = !_savedIds.contains(videoId);
    if (nextSaved) {
      _savedIds = {..._savedIds, videoId};
    } else {
      _savedIds = {..._savedIds}..remove(videoId);
    }
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey(uid), _savedIds.toList());

    try {
      await SupabaseService.rpc(
        'toggle_saved_video',
        params: {'p_video_id': videoId},
      );
    } catch (_) {
      try {
        if (nextSaved) {
          await SupabaseService.from('saved_videos').upsert({
            'user_id': uid,
            'video_id': videoId,
          });
        } else {
          await SupabaseService.from('saved_videos')
              .delete()
              .eq('user_id', uid)
              .eq('video_id', videoId);
        }
      } catch (_) {}
    }

    return nextSaved;
  }

  Future<List<VideoEntity>> fetchSavedVideos() async {
    final uid = SupabaseService.currentUserId;
    if (uid == null) return const [];

    await reload();
    if (_savedIds.isEmpty) return const [];

    try {
      final ids = _savedIds.toList();
      final rows = await SupabaseService.from('videos')
          .select('''
            *,
            profiles:author_id (
              id, username, display_name, avatar_url, is_verified,
              follower_count, following_count, like_received_count
            )
          ''')
          .inFilter('id', ids) as List;

      final likedRes = await SupabaseService.from('video_likes')
          .select('video_id')
          .eq('user_id', uid)
          .inFilter('video_id', ids) as List;
      final likedSet = {
        for (final r in likedRes)
          (r as Map<String, dynamic>)['video_id'] as String,
      };

      final byId = {
        for (final r in rows) (r as Map<String, dynamic>)['id'] as String: r,
      };

      return [
        for (final id in ids)
          if (byId.containsKey(id))
            VideoModel.fromJson(byId[id]!, isLiked: likedSet.contains(id)),
      ];
    } catch (_) {
      return const [];
    }
  }

  @override
  void dispose() {
    _authNotifier.removeListener(_onAuthChanged);
    super.dispose();
  }
}

