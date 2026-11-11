import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../features/comment/presentation/screen/comment_sheet.dart';
import '../../../features/notification/data/models/notification_model.dart';
import '../../../features/notification/domain/entities/notification_entity.dart';
import '../../../features/video/domain/repositories/video_repository.dart';
import '../../../routes/app_router.dart';
import '../../constants/app_colors.dart';
import '../../notifier/auth_notifier.dart';
import '../../utils/video_controller_cache.dart';
import '../supabase/index.dart';
import 'notification_preferences.dart';

class PushBannerPayload {
  final String id;
  final String type;
  final String title;
  final String body;
  final String? avatarUrl;
  final Map<String, dynamic> data;
  final DateTime createdAt;

  const PushBannerPayload({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.avatarUrl,
    this.data = const {},
    required this.createdAt,
  });
}

class PushNotificationService extends ChangeNotifier {
  static const String _channelId = 'shareco_push_high_v1';
  static const String _channelName = 'Thông báo ShareCo';
  static const String _channelDesc =
      'Thông báo bình luận, thả tim, nhắc đến, video mới, livestream và đơn hàng';

  final AuthNotifier _authNotifier;
  final NotificationPreferences preferences;
  final VideoRepository _videoRepository;

  final FlutterLocalNotificationsPlugin _localPlugin =
      FlutterLocalNotificationsPlugin();

  final StreamController<PushBannerPayload> _bannerController =
      StreamController<PushBannerPayload>.broadcast();
  Stream<PushBannerPayload> get bannerStream => _bannerController.stream;

  GoRouter? _router;
  BuildContext? _navigatorContext;
  bool _pluginInitialized = false;
  String? _subscribedUserId;
  String? activeConversationId;

  RealtimeChannel? _notifChannel;
  RealtimeChannel? _msgChannel;
  RealtimeChannel? _liveFallbackChannel;

  final Set<String> _recentDeliveredKeys = <String>{};

  int _unreadTotal = 0;
  int _unreadLikes = 0;
  int _unreadComments = 0;
  int _unreadMentions = 0;
  int _unreadFollowsAndLive = 0;
  int _unreadOrdersAndWallet = 0;

  int get unreadTotal => _unreadTotal;
  int get unreadLikes => _unreadLikes;
  int get unreadComments => _unreadComments;
  int get unreadMentions => _unreadMentions;
  int get unreadFollowsAndLive => _unreadFollowsAndLive;
  int get unreadOrdersAndWallet => _unreadOrdersAndWallet;

  PushNotificationService({
    required AuthNotifier authNotifier,
    required this.preferences,
    required VideoRepository videoRepository,
  }) : _authNotifier = authNotifier,
       _videoRepository = videoRepository;

  void attachRouter(GoRouter router) {
    _router = router;
  }

  void attachContext(BuildContext context) {
    _navigatorContext = context;
  }

  Future<void> init() async {
    await preferences.init();
    await _initLocalNotifications();
    _authNotifier.addListener(_onAuthChanged);
    _onAuthChanged();
  }

  Future<void> _initLocalNotifications() async {
    if (_pluginInitialized || kIsWeb) return;
    try {
      const androidSettings = AndroidInitializationSettings(
        '@mipmap/launcher_icon',
      );
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const linuxSettings = LinuxInitializationSettings(
        defaultActionName: 'Open notification',
      );
      const windowsSettings = WindowsInitializationSettings(
        appName: 'ShareCo',
        appUserModelId: 'com.example.shareco',
        guid: 'd49b0314-ee7a-4626-bf79-97cdb8a991bb',
      );

      await _localPlugin.initialize(
        settings: const InitializationSettings(
          android: androidSettings,
          iOS: iosSettings,
          macOS: iosSettings,
          linux: linuxSettings,
          windows: windowsSettings,
        ),
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          final raw = response.payload;
          if (raw == null || raw.isEmpty) return;
          try {
            final map = jsonDecode(raw) as Map<String, dynamic>;
            unawaited(navigateFromPayload(map));
          } catch (_) {}
        },
      );

      if (!kIsWeb && Platform.isAndroid) {
        final androidImpl = _localPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        await androidImpl?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: _channelDesc,
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
          ),
        );
        unawaited(_requestNotificationPermission());
      }

      _pluginInitialized = true;
    } catch (e) {
      debugPrint('[PushNotificationService] Init error: $e');
    }
  }

  Future<bool> requestPermissionExplicitly() async {
    return _requestNotificationPermission();
  }

  Future<bool> _requestNotificationPermission() async {
    if (kIsWeb) return false;
    try {
      if (Platform.isAndroid) {
        final status = await Permission.notification.status;
        if (status.isGranted) return true;
        final result = await Permission.notification.request();
        return result.isGranted;
      }
      if (Platform.isIOS) {
        final iosImpl = _localPlugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();
        return await iosImpl?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  void _onAuthChanged() {
    final uid = _authNotifier.userId;
    if (uid == _subscribedUserId) return;

    _unsubscribeRealtime();
    _subscribedUserId = uid;

    if (uid == null || uid.isEmpty) {
      _resetCounts();
      return;
    }

    unawaited(refreshUnreadSummary());
    _subscribeRealtimeForUser(uid);
  }

  void _resetCounts() {
    _unreadTotal = 0;
    _unreadLikes = 0;
    _unreadComments = 0;
    _unreadMentions = 0;
    _unreadFollowsAndLive = 0;
    _unreadOrdersAndWallet = 0;
    notifyListeners();
  }

  void _unsubscribeRealtime() {
    final client = SupabaseService.client;
    if (_notifChannel != null) {
      client.removeChannel(_notifChannel!);
      _notifChannel = null;
    }
    if (_msgChannel != null) {
      client.removeChannel(_msgChannel!);
      _msgChannel = null;
    }
    if (_liveFallbackChannel != null) {
      client.removeChannel(_liveFallbackChannel!);
      _liveFallbackChannel = null;
    }
  }

  void _subscribeRealtimeForUser(String uid) {
    final client = SupabaseService.client;

    // 1. Kênh Realtime bảng notifications của chính người dùng
    final nCh = client.channel('push_notifs_$uid');
    _notifChannel = nCh;
    nCh
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: uid,
          ),
          callback: (payload) {
            final record = payload.newRecord;
            if (record.isEmpty) return;
            _handleIncomingNotificationRecord(record);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: uid,
          ),
          callback: (_) => unawaited(refreshUnreadSummary()),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: uid,
          ),
          callback: (_) => unawaited(refreshUnreadSummary()),
        )
        .subscribe();

    // 2. Kênh Realtime tin nhắn mới (báo đẩy khi đang không mở phòng chat đó)
    final mCh = client.channel('push_msgs_$uid');
    _msgChannel = mCh;
    mCh
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: (payload) {
            final record = payload.newRecord;
            if (record.isEmpty) return;
            unawaited(_handleIncomingChatMessage(record, uid));
          },
        )
        .subscribe();

    // 3. Kênh dự phòng khi người đang follow bắt đầu Livestream
    // (Hoạt động ngay cả khi chưa kịp chạy trigger SQL mới)
    final lCh = client.channel('push_live_watch_$uid');
    _liveFallbackChannel = lCh;
    lCh
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'livestreams',
          callback: (payload) {
            final record = payload.newRecord;
            if (record.isEmpty) return;
            unawaited(_handleLivestreamStartedFallback(record, uid));
          },
        )
        .subscribe();
  }

  void _handleIncomingNotificationRecord(Map<String, dynamic> record) {
    try {
      final model = NotificationModel.fromJson(record);
      final dedupeKey =
          (model.data?['dedupe_key'] as String?) ?? 'notif_${model.id}';
      if (!_markDeliveredOnce(dedupeKey)) {
        unawaited(refreshUnreadSummary());
        return;
      }

      unawaited(refreshUnreadSummary());

      if (!preferences.shouldShowPushForType(model.type)) return;

      final title = (model.title?.trim().isNotEmpty == true)
          ? model.title!.trim()
          : defaultTitleForType(model.type);
      final body = (model.body?.trim().isNotEmpty == true)
          ? model.body!.trim()
          : 'Nhấn để xem chi tiết trên ShareCo';

      final avatarUrl = model.data?['actor_avatar'] as String?;
      final mergedData = <String, dynamic>{
        ...?model.data,
        'notification_id': model.id,
        'type': model.type,
      };

      _deliverLocalAndInAppPush(
        id: model.id,
        type: model.type,
        title: title,
        body: body,
        avatarUrl: avatarUrl,
        data: mergedData,
      );
    } catch (e) {
      debugPrint('[PushNotificationService] Parse record error: $e');
    }
  }

  Future<void> _handleIncomingChatMessage(
    Map<String, dynamic> record,
    String currentUid,
  ) async {
    try {
      final senderId = record['sender_id'] as String?;
      final conversationId = record['conversation_id'] as String?;
      final isDeleted = (record['is_deleted'] as bool?) ?? false;
      if (senderId == null ||
          conversationId == null ||
          senderId == currentUid ||
          isDeleted) {
        return;
      }

      if (activeConversationId == conversationId) return;
      if (!preferences.shouldShowPushForType('message')) return;

      // Kiểm tra user hiện tại có trong cuộc trò chuyện & có tắt thông báo không
      final part = await SupabaseService.from('conversation_participants')
          .select('is_muted')
          .eq('conversation_id', conversationId)
          .eq('user_id', currentUid)
          .maybeSingle();

      if (part == null) return;
      if ((part['is_muted'] as bool?) == true) return;

      final msgId = (record['id'] as String?) ?? conversationId;
      if (!_markDeliveredOnce('msg_$msgId')) return;

      final senderProfile = await SupabaseService.from('profiles')
          .select('username, display_name, avatar_url')
          .eq('id', senderId)
          .maybeSingle();

      final senderName =
          (senderProfile?['display_name'] as String?)?.trim().isNotEmpty == true
          ? senderProfile!['display_name'] as String
          : '@${senderProfile?['username'] ?? 'Người dùng'}';

      final msgType = (record['type'] as String?) ?? 'text';
      final rawContent = (record['content'] as String?)?.trim() ?? '';
      final preview = switch (msgType) {
        'image' => '📷 Đã gửi một hình ảnh',
        'video' => '🎬 Đã gửi một video',
        'sticker' => '😊 Đã gửi một nhãn dán',
        'gift' => '🎁 Đã gửi một món quà',
        _ => rawContent.isNotEmpty ? rawContent : 'Tin nhắn mới',
      };

      _deliverLocalAndInAppPush(
        id: msgId,
        type: 'message',
        title: '💬 $senderName',
        body: preview,
        avatarUrl: senderProfile?['avatar_url'] as String?,
        data: {
          'type': 'message',
          'conversation_id': conversationId,
          'actor_id': senderId,
        },
      );
    } catch (_) {}
  }

  Future<void> _handleLivestreamStartedFallback(
    Map<String, dynamic> record,
    String currentUid,
  ) async {
    try {
      final hostId = record['host_id'] as String?;
      final status = record['status'] as String?;
      final liveId = record['id'] as String?;
      if (hostId == null ||
          liveId == null ||
          hostId == currentUid ||
          status != 'live') {
        return;
      }

      // Chờ ngắn để ưu tiên thông báo từ Trigger DB (nếu đã cài đặt SQL)
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      final dedupeKey = 'live_${liveId}_$currentUid';
      if (_recentDeliveredKeys.contains(dedupeKey)) return;

      final followRow = await SupabaseService.from('user_follows')
          .select('following_id')
          .eq('follower_id', currentUid)
          .eq('following_id', hostId)
          .maybeSingle();
      if (followRow == null) return;

      if (!_markDeliveredOnce(dedupeKey)) return;
      if (!preferences.shouldShowPushForType('livestream')) return;

      final host = await SupabaseService.from('profiles')
          .select('username, display_name, avatar_url')
          .eq('id', hostId)
          .maybeSingle();

      final hostName =
          (host?['display_name'] as String?)?.trim().isNotEmpty == true
          ? host!['display_name'] as String
          : '@${host?['username'] ?? 'Creator'}';

      final title = '🔴 $hostName đang phát trực tiếp!';
      final body = (record['title'] as String?)?.trim().isNotEmpty == true
          ? record['title'] as String
          : 'Vào xem phiên Live ngay!';

      _deliverLocalAndInAppPush(
        id: liveId,
        type: 'livestream',
        title: title,
        body: body,
        avatarUrl: host?['avatar_url'] as String?,
        data: {
          'type': 'livestream',
          'livestream_id': liveId,
          'channel_name': record['channel_name'] ?? '',
          'host_id': hostId,
          'actor_id': hostId,
        },
      );
    } catch (_) {}
  }

  bool _markDeliveredOnce(String key) {
    if (_recentDeliveredKeys.contains(key)) return false;
    _recentDeliveredKeys.add(key);
    if (_recentDeliveredKeys.length > 300) {
      _recentDeliveredKeys.remove(_recentDeliveredKeys.first);
    }
    return true;
  }

  void _deliverLocalAndInAppPush({
    required String id,
    required String type,
    required String title,
    required String body,
    String? avatarUrl,
    required Map<String, dynamic> data,
  }) {
    _bannerController.add(
      PushBannerPayload(
        id: id,
        type: type,
        title: title,
        body: body,
        avatarUrl: avatarUrl,
        data: data,
        createdAt: DateTime.now(),
      ),
    );

    if (!_pluginInitialized || kIsWeb) return;
    final notifId = id.hashCode & 0x7fffffff;
    final payloadJson = jsonEncode(data);

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.max,
        priority: Priority.high,
        color: AppColors.primary,
        playSound: true,
        enableVibration: true,
        styleInformation: BigTextStyleInformation(body, contentTitle: title),
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    unawaited(
      _localPlugin
          .show(
            id: notifId,
            title: title,
            body: body,
            notificationDetails: details,
            payload: payloadJson,
          )
          .catchError((Object e) {
            debugPrint('[PushNotificationService] OS show error: $e');
          }),
    );
  }

  /// Làm mới tổng số thông báo chưa đọc & số lượng theo từng phân loại
  Future<void> refreshUnreadSummary() async {
    final uid = SupabaseService.currentUserId;
    if (uid == null) {
      _resetCounts();
      return;
    }

    try {
      final rows = await SupabaseService.from('notifications')
          .select('type')
          .eq('user_id', uid)
          .eq('is_read', false) as List;

      int likes = 0;
      int comments = 0;
      int mentions = 0;
      int followsLive = 0;
      int ordersWallet = 0;

      for (final raw in rows) {
        final t = (raw as Map<String, dynamic>)['type'] as String? ?? '';
        switch (t) {
          case 'like':
          case 'video_like':
          case 'comment_like':
            likes++;
            break;
          case 'comment':
          case 'comment_reply':
            comments++;
            break;
          case 'mention':
            mentions++;
            break;
          case 'follow':
          case 'new_video':
          case 'livestream':
          case 'gift':
            followsLive++;
            break;
          case 'order':
          case 'new_order':
          case 'order_status':
          case 'wallet':
          case 'system':
            ordersWallet++;
            break;
          default:
            ordersWallet++;
        }
      }

      _unreadTotal = rows.length;
      _unreadLikes = likes;
      _unreadComments = comments;
      _unreadMentions = mentions;
      _unreadFollowsAndLive = followsLive;
      _unreadOrdersAndWallet = ordersWallet;
      notifyListeners();
    } catch (_) {}
  }

  /// Gửi thông báo thử nghiệm để kiểm tra ngay thông báo đẩy OS & In-App Banner
  Future<void> sendTestPushNotification() async {
    await _requestNotificationPermission();
    final uid = SupabaseService.currentUserId;

    if (uid != null) {
      try {
        await SupabaseService.from('notifications').insert({
          'user_id': uid,
          'type': 'system',
          'title': '🔔 Thông báo đẩy ShareCo đã hoạt động!',
          'body':
              'Bạn sẽ nhận ngay thông báo về bình luận, thả tim, @nhắc tên, video mới và Livestream.',
          'data': {
            'type': 'system',
            'dedupe_key': 'test_${DateTime.now().millisecondsSinceEpoch}',
          },
        });
        await Future<void>.delayed(const Duration(milliseconds: 600));
        if (_recentDeliveredKeys.any((k) => k.startsWith('test_'))) {
          return;
        }
      } catch (_) {}
    }

    _deliverLocalAndInAppPush(
      id: 'test_${DateTime.now().millisecondsSinceEpoch}',
      type: 'system',
      title: '🔔 Thông báo đẩy ShareCo đã hoạt động!',
      body:
          'Bạn sẽ nhận ngay thông báo về bình luận, thả tim, @nhắc tên, video mới và Livestream.',
      data: const {'type': 'system'},
    );
  }

  /// Điều hướng thông minh khi người dùng nhấn vào thông báo đẩy hoặc mục trong Trung tâm thông báo
  Future<void> openNotificationEntity(NotificationEntity item) async {
    if (!item.isRead) {
      try {
        await SupabaseService.from('notifications')
            .update({'is_read': true})
            .eq('id', item.id);
        unawaited(refreshUnreadSummary());
      } catch (_) {}
    }

    await navigateFromPayload({
      ...?item.data,
      'type': item.type,
      'notification_id': item.id,
    });
  }

  Future<void> navigateFromPayload(Map<String, dynamic> payload) async {
    final router = _router;
    if (router == null) return;

    final notifId = payload['notification_id'] as String?;
    if (notifId != null && notifId.isNotEmpty) {
      unawaited(
        SupabaseService.from('notifications')
            .update({'is_read': true})
            .eq('id', notifId)
            .then((_) => refreshUnreadSummary())
            .catchError((_) {}),
      );
    }

    final type = (payload['type'] as String?) ?? '';
    final videoId = payload['video_id'] as String?;
    final commentId = payload['comment_id'] as String?;
    final actorId = payload['actor_id'] as String?;
    final orderId = payload['order_id'] as String?;
    final livestreamId = payload['livestream_id'] as String?;
    final channelName = payload['channel_name'] as String?;

    try {
      switch (type) {
        case 'video_like':
        case 'like':
        case 'comment':
        case 'comment_reply':
        case 'comment_like':
        case 'mention':
        case 'new_video':
          if (videoId != null && videoId.isNotEmpty) {
            final res = await _videoRepository.getVideoById(videoId);
            await res.fold(
              (_) async {
                if (actorId != null && actorId.isNotEmpty) {
                  router.push(Routes.profileOf(actorId));
                }
              },
              (video) async {
                VideoControllerCache.pauseAllGlobal();
                router.push(
                  Routes.searchFeedViewer,
                  extra: {
                    'videos': [video],
                    'initialIndex': 0,
                  },
                );
                if (commentId != null &&
                    (type == 'comment' ||
                        type == 'comment_reply' ||
                        type == 'comment_like')) {
                  await Future<void>.delayed(
                    const Duration(milliseconds: 450),
                  );
                  final ctx = _navigatorContext;
                  if (ctx != null && ctx.mounted) {
                    CommentSheet.show(ctx, videoId: video.id);
                  }
                }
              },
            );
            return;
          }
          if (actorId != null && actorId.isNotEmpty) {
            router.push(Routes.profileOf(actorId));
          }
          return;

        case 'livestream':
          if (livestreamId != null && livestreamId.isNotEmpty) {
            final row = await SupabaseService.from('livestreams')
                .select('id, channel_name, status, host_id')
                .eq('id', livestreamId)
                .maybeSingle();
            if (row != null && row['status'] == 'live') {
              VideoControllerCache.pauseAllGlobal();
              router.push(
                Routes.livestream,
                extra: {
                  'channelName': (row['channel_name'] as String?) ??
                      (channelName ?? ''),
                  'isHost': row['host_id'] == SupabaseService.currentUserId,
                  'livestreamId': livestreamId,
                },
              );
              return;
            }
          }
          if (actorId != null && actorId.isNotEmpty) {
            router.push(Routes.profileOf(actorId));
          }
          return;

        case 'gift':
        case 'wallet':
          router.push(Routes.wallet);
          return;

        case 'follow':
          if (actorId != null && actorId.isNotEmpty) {
            router.push(Routes.profileOf(actorId));
          }
          return;

        case 'order':
        case 'new_order':
        case 'order_status':
          if (orderId != null && orderId.isNotEmpty) {
            router.push('/orders/$orderId');
          } else {
            router.push(Routes.orders);
          }
          return;

        case 'message':
          router.go(Routes.chat);
          return;

        default:
          if (actorId != null && actorId.isNotEmpty) {
            router.push(Routes.profileOf(actorId));
          }
      }
    } catch (e) {
      debugPrint('[PushNotificationService] Navigate error: $e');
    }
  }

  static String defaultTitleForType(String type) {
    switch (type) {
      case 'comment':
        return 'Bình luận mới về video';
      case 'comment_reply':
        return 'Phản hồi bình luận mới';
      case 'comment_like':
        return 'Lượt thích bình luận';
      case 'video_like':
      case 'like':
        return 'Lượt thích video mới';
      case 'mention':
        return 'Bạn được nhắc đến';
      case 'new_video':
        return 'Video mới từ người bạn theo dõi';
      case 'livestream':
        return 'Đang phát trực tiếp!';
      case 'follow':
        return 'Người theo dõi mới';
      case 'gift':
        return 'Quà tặng Livestream mới';
      case 'order':
      case 'new_order':
      case 'order_status':
        return 'Cập nhật đơn hàng';
      case 'wallet':
        return 'Cập nhật Ví Xu';
      case 'message':
        return 'Tin nhắn mới';
      default:
        return 'Thông báo ShareCo';
    }
  }

  @override
  void dispose() {
    _authNotifier.removeListener(_onAuthChanged);
    _unsubscribeRealtime();
    _bannerController.close();
    super.dispose();
  }
}
