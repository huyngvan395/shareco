// features/video/presentation/screen/livestream_screen.dart

import 'dart:async';
import 'dart:math' as math;
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/livestrem/agora_service.dart';
import '../../../../core/services/supabase/index.dart';
import '../../../../core/utils/storage_image.dart';
import '../../../../core/utils/video_controller_cache.dart';
import '../../../../di/injector.dart';
import '../../../ecommerce/cart/domain/usecases/add_to_cart_usecase.dart';
import '../../../ecommerce/cart/presentation/screen/cart_screen.dart';
import '../../../ecommerce/checkout/domain/entities/direct_order_args.dart';
import '../../../ecommerce/checkout/presentation/screen/checkout_screen.dart';
import '../../../ecommerce/product/domain/entities/product.dart';
import '../../../ecommerce/product/domain/usecases/get_products_usecase.dart';
import '../../../wallet/data/datasources/wallet_remote_datasource.dart';
import '../../../wallet/presentation/screen/wallet_screen.dart';
import '../../data/datasources/livestream_remote_datasource.dart';
import '../bloc/livestream_bloc.dart';
import '../bloc/livestream_event.dart';
import '../bloc/livestream_state.dart';

/// Mở danh sách các phòng Livestream đang phát hoặc tạo phòng Live mới
Future<void> showLiveDiscoverySheet(BuildContext context) async {
  VideoControllerCache.pauseAllGlobal();
  await showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: AppColors.surfaceSheet,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const _LiveDiscoverySheet(),
  );
}

typedef LiveStreamScreen = LivestreamScreen;

class LivestreamScreen extends StatefulWidget {
  final String channelName;
  final bool isHost;
  final String? livestreamId;
  final LivestreamRoomInfo? initialRoom;

  const LivestreamScreen({
    super.key,
    this.channelName = '',
    this.isHost = true,
    this.livestreamId,
    this.initialRoom,
  });

  @override
  State<LivestreamScreen> createState() => _LivestreamScreenState();
}

class _LivestreamScreenState extends State<LivestreamScreen> {
  late final String _effectiveChannelName;
  late final int _localUid;

  @override
  void initState() {
    super.initState();
    // Dừng toàn bộ video Feed đang phát ngay khi mở màn hình Livestream
    VideoControllerCache.pauseAllGlobal();

    final rawChannel = widget.initialRoom?.channelName.trim().isNotEmpty == true
        ? widget.initialRoom!.channelName.trim()
        : widget.channelName.trim();

    if (rawChannel.isEmpty || (widget.isHost && rawChannel == 'shareco_live')) {
      _effectiveChannelName = 'live_${DateTime.now().millisecondsSinceEpoch}';
    } else {
      _effectiveChannelName = rawChannel;
    }

    // UID luôn nằm trong khoảng 10000..909999 (khác 0 để khớp chuẩn Agora Token)
    _localUid = (DateTime.now().millisecondsSinceEpoch % 900000) + 10000;
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => LivestreamBloc()
        ..add(
          LivestreamInitialize(
            channelName: _effectiveChannelName,
            token: '',
            uid: _localUid,
            isBroadcaster: widget.isHost,
          ),
        ),
      child: _LivestreamView(
        channelName: _effectiveChannelName,
        localUid: _localUid,
        isHost: widget.isHost,
        initialLivestreamId: widget.livestreamId,
        initialRoom: widget.initialRoom,
      ),
    );
  }
}

class _LivestreamView extends StatefulWidget {
  final String channelName;
  final int localUid;
  final bool isHost;
  final String? initialLivestreamId;
  final LivestreamRoomInfo? initialRoom;

  const _LivestreamView({
    required this.channelName,
    required this.localUid,
    required this.isHost,
    this.initialLivestreamId,
    this.initialRoom,
  });

  @override
  State<_LivestreamView> createState() => _LivestreamViewState();
}

class _LivestreamViewState extends State<_LivestreamView> {
  final _liveDs = LivestreamRemoteDataSource.instance;
  final _walletDs = WalletRemoteDataSource.instance;
  final _titleCtrl = TextEditingController(
    text: 'Săn sale giá sốc trên Live hôm nay 🔥',
  );
  final _commentCtrl = TextEditingController();
  final _commentFocusNode = FocusNode();
  final _chatScrollCtrl = ScrollController();
  final _currencyFmt = NumberFormat('#,###', 'vi_VN');
  final _rng = math.Random();

  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  int _selectedCameraIdx = 0;
  final bool _isCameraOff = false;

  LivestreamRoomInfo? _room;
  List<Product> _allCatalogProducts = [];
  List<Product> _attachedProducts = [];
  String? _pinnedProductId;
  List<LivestreamCommentItem> _comments = [];
  List<GiftCatalogItem> _giftCatalog = GiftCatalogItem.defaultGifts;
  WalletSummary _wallet = const WalletSummary(
    coinBalance: 0,
    earningsBalance: 0,
  );

  bool _isStartingLive = false;
  bool _hideErrorBanner = false;
  int _likeCount = 0;
  int _viewerCount = 0; // Chủ phòng KHÔNG được tính vào số người xem
  int _totalGiftCoins = 0;

  // Realtime Presence & Broadcast
  RealtimeChannel? _realtimeChannel;
  String? _subscribedRoomId;
  bool _presenceSynced = false;
  int _lastPersistedViewerCount = -1;
  bool _hasJoinedAsViewer = false;
  bool _hasLeftAsViewer = false;
  bool _hasSentJoinAnnouncement = false;
  bool _isEndingOrLeaving = false;
  bool _isStreamEndedForViewer = false;
  bool _sawHostPresence = false;

  // Banners & Floating Hearts
  LivestreamCommentItem? _activeGiftBanner;
  LivestreamCommentItem? _activeActivityBanner;
  Timer? _giftBannerTimer;
  Timer? _activityBannerTimer;
  Timer? _syncTimer;
  DateTime? _lastLikeAnnouncementAt;

  bool _initialCommentsLoaded = false;
  final Set<String> _seenCommentIds = {};
  final Set<String> _seenGiftCommentIds = {};
  final List<_FloatingHeartSpec> _floatingHearts = [];

  String get _sessionKey =>
      '${SupabaseService.currentUserId ?? 'guest'}_${widget.localUid}';

  @override
  void initState() {
    super.initState();
    VideoControllerCache.pauseAllGlobal();

    _room = widget.initialRoom;
    _pinnedProductId = widget.initialRoom?.pinnedProductId;
    // Chủ phòng bắt đầu từ 0 người xem; Viewer lấy số người xem thực tế từ phòng
    _viewerCount = widget.isHost ? 0 : (widget.initialRoom?.viewerCount ?? 0);
    _likeCount = widget.initialRoom?.likeCount ?? 0;
    _totalGiftCoins = widget.initialRoom?.totalGiftCoins ?? 0;

    // QUAN TRỌNG: Chỉ khởi tạo CameraController cục bộ khi CHƯA cấu hình AGORA_APP_ID.
    // Nếu đã có AGORA_APP_ID, tuyệt đối để Agora RtcEngine giữ độc quyền Camera.
    if (widget.isHost && !AgoraService().hasValidAppId) {
      _initLocalCameraFallback();
    }

    _loadInitialResources();

    final initialStreamId = widget.initialLivestreamId ?? _room?.id;
    if (!widget.isHost && initialStreamId != null) {
      _enterRoomAsViewer(initialStreamId);
    }
  }

  @override
  void dispose() {
    _giftBannerTimer?.cancel();
    _activityBannerTimer?.cancel();
    _syncTimer?.cancel();
    _disposeRealtimeAndSession();
    _cameraController?.dispose();
    _titleCtrl.dispose();
    _commentCtrl.dispose();
    _commentFocusNode.dispose();
    _chatScrollCtrl.dispose();
    super.dispose();
  }

  void _disposeRealtimeAndSession() {
    final ch = _realtimeChannel;
    _realtimeChannel = null;
    if (ch != null) {
      if (widget.isHost) {
        ch
            .httpSend(
              event: 'room_signal',
              payload: {
                'kind': 'stream_ended',
                'sender': _sessionKey,
              },
            )
            .catchError((_) {});
      }
      ch.untrack();
      SupabaseService.client.removeChannel(ch);
    }

    final roomId = _room?.id ?? widget.initialLivestreamId;
    if (roomId != null) {
      if (widget.isHost) {
        _liveDs.endLivestream(roomId);
      } else if (_hasJoinedAsViewer && !_hasLeftAsViewer) {
        _hasLeftAsViewer = true;
        _liveDs.leaveLivestream(roomId, hostId: _room?.hostId);
      }
    }
  }

  Future<void> _connectRoomRealtime(String livestreamId) async {
    if (livestreamId.startsWith('local-')) return;
    if (_subscribedRoomId == livestreamId && _realtimeChannel != null) return;

    if (_realtimeChannel != null) {
      final old = _realtimeChannel!;
      _realtimeChannel = null;
      await old.untrack();
      await SupabaseService.client.removeChannel(old);
    }

    _subscribedRoomId = livestreamId;
    final me = await _liveDs.getCurrentUserMiniProfile();
    if (!mounted) return;

    final channel = SupabaseService.client.channel('live_room_$livestreamId');
    _realtimeChannel = channel;

    channel
        .onPresenceSync((_) => _recomputePresenceViewers())
        .onPresenceJoin((_) => _recomputePresenceViewers())
        .onPresenceLeave((_) => _recomputePresenceViewers())
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'livestreams',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: livestreamId,
          ),
          callback: (payload) {
            if (!mounted || widget.isHost) return;
            final status = payload.newRecord['status']?.toString();
            if (status == 'ended') {
              _triggerStreamEndedOnViewer();
            }
          },
        )
        .onBroadcast(
          event: 'room_signal',
          callback: (payload) {
            if (!mounted) return;
            final kind = payload['kind']?.toString() ?? '';
            final senderSession = payload['sender']?.toString() ?? '';
            if (senderSession == _sessionKey) return;

            if (kind == 'stream_ended') {
              if (!widget.isHost) {
                _triggerStreamEndedOnViewer();
              }
            } else if (kind == 'like_tap') {
              setState(() => _likeCount += 1);
              _spawnFloatingHeart();
            } else if (kind == 'refresh') {
              _syncLiveRoomData(livestreamId);
            }
          },
        )
        .subscribe((status, [error]) async {
          if (status == RealtimeSubscribeStatus.subscribed && mounted) {
            await channel.track({
              'user_id': me.userId,
              'session_key': _sessionKey,
              'display_name': me.displayName,
              'role': widget.isHost ? 'host' : 'viewer',
              'joined_at': DateTime.now().toIso8601String(),
            });
          }
        });
  }

  void _recomputePresenceViewers() {
    final ch = _realtimeChannel;
    if (ch == null || !mounted) return;

    final states = ch.presenceState();
    final hostId = _room?.hostId ?? '';
    final viewerKeys = <String>{};
    bool hostPresentNow = false;

    for (final state in states) {
      for (final p in state.presences) {
        final role = p.payload['role']?.toString() ?? '';
        final uid = p.payload['user_id']?.toString() ?? '';
        final sKey = p.payload['session_key']?.toString() ?? state.key;

        if (role == 'host' || (hostId.isNotEmpty && uid == hostId)) {
          hostPresentNow = true;
        }

        // Tuyệt đối không tính Host vào số người xem
        if (role == 'viewer' && (hostId.isEmpty || uid != hostId)) {
          viewerKeys.add(uid.isNotEmpty ? uid : sKey);
        }
      }
    }

    if (hostPresentNow) {
      _sawHostPresence = true;
    } else if (!widget.isHost && _sawHostPresence && !_isStreamEndedForViewer) {
      _verifyIfStreamEnded();
    }

    final exactCount = viewerKeys.length;
    setState(() {
      _presenceSynced = true;
      _viewerCount = exactCount;
    });

    // Host đồng bộ số người xem thực tế lên bảng livestreams để danh sách phòng bên ngoài hiển thị chuẩn xác
    if (widget.isHost &&
        _room != null &&
        _lastPersistedViewerCount != exactCount) {
      _lastPersistedViewerCount = exactCount;
      _liveDs.updateViewerCount(_room!.id, exactCount);
    }
  }

  void _broadcastRoomSignal(String kind) {
    final ch = _realtimeChannel;
    if (ch == null) return;
    ch
        .httpSend(
          event: 'room_signal',
          payload: {
            'kind': kind,
            'sender': _sessionKey,
          },
        )
        .catchError((_) {});
  }

  Future<void> _broadcastRoomSignalAsync(String kind) async {
    final ch = _realtimeChannel;
    if (ch == null) return;
    try {
      await ch.httpSend(
        event: 'room_signal',
        payload: {
          'kind': kind,
          'sender': _sessionKey,
        },
      );
    } catch (_) {}
  }

  Future<void> _verifyIfStreamEnded() async {
    if (widget.isHost || _isStreamEndedForViewer || !mounted) return;
    final roomId = _room?.id ?? widget.initialLivestreamId;
    if (roomId == null) return;

    await Future.delayed(const Duration(milliseconds: 350));
    if (!mounted || _isStreamEndedForViewer) return;

    final latest = await _liveDs.getLivestreamRoom(roomId);
    if (!mounted || _isStreamEndedForViewer) return;
    if (latest == null || latest.status == 'ended') {
      _triggerStreamEndedOnViewer(updatedRoom: latest);
    }
  }

  Future<void> _triggerStreamEndedOnViewer({
    LivestreamRoomInfo? updatedRoom,
  }) async {
    if (widget.isHost || _isStreamEndedForViewer || !mounted) return;

    _syncTimer?.cancel();
    _giftBannerTimer?.cancel();
    _activityBannerTimer?.cancel();
    FocusManager.instance.primaryFocus?.unfocus();

    setState(() {
      _isStreamEndedForViewer = true;
      _activeGiftBanner = null;
      _activeActivityBanner = null;
      _viewerCount = 0;
      if (updatedRoom != null) {
        _room = updatedRoom;
        if (updatedRoom.likeCount > _likeCount) {
          _likeCount = updatedRoom.likeCount;
        }
        _totalGiftCoins = updatedRoom.totalGiftCoins;
      }
    });

    context.read<LivestreamBloc>().add(LivestreamStop());

    final ch = _realtimeChannel;
    _realtimeChannel = null;
    if (ch != null) {
      try {
        await ch.untrack();
        await SupabaseService.client.removeChannel(ch);
      } catch (_) {}
    }

    final roomId = _room?.id ?? widget.initialLivestreamId;
    if (roomId != null && _hasJoinedAsViewer && !_hasLeftAsViewer) {
      _hasLeftAsViewer = true;
      await _liveDs.leaveLivestream(roomId, hostId: _room?.hostId);
    }
  }

  Future<void> _initLocalCameraFallback() async {
    if (!widget.isHost) return;
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) return;
      final frontIdx = _cameras.indexWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
      );
      _selectedCameraIdx = frontIdx != -1 ? frontIdx : 0;
      await _setupCameraController(_cameras[_selectedCameraIdx]);
    } catch (_) {}
  }

  Future<void> _setupCameraController(CameraDescription description) async {
    final prev = _cameraController;
    final ctrl = CameraController(
      description,
      ResolutionPreset.high,
      enableAudio: false,
    );
    _cameraController = ctrl;
    if (prev != null) {
      await prev.dispose();
    }
    try {
      await ctrl.initialize();
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _switchCamera() async {
    context.read<LivestreamBloc>().add(LivestreamSwitchCamera());
    if (_cameraController == null || _cameras.length < 2) return;
    _selectedCameraIdx = (_selectedCameraIdx + 1) % _cameras.length;
    await _setupCameraController(_cameras[_selectedCameraIdx]);
  }

  Future<void> _loadInitialResources() async {
    try {
      final walletFuture = _walletDs.getWalletSummary();
      final giftsFuture = _walletDs.getGiftCatalog();
      final productsResult = await sl<GetProductsUseCase>()(limit: 50);
      final wallet = await walletFuture;
      final gifts = await giftsFuture;

      final catalog = productsResult.fold(
        (_) => <Product>[],
        (items) => items,
      );

      if (!mounted) return;
      setState(() {
        _wallet = wallet;
        _giftCatalog = gifts;
        _allCatalogProducts = catalog;
      });

      final streamId = widget.initialLivestreamId ?? _room?.id;
      if (streamId != null) {
        if (!widget.isHost) {
          await _enterRoomAsViewer(streamId);
        } else {
          await _connectRoomRealtime(streamId);
          await _syncLiveRoomData(streamId);
          _startPeriodicSync(streamId);
        }
      }
    } catch (_) {}
  }

  Future<void> _enterRoomAsViewer(String livestreamId) async {
    if (!_hasJoinedAsViewer) {
      _hasJoinedAsViewer = true;
      await _liveDs.joinLivestream(livestreamId, hostId: _room?.hostId);
    }

    await _connectRoomRealtime(livestreamId);
    await _syncLiveRoomData(livestreamId);
    _startPeriodicSync(livestreamId);

    // Gửi dòng thông báo người xem vừa vào phòng Live (1 lần mỗi phiên vào phòng)
    if (!_hasSentJoinAnnouncement && mounted) {
      _hasSentJoinAnnouncement = true;
      final currentUid = SupabaseService.currentUserId;
      if (currentUid == null || currentUid != _room?.hostId) {
        final joinedItem = await _liveDs.sendRoomActivity(
          livestreamId: livestreamId,
          tag: 'JOIN',
          message: 'đã tham gia phòng Live',
        );
        if (joinedItem != null && mounted) {
          _seenCommentIds.add(joinedItem.id);
          setState(() {
            if (!_comments.any((c) => c.id == joinedItem.id)) {
              _comments = [..._comments, joinedItem];
            }
          });
          _showActivityBanner(joinedItem);
          _scrollToLatestComment();
          _broadcastRoomSignal('refresh');
        }
      }
    }
  }

  Future<void> _handleViewerExit() async {
    if (_isEndingOrLeaving) return;
    _isEndingOrLeaving = true;

    final ch = _realtimeChannel;
    _realtimeChannel = null;
    if (ch != null) {
      try {
        await ch.untrack();
        await SupabaseService.client.removeChannel(ch);
      } catch (_) {}
    }

    final roomId = _room?.id ?? widget.initialLivestreamId;
    if (roomId != null && _hasJoinedAsViewer && !_hasLeftAsViewer) {
      _hasLeftAsViewer = true;
      await _liveDs.leaveLivestream(roomId, hostId: _room?.hostId);
    }

    if (!mounted) return;
    context.read<LivestreamBloc>().add(LivestreamStop());
    Navigator.of(context).pop();
  }

  void _startPeriodicSync(String livestreamId) {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _syncLiveRoomData(livestreamId);
    });
  }

  Future<void> _syncLiveRoomData(String livestreamId) async {
    if (!mounted) return;
    try {
      final results = await Future.wait([
        _liveDs.getLivestreamRoom(livestreamId),
        _liveDs.getLivestreamProductIds(livestreamId),
        _liveDs.getComments(livestreamId),
        _walletDs.getWalletSummary(),
      ]);
      if (!mounted) return;

      final updatedRoom = results[0] as LivestreamRoomInfo?;
      final productIds = results[1] as List<String>;
      final comments = results[2] as List<LivestreamCommentItem>;
      final wallet = results[3] as WalletSummary;

      if (!widget.isHost &&
          updatedRoom != null &&
          updatedRoom.status == 'ended') {
        await _triggerStreamEndedOnViewer(updatedRoom: updatedRoom);
        return;
      }

      // Đảm bảo Viewer luôn join đúng channelName từ Supabase nếu phòng vừa đồng bộ về
      if (!widget.isHost &&
          updatedRoom != null &&
          updatedRoom.channelName.trim().isNotEmpty) {
        final bloc = context.read<LivestreamBloc>();
        if (bloc.state.joinedChannelName != updatedRoom.channelName.trim()) {
          bloc.add(
            LivestreamJoinChannel(
              channelName: updatedRoom.channelName.trim(),
              isBroadcaster: false,
            ),
          );
        }
      }

      bool hasNewComments = false;
      if (!_initialCommentsLoaded) {
        _initialCommentsLoaded = true;
        for (final c in comments) {
          _seenCommentIds.add(c.id);
          if (c.type == 'gift') {
            _seenGiftCommentIds.add(c.id);
          }
        }
        hasNewComments = comments.isNotEmpty;
      } else {
        for (final c in comments) {
          if (!_seenCommentIds.contains(c.id)) {
            _seenCommentIds.add(c.id);
            hasNewComments = true;
            if (c.type == 'gift' && !_seenGiftCommentIds.contains(c.id)) {
              _seenGiftCommentIds.add(c.id);
              _showGiftBanner(c);
            } else if (c.isJoinEvent || c.isLikeEvent) {
              _showActivityBanner(c);
            }
          }
        }
      }

      setState(() {
        _wallet = wallet;
        if (updatedRoom != null) {
          _room = updatedRoom;
          // Nếu Realtime Presence đang hoạt động, ưu tiên số đếm Presence thời gian thực
          if (!_presenceSynced) {
            _viewerCount = updatedRoom.viewerCount < 0
                ? 0
                : updatedRoom.viewerCount;
          }
          if (updatedRoom.likeCount > _likeCount || widget.isHost) {
            _likeCount = updatedRoom.likeCount;
          }
          _totalGiftCoins = updatedRoom.totalGiftCoins;
          _pinnedProductId = updatedRoom.pinnedProductId;
        }
        if (_allCatalogProducts.isNotEmpty) {
          _attachedProducts = productIds.isEmpty
              ? <Product>[]
              : _allCatalogProducts
                    .where((p) => productIds.contains(p.id))
                    .toList();
        }
        if (comments.isNotEmpty) {
          _comments = comments;
        }
      });

      if (hasNewComments) {
        _scrollToLatestComment();
      }
    } catch (_) {}
  }

  void _scrollToLatestComment() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollCtrl.hasClients) {
        _chatScrollCtrl.animateTo(
          _chatScrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void _showGiftBanner(LivestreamCommentItem giftComment) {
    _giftBannerTimer?.cancel();
    setState(() => _activeGiftBanner = giftComment);
    _giftBannerTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() => _activeGiftBanner = null);
      }
    });
  }

  void _showActivityBanner(LivestreamCommentItem activityItem) {
    _activityBannerTimer?.cancel();
    setState(() => _activeActivityBanner = activityItem);
    _activityBannerTimer = Timer(const Duration(milliseconds: 3400), () {
      if (mounted) {
        setState(() => _activeActivityBanner = null);
      }
    });
  }

  void _spawnFloatingHeart() {
    if (!mounted) return;
    final spec = _FloatingHeartSpec(
      id: DateTime.now().microsecondsSinceEpoch + _rng.nextInt(10000),
      horizontalOffset: (_rng.nextDouble() * 44) - 22,
      color: const [
        AppColors.primary,
        Color(0xFFFF5FA2),
        Color(0xFFFF7A18),
        AppColors.secondary,
      ][_rng.nextInt(4)],
    );
    setState(() {
      _floatingHearts.add(spec);
      if (_floatingHearts.length > 14) {
        _floatingHearts.removeAt(0);
      }
    });
    Future.delayed(const Duration(milliseconds: 1550), () {
      if (!mounted) return;
      setState(() {
        _floatingHearts.removeWhere((h) => h.id == spec.id);
      });
    });
  }

  Future<void> _handleStartLive() async {
    if (_isStartingLive) return;
    setState(() {
      _isStartingLive = true;
      _hideErrorBanner = false;
    });
    try {
      final productIds = _attachedProducts.map((p) => p.id).toList();
      final pinnedId =
          _pinnedProductId ?? (productIds.isNotEmpty ? productIds.first : null);

      final createdRoom = await _liveDs.createLivestream(
        title: _titleCtrl.text.trim(),
        channelName: widget.channelName,
        productIds: productIds,
        pinnedProductId: pinnedId,
      );

      if (!mounted) return;
      context.read<LivestreamBloc>().add(
            LivestreamStart(channelName: createdRoom.channelName),
          );

      final welcomeComment = LivestreamCommentItem(
        id: 'welcome-${DateTime.now().millisecondsSinceEpoch}',
        livestreamId: createdRoom.id,
        userId: createdRoom.hostId,
        username: createdRoom.hostUsername,
        displayName: createdRoom.hostDisplayName,
        avatarUrl: createdRoom.hostAvatarUrl,
        content:
            'Chào mừng mọi người đến với phòng Live! Nhấn vào Giỏ hàng góc dưới để săn deal nhé 🛒🔥',
        type: 'system',
        createdAt: DateTime.now(),
      );

      setState(() {
        _room = createdRoom;
        _viewerCount = 0; // Chủ phòng không tính vào lượt xem
        _pinnedProductId = pinnedId;
        _comments = [welcomeComment];
        _isStartingLive = false;
      });

      await _connectRoomRealtime(createdRoom.id);
      _startPeriodicSync(createdRoom.id);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isStartingLive = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.error,
          content: Text(e.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  Future<void> _handleEndLive() async {
    if (_isEndingOrLeaving) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceSheet,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.borderSubtle),
        ),
        title: const Text(
          'Kết thúc Livestream?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        content: Text(
          'Phiên Live đã nhận được ${_currencyFmt.format(_totalGiftCoins)} xu quà tặng và ${_currencyFmt.format(_likeCount)} lượt thích.',
          style: const TextStyle(color: Colors.white70, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Tiếp tục Live',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Kết thúc',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;
    _isEndingOrLeaving = true;

    if (_room != null) {
      await _liveDs.endLivestream(_room!.id);
    }
    await _broadcastRoomSignalAsync('stream_ended');

    final ch = _realtimeChannel;
    _realtimeChannel = null;
    if (ch != null) {
      try {
        await ch.untrack();
        await SupabaseService.client.removeChannel(ch);
      } catch (_) {}
    }

    if (!mounted) return;
    context.read<LivestreamBloc>().add(LivestreamStop());
    Navigator.of(context).pop();
  }

  Future<void> _handleSendComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty || _room == null) return;
    _commentCtrl.clear();

    final sent = await _liveDs.sendComment(
      livestreamId: _room!.id,
      content: text,
    );
    if (sent != null && mounted) {
      _seenCommentIds.add(sent.id);
      setState(() {
        _comments = [..._comments, sent];
      });
      _scrollToLatestComment();
      _broadcastRoomSignal('refresh');
    }
  }

  Future<void> _handleLikeStream() async {
    setState(() => _likeCount += 1);
    _spawnFloatingHeart();
    _broadcastRoomSignal('like_tap');

    final streamId = _room?.id;
    if (streamId == null) return;

    await _liveDs.likeLivestream(streamId);

    // Hiển thị dòng thông báo "<Tên> đã thích phiên Live" (giới hạn 10s/lần mỗi người để tránh spam khi bấm liên tục)
    final now = DateTime.now();
    final canAnnounce = _lastLikeAnnouncementAt == null ||
        now.difference(_lastLikeAnnouncementAt!) >=
            const Duration(seconds: 10);

    if (canAnnounce && !widget.isHost) {
      _lastLikeAnnouncementAt = now;
      final likedItem = await _liveDs.sendRoomActivity(
        livestreamId: streamId,
        tag: 'LIKE',
        message: 'đã thích phiên Live',
      );
      if (likedItem != null && mounted) {
        _seenCommentIds.add(likedItem.id);
        setState(() {
          if (!_comments.any((c) => c.id == likedItem.id)) {
            _comments = [..._comments, likedItem];
          }
        });
        _showActivityBanner(likedItem);
        _scrollToLatestComment();
        _broadcastRoomSignal('refresh');
      }
    }
  }

  Product? get _pinnedProduct {
    if (_pinnedProductId == null) {
      return _attachedProducts.isNotEmpty ? _attachedProducts.first : null;
    }
    for (final p in _attachedProducts) {
      if (p.id == _pinnedProductId) return p;
    }
    return _attachedProducts.isNotEmpty ? _attachedProducts.first : null;
  }

  Future<void> _openHostProductSelector() async {
    final selected = await showModalBottomSheet<List<Product>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceSheet,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _HostProductSelectorSheet(
        allProducts: _allCatalogProducts,
        initiallySelected: _attachedProducts,
      ),
    );

    if (selected != null && mounted) {
      final newPinned = selected.any((p) => p.id == _pinnedProductId)
          ? _pinnedProductId
          : (selected.isNotEmpty ? selected.first.id : null);

      setState(() {
        _attachedProducts = selected;
        _pinnedProductId = newPinned;
      });

      if (_room != null) {
        await _liveDs.syncLivestreamProducts(
          livestreamId: _room!.id,
          productIds: selected.map((p) => p.id).toList(),
          pinnedProductId: newPinned,
        );
        _broadcastRoomSignal('refresh');
      }
    }
  }

  Future<void> _openLiveShoppingBagSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceSheet,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return _LiveShoppingBagSheet(
            products: _attachedProducts,
            pinnedProductId: _pinnedProduct?.id,
            isHost: widget.isHost,
            onAddMoreProducts: () async {
              Navigator.pop(ctx);
              await _openHostProductSelector();
            },
            onTogglePin: (product) async {
              final nextPin =
                  _pinnedProductId == product.id ? null : product.id;
              setState(() => _pinnedProductId = nextPin);
              setSheetState(() {});
              if (_room != null) {
                await _liveDs.pinProduct(
                  livestreamId: _room!.id,
                  productId: nextPin,
                );
                _broadcastRoomSignal('refresh');
              }
            },
            onAddToCart: (product) => _addProductToCart(product),
            onBuyNow: (product) {
              Navigator.pop(ctx);
              _buyProductNow(product);
            },
          );
        },
      ),
    );
  }

  Future<void> _addProductToCart(Product product) async {
    try {
      final variantId =
          product.variants.isNotEmpty ? product.variants.first.id : null;
      final res = await sl<AddToCartUseCase>()(
        productId: product.id,
        variantId: variantId,
        qty: 1,
      );
      if (!mounted) return;
      res.fold(
        (failure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.error,
              content: Text(failure.message),
            ),
          );
        },
        (_) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.emerald,
              content: Text('🛒 Đã thêm "${product.title}" vào giỏ hàng!'),
              action: SnackBarAction(
                label: 'Xem giỏ',
                textColor: Colors.white,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CartScreen()),
                  );
                },
              ),
            ),
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  void _buyProductNow(Product product) {
    final variant =
        product.variants.isNotEmpty ? product.variants.first : null;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CheckoutScreen(
          directOrderArgs: DirectOrderArgs(
            product: product,
            selectedVariant: variant,
            qty: 1,
          ),
        ),
      ),
    );
  }

  Future<void> _openGiftSheet() async {
    final updatedWallet = await _walletDs.getWalletSummary();
    if (!mounted) return;
    setState(() => _wallet = updatedWallet);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceSheet,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _LiveGiftBottomSheet(
        gifts: _giftCatalog,
        initialWallet: _wallet,
        onOpenWallet: (tabIndex) async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => WalletScreen(initialTabIndex: tabIndex),
            ),
          );
          final refreshed = await _walletDs.getWalletSummary();
          if (mounted) setState(() => _wallet = refreshed);
        },
        onSendGift: (gift, quantity) async {
          final streamId = _room?.id ?? 'local-room';
          final result = await _walletDs.sendLivestreamGift(
            livestreamId: streamId,
            gift: gift,
            quantity: quantity,
          );

          final me = await _liveDs.getCurrentUserMiniProfile();
          final totalCost = gift.coinPrice * quantity;
          final giftComment = LivestreamCommentItem(
            id: 'gift-${DateTime.now().millisecondsSinceEpoch}',
            livestreamId: streamId,
            userId: me.userId.isEmpty ? 'me' : me.userId,
            username: me.username,
            displayName: me.displayName,
            avatarUrl: me.avatarUrl,
            content:
                'đã tặng ${quantity}x ${gift.icon} ${gift.name} ($totalCost xu)',
            type: 'gift',
            giftName: gift.name,
            giftIcon: gift.icon,
            giftQuantity: quantity,
            giftCoins: totalCost,
            createdAt: DateTime.now(),
          );

          if (!mounted) return;
          _seenCommentIds.add(giftComment.id);
          _seenGiftCommentIds.add(giftComment.id);
          _showGiftBanner(giftComment);

          setState(() {
            _wallet = _wallet.copyWith(coinBalance: result['coin_balance']);
            _totalGiftCoins += totalCost;
            _comments = [..._comments, giftComment];
          });
          _scrollToLatestComment();
          _broadcastRoomSignal('refresh');
        },
      ),
    );
  }

  Future<void> _openWalletScreen({int initialTab = 0}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WalletScreen(initialTabIndex: initialTab),
      ),
    );
    final refreshed = await _walletDs.getWalletSummary();
    if (mounted) setState(() => _wallet = refreshed);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<LivestreamBloc, LivestreamState>(
      listenWhen: (prev, curr) =>
          !widget.isHost &&
          prev.remoteUsers.isNotEmpty &&
          curr.remoteUsers.isEmpty,
      listener: (_, _) {
        _verifyIfStreamEnded();
      },
      builder: (context, state) {
        final isLiveActive = !widget.isHost || state.isLive || _room != null;

        return PopScope(
          canPop: _isEndingOrLeaving ||
              _isStreamEndedForViewer ||
              (widget.isHost && !isLiveActive),
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            if (widget.isHost && isLiveActive) {
              _handleEndLive();
            } else {
              _handleViewerExit();
            }
          },
          child: Scaffold(
            backgroundColor: AppColors.surfaceDark,
            resizeToAvoidBottomInset: true,
            body: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onDoubleTap:
                  (!widget.isHost && isLiveActive && !_isStreamEndedForViewer)
                  ? _handleLikeStream
                  : null,
              child: Stack(
                children: [
                  // 1. Video Background (Agora or CameraController fallback or Viewer Waiting UI)
                  if (!_isStreamEndedForViewer)
                    Positioned.fill(child: _buildVideoSurface(state)),

                  // Subtle gradient overlay for readability
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.52),
                              Colors.transparent,
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.82),
                            ],
                            stops: const [0.0, 0.22, 0.55, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // 2. Viewer Stream-Ended Fullscreen Overlay
                  if (_isStreamEndedForViewer && !widget.isHost)
                    Positioned.fill(child: _buildStreamEndedOverlay())
                  // 3. Pre-Live Setup UI (for Host before pressing GO LIVE)
                  else if (!isLiveActive && widget.isHost)
                    _buildPreLiveSetupOverlay(state)
                  else ...[
                    // 3. Active Live Room Top Bar
                    _buildLiveTopBar(state),

                    // 3b. Diagnostic Error Banner if Agora Token / Certificate is missing
                    if (state.error != null && !_hideErrorBanner)
                      Positioned(
                        top: MediaQuery.of(context).padding.top + 94,
                        left: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF991B1B,
                            ).withValues(alpha: 0.94),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppColors.gold.withValues(alpha: 0.65),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.warning_amber_rounded,
                                color: AppColors.gold,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  state.error!,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                              InkWell(
                                onTap: () =>
                                    setState(() => _hideErrorBanner = true),
                                child: const Padding(
                                  padding: EdgeInsets.all(4),
                                  child: Icon(
                                    Icons.close,
                                    color: Colors.white70,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // 4. Floating Gift Animation Banner
                    if (_activeGiftBanner != null)
                      Positioned(
                        top: MediaQuery.of(context).padding.top + 96,
                        left: 14,
                        right: 24,
                        child: _GiftBannerWidget(item: _activeGiftBanner!),
                      ),

                    // 4b. Floating Hearts Layer
                    if (_floatingHearts.isNotEmpty)
                      Positioned(
                        right: 16,
                        bottom: 72,
                        width: 84,
                        height: 240,
                        child: IgnorePointer(
                          child: Stack(
                            alignment: Alignment.bottomCenter,
                            children: _floatingHearts
                                .map(
                                  (h) => _FloatingHeartWidget(
                                    key: ValueKey(h.id),
                                    spec: h,
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ),

                    // 5. Pinned Product + Activity Toast + Live Chat + Bottom Bar
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_pinnedProduct != null)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _PinnedProductCard(
                                    product: _pinnedProduct!,
                                    isHost: widget.isHost,
                                    onTapCard: _openLiveShoppingBagSheet,
                                    onPrimaryAction: () {
                                      if (widget.isHost) {
                                        _openLiveShoppingBagSheet();
                                      } else {
                                        _buyProductNow(_pinnedProduct!);
                                      }
                                    },
                                    onAddToCart: widget.isHost
                                        ? null
                                        : () => _addProductToCart(
                                            _pinnedProduct!,
                                          ),
                                  ),
                                ),
                              if (_activeActivityBanner != null)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: _ActivityToastPill(
                                    item: _activeActivityBanner!,
                                  ),
                                ),
                              _buildLiveChatStream(),
                              const SizedBox(height: 10),
                              _buildLiveBottomActionBar(state),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStreamEndedOverlay() {
    final hostName = (_room?.hostDisplayName.isNotEmpty == true)
        ? _room!.hostDisplayName
        : (_room?.hostUsername ?? 'Chủ phòng');
    final hostUsername = _room?.hostUsername ?? 'streamer';
    final avatarUrl = StorageImage.publicUrl(_room?.hostAvatarUrl);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF141827),
            AppColors.surfaceDark,
            Color(0xFF07080D),
          ],
        ),
      ),
      child: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: -60,
              left: -40,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.14),
                ),
              ),
            ),
            Positioned(
              bottom: -70,
              right: -40,
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.secondary.withValues(alpha: 0.10),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 12,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                ),
                icon: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 24,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 30,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSheet.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(color: AppColors.borderSubtle),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.45),
                        blurRadius: 28,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.bottomCenter,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white24,
                                width: 2,
                              ),
                            ),
                            child: CircleAvatar(
                              radius: 40,
                              backgroundColor: AppColors.surfaceElevated,
                              backgroundImage: avatarUrl != null
                                  ? NetworkImage(avatarUrl)
                                  : null,
                              child: avatarUrl == null
                                  ? const Icon(
                                      Icons.person_rounded,
                                      color: Colors.white60,
                                      size: 40,
                                    )
                                  : null,
                            ),
                          ),
                          Positioned(
                            bottom: -8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceElevated,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: AppColors.borderHighlight,
                                ),
                              ),
                              child: const Text(
                                'ĐÃ KẾT THÚC',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        hostName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '@$hostUsername',
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Phiên Live đã kết thúc',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Chủ phòng đã dừng phát trực tiếp.\nCảm ơn bạn đã tham gia và tương tác!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 13.5,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 22),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceCard,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.borderSubtle),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.favorite_rounded,
                                        color: AppColors.primary,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        _currencyFmt.format(_likeCount),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Lượt thích',
                                    style: TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 32,
                              color: AppColors.borderSubtle,
                            ),
                            Expanded(
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.monetization_on_rounded,
                                        color: AppColors.gold,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        _currencyFmt.format(_totalGiftCoins),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Xu quà tặng',
                                    style: TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.3),
                                blurRadius: 14,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton.icon(
                            onPressed: () => Navigator.of(context).pop(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: const Icon(
                              Icons.arrow_back_rounded,
                              size: 19,
                            ),
                            label: const Text(
                              'Quay lại',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoSurface(LivestreamState state) {
    final agora = state.agoraService;
    if (agora != null && agora.isEngineReady && agora.engine != null) {
      if (widget.isHost) {
        if (_isCameraOff) return _buildCameraOffPlaceholder();
        return AgoraVideoView(
          key: const ValueKey('agora_local_broadcaster'),
          controller: VideoViewController(
            rtcEngine: agora.engine!,
            canvas: const VideoCanvas(
              uid: 0,
              renderMode: RenderModeType.renderModeHidden,
            ),
          ),
        );
      } else if (state.remoteUsers.isNotEmpty) {
        final remoteUid = state.remoteUsers.first;
        final activeChannel =
            (state.joinedChannelName?.trim().isNotEmpty == true)
            ? state.joinedChannelName!.trim()
            : (_room?.channelName.trim().isNotEmpty == true
                  ? _room!.channelName.trim()
                  : widget.channelName);

        return AgoraVideoView(
          key: ValueKey('agora_remote_${activeChannel}_$remoteUid'),
          controller: VideoViewController.remote(
            rtcEngine: agora.engine!,
            canvas: VideoCanvas(
              uid: remoteUid,
              renderMode: RenderModeType.renderModeHidden,
            ),
            connection: RtcConnection(channelId: activeChannel),
          ),
        );
      }
    }

    // Local CameraController fallback for Host (khi không cấu hình AGORA_APP_ID)
    if (widget.isHost) {
      if (_isCameraOff) return _buildCameraOffPlaceholder();
      if (_cameraController != null &&
          _cameraController!.value.isInitialized) {
        return FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: _cameraController!.value.previewSize?.height ?? 720,
            height: _cameraController!.value.previewSize?.width ?? 1280,
            child: CameraPreview(_cameraController!),
          ),
        );
      }
    }

    // Viewer mode waiting for remote stream or camera initializing visual
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A102B), AppColors.surfaceDark, Color(0xFF0F172A)],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 44,
                  backgroundColor: Colors.white12,
                  backgroundImage:
                      (_room?.hostAvatarUrl?.isNotEmpty == true)
                      ? CachedNetworkImageProvider(
                          StorageImage.avatarUrl(_room!.hostAvatarUrl!),
                        )
                      : null,
                  child: (_room?.hostAvatarUrl?.isNotEmpty != true)
                      ? const Icon(
                          Icons.live_tv_rounded,
                          color: Colors.white70,
                          size: 40,
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                _room?.title ?? 'Đang phát trực tiếp',
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                state.error != null
                    ? 'Không thể kết nối luồng hình ảnh Agora'
                    : '@${_room?.hostUsername ?? 'streamer'} đang kết nối luồng hình ảnh...',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white60, fontSize: 13),
              ),
              if (!widget.isHost && state.error == null) ...[
                const SizedBox(height: 14),
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: AppColors.primary,
                    strokeWidth: 2.2,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCameraOffPlaceholder() {
    return Container(
      color: AppColors.surfaceDark,
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.videocam_off_rounded, color: Colors.white38, size: 56),
            SizedBox(height: 10),
            Text(
              'Camera đang tạm tắt',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreLiveSetupOverlay(LivestreamState state) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: (constraints.maxHeight - 32).clamp(0.0, 9999.0),
              ),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Top controls
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.surfaceGlass,
                            side: const BorderSide(
                              color: AppColors.borderSubtle,
                            ),
                          ),
                          icon: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                        Flexible(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: InkWell(
                                  onTap: () =>
                                      _openWalletScreen(initialTab: 0),
                                  borderRadius: BorderRadius.circular(22),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceGlass,
                                      borderRadius: BorderRadius.circular(22),
                                      border: Border.all(
                                        color: AppColors.gold.withValues(
                                          alpha: 0.4,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Text(
                                          '🪙',
                                          style: TextStyle(fontSize: 14),
                                        ),
                                        const SizedBox(width: 6),
                                        Flexible(
                                          child: Text(
                                            '${_currencyFmt.format(_wallet.coinBalance)} Xu',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: AppColors.gold,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                onPressed: _switchCamera,
                                style: IconButton.styleFrom(
                                  backgroundColor: AppColors.surfaceGlass,
                                  side: const BorderSide(
                                    color: AppColors.borderSubtle,
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.cameraswitch_rounded,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Setup Card: Title & Product Bag
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceGlass,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.borderSubtle),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3.5,
                                ),
                                decoration: BoxDecoration(
                                  gradient: AppColors.primaryGradient,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'LIVE SHOP',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Thiết lập phòng phát trực tiếp',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _titleCtrl,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Tiêu đề Livestream',
                              labelStyle: const TextStyle(color: Colors.white60),
                              filled: true,
                              fillColor: Colors.white.withValues(alpha: 0.07),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: AppColors.borderSubtle,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: AppColors.primary,
                                  width: 1.4,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          InkWell(
                            onTap: _openHostProductSelector,
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(
                                  alpha: 0.12,
                                ),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.45,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(9),
                                    decoration: BoxDecoration(
                                      gradient: AppColors.shopGradient,
                                      borderRadius: BorderRadius.circular(11),
                                    ),
                                    child: const Icon(
                                      Icons.shopping_bag_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _attachedProducts.isEmpty
                                              ? 'Gắn giỏ hàng sản phẩm vào Live'
                                              : 'Đã gắn ${_attachedProducts.length} sản phẩm vào giỏ hàng Live',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 13.5,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _attachedProducts.isEmpty
                                              ? 'Người xem có thể thêm vào giỏ hoặc mua ngay trên Live'
                                              : 'Sản phẩm ghim: ${_pinnedProduct?.title ?? _attachedProducts.first.title}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 11.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(
                                    Icons.add_circle_rounded,
                                    color: AppColors.primarySoft,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Spacer(),
                    const SizedBox(height: 16),

                    // Bottom Start Live Gradient Button
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.4),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: SizedBox(
                        height: 54,
                        child: ElevatedButton.icon(
                          onPressed: _isStartingLive ? null : _handleStartLive,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                          ),
                          icon: _isStartingLive
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.sensors_rounded, size: 24),
                          label: Text(
                            _isStartingLive
                                ? 'Đang khởi tạo phòng Live...'
                                : 'BẮT ĐẦU PHÁT TRỰC TIẾP',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLiveTopBar(LivestreamState state) {
    final hostName = _room?.hostDisplayName ?? 'Streamer';
    // Hiển thị chính xác số người xem (không bao giờ tính chủ phòng)
    final viewers = _viewerCount < 0 ? 0 : _viewerCount;

    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 12,
      right: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Host info pill
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceGlass,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(1.5),
                        decoration: const BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          shape: BoxShape.circle,
                        ),
                        child: CircleAvatar(
                          radius: 15,
                          backgroundColor: AppColors.surfaceCard,
                          backgroundImage:
                              (_room?.hostAvatarUrl?.isNotEmpty == true)
                              ? CachedNetworkImageProvider(
                                  StorageImage.avatarUrl(_room!.hostAvatarUrl!),
                                )
                              : null,
                          child: (_room?.hostAvatarUrl?.isNotEmpty != true)
                              ? const Icon(
                                  Icons.person,
                                  color: Colors.white,
                                  size: 16,
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              hostName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              '❤️ ${_currencyFmt.format(_likeCount)} thích',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 10.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3.5,
                        ),
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'LIVE',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 9.5,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // Viewer count pill (0 when only Host is in room)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceGlass,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.visibility_rounded,
                      color: AppColors.secondary,
                      size: 14,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _currencyFmt.format(viewers),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),

              // Close / End button
              IconButton(
                onPressed: widget.isHost ? _handleEndLive : _handleViewerExit,
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.surfaceGlass,
                  side: const BorderSide(color: AppColors.borderSubtle),
                  padding: const EdgeInsets.all(7),
                  minimumSize: const Size(34, 34),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 19,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Second row: Wrap prevents overflow even with large coin numbers
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              GestureDetector(
                onTap: () => _openWalletScreen(initialTab: 1),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5.5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceGlass,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: AppColors.gold.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('💎', style: TextStyle(fontSize: 12.5)),
                      const SizedBox(width: 5),
                      Text(
                        'Quà Live: ${_currencyFmt.format(_totalGiftCoins)} xu',
                        style: const TextStyle(
                          color: AppColors.gold,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => _openWalletScreen(initialTab: 0),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5.5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceGlass,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🪙', style: TextStyle(fontSize: 12.5)),
                      const SizedBox(width: 5),
                      Text(
                        'Ví: ${_currencyFmt.format(_wallet.coinBalance)} xu',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 5),
                      const Icon(
                        Icons.add_circle_rounded,
                        color: AppColors.primary,
                        size: 14,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLiveChatStream() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 168),
      child: ListView.builder(
        controller: _chatScrollCtrl,
        shrinkWrap: true,
        itemCount: _comments.length,
        itemBuilder: (context, index) {
          final c = _comments[index];
          final isGift = c.type == 'gift';
          final isJoin = c.isJoinEvent;
          final isLike = c.isLikeEvent;
          final isSystemNotice = c.type == 'system' && !isJoin && !isLike;

          Color bgColor = AppColors.surfaceGlass;
          Border? border;
          String prefixText = '${c.displayName}: ';
          Color prefixColor = Colors.white70;

          if (isGift) {
            bgColor = AppColors.gold.withValues(alpha: 0.2);
            border = Border.all(color: AppColors.gold.withValues(alpha: 0.55));
            prefixText = '🎁 ${c.displayName} ';
            prefixColor = AppColors.gold;
          } else if (isJoin) {
            bgColor = AppColors.secondary.withValues(alpha: 0.16);
            border = Border.all(
              color: AppColors.secondary.withValues(alpha: 0.38),
            );
            prefixText = '👋 ${c.displayName} ';
            prefixColor = AppColors.secondary;
          } else if (isLike) {
            bgColor = AppColors.primary.withValues(alpha: 0.18);
            border = Border.all(
              color: AppColors.primary.withValues(alpha: 0.42),
            );
            prefixText = '❤️ ${c.displayName} ';
            prefixColor = AppColors.primarySoft;
          } else if (isSystemNotice) {
            bgColor = AppColors.indigo.withValues(alpha: 0.22);
            border = Border.all(
              color: AppColors.indigo.withValues(alpha: 0.35),
            );
            prefixText = '✨ Hệ thống: ';
            prefixColor = AppColors.secondary;
          }

          return Align(
            alignment: Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(14),
                border: border,
              ),
              child: RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: prefixText,
                      style: TextStyle(
                        color: prefixColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                      ),
                    ),
                    TextSpan(
                      text: c.cleanContent,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: (isGift || isJoin || isLike)
                            ? FontWeight.w700
                            : FontWeight.w500,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLiveBottomActionBar(LivestreamState state) {
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    final isTyping = isKeyboardOpen || _commentFocusNode.hasFocus;

    return Row(
      children: [
        // 1. Comment input box (Expands to Full Width when typing)
        Expanded(
          child: Container(
            height: 44,
            padding: const EdgeInsets.only(left: 12, right: 6),
            decoration: BoxDecoration(
              color: AppColors.surfaceGlass,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isTyping ? AppColors.primary : AppColors.borderSubtle,
                width: isTyping ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                if (isTyping)
                  GestureDetector(
                    onTap: () {
                      _commentFocusNode.unfocus();
                    },
                    behavior: HitTestBehavior.opaque,
                    child: const Padding(
                      padding: EdgeInsets.only(right: 6),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Colors.white70,
                        size: 22,
                      ),
                    ),
                  ),
                Expanded(
                  child: TextField(
                    controller: _commentCtrl,
                    focusNode: _commentFocusNode,
                    cursorColor: AppColors.primary,
                    textAlignVertical: TextAlignVertical.center,
                    style: const TextStyle(color: Colors.white, fontSize: 13.5),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _handleSendComment(),
                    decoration: InputDecoration(
                      hintText: widget.isHost
                          ? 'Bình luận...'
                          : 'Bình luận trực tiếp...',
                      hintStyle: const TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      isCollapsed: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: _handleSendComment,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 15,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (!isTyping) ...[
          const SizedBox(width: 6),

          // 2. Live Shopping Bag Button
          GestureDetector(
            onTap: _openLiveShoppingBagSheet,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: AppColors.shopGradient,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.shopping_bag_rounded,
                    color: Colors.white,
                    size: 19,
                  ),
                ),
                if (_attachedProducts.isNotEmpty)
                  Positioned(
                    right: -2,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5.5,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_attachedProducts.length}',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 6),

          // 3. Gift Button
          GestureDetector(
            onTap: _openGiftSheet,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: AppColors.liveGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(
                Icons.card_giftcard_rounded,
                color: Colors.white,
                size: 19,
              ),
            ),
          ),
          const SizedBox(width: 6),

          // 4. Host controls (Mic / Flip Camera) or Viewer Like button
          if (widget.isHost) ...[
            GestureDetector(
              onTap: () =>
                  context.read<LivestreamBloc>().add(LivestreamToggleMute()),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: state.isMuted ? AppColors.error : AppColors.surfaceGlass,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Icon(
                  state.isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                  color: Colors.white,
                  size: 19,
                ),
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: _switchCamera,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.surfaceGlass,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: const Icon(
                  Icons.cameraswitch_rounded,
                  color: Colors.white,
                  size: 19,
                ),
              ),
            ),
          ] else
            GestureDetector(
              onTap: _handleLikeStream,
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.favorite_rounded,
                  color: Colors.white,
                  size: 21,
                ),
              ),
            ),
        ],
      ],
    );
  }
}

// ─── Real-time Activity Toast Pill (Join / Like) ──────────────────────────────

class _ActivityToastPill extends StatelessWidget {
  final LivestreamCommentItem item;

  const _ActivityToastPill({required this.item});

  @override
  Widget build(BuildContext context) {
    final isJoin = item.isJoinEvent;
    final accent = isJoin ? AppColors.secondary : AppColors.primary;

    return TweenAnimationBuilder<double>(
      key: ValueKey(item.id),
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutBack,
      builder: (context, val, child) {
        return Opacity(
          opacity: val.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(-16 * (1 - val), 0),
            child: child,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              accent.withValues(alpha: 0.88),
              AppColors.surfaceCard.withValues(alpha: 0.92),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white24, width: 0.8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(isJoin ? '👋' : '❤️', style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                '${item.displayName} ${item.cleanContent}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Floating Animated Heart ──────────────────────────────────────────────────

class _FloatingHeartSpec {
  final int id;
  final double horizontalOffset;
  final Color color;

  const _FloatingHeartSpec({
    required this.id,
    required this.horizontalOffset,
    required this.color,
  });
}

class _FloatingHeartWidget extends StatelessWidget {
  final _FloatingHeartSpec spec;

  const _FloatingHeartWidget({super.key, required this.spec});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 1450),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) {
        final dy = -190.0 * t;
        final dx = spec.horizontalOffset * math.sin(t * math.pi);
        final scale = t < 0.2 ? (0.5 + t * 2.8) : (1.06 - t * 0.25);
        final opacity = t < 0.7 ? 1.0 : ((1.0 - t) / 0.3).clamp(0.0, 1.0);
        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(dx, dy),
            child: Transform.scale(scale: scale, child: child),
          ),
        );
      },
      child: Icon(Icons.favorite_rounded, color: spec.color, size: 30),
    );
  }
}

// ─── Pinned Product Floating Card ─────────────────────────────────────────────

class _PinnedProductCard extends StatelessWidget {
  final Product product;
  final bool isHost;
  final VoidCallback onTapCard;
  final VoidCallback onPrimaryAction;
  final VoidCallback? onAddToCart;

  const _PinnedProductCard({
    required this.product,
    required this.isHost,
    required this.onTapCard,
    required this.onPrimaryAction,
    this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###', 'vi_VN');
    final imageUrl = product.displayImagePath != null
        ? StorageImage.productMediaUrl(product.displayImagePath!)
        : '';

    return GestureDetector(
      onTap: onTapCard,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 325),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderHighlight),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: SizedBox(
                width: 50,
                height: 50,
                child: imageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) => Container(
                          color: Colors.white10,
                          child: const Icon(
                            Icons.shopping_bag_outlined,
                            color: Colors.white54,
                          ),
                        ),
                      )
                    : Container(
                        color: Colors.white10,
                        child: const Icon(
                          Icons.shopping_bag_outlined,
                          color: Colors.white54,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5.5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          gradient: AppColors.shopGradient,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: const Text(
                          'GHIM',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          product.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${fmt.format(product.priceMin)} ₫',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.gold,
                      fontWeight: FontWeight.w900,
                      fontSize: 13.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            if (onAddToCart != null) ...[
              InkWell(
                onTap: onAddToCart,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.4),
                    ),
                  ),
                  child: const Icon(
                    Icons.add_shopping_cart_rounded,
                    color: AppColors.primarySoft,
                    size: 16,
                  ),
                ),
              ),
              const SizedBox(width: 5),
            ],
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: ElevatedButton(
                onPressed: onPrimaryAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 8,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  isHost ? 'Quản lý' : 'Mua',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Floating Gift Banner Widget ──────────────────────────────────────────────

class _GiftBannerWidget extends StatelessWidget {
  final LivestreamCommentItem item;

  const _GiftBannerWidget({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: AppColors.liveGradient,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white30),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.45),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            item.giftIcon ?? '🎁',
            style: const TextStyle(fontSize: 26),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 13.5,
                  ),
                ),
                Text(
                  'Đã gửi tặng ${item.giftName ?? 'Quà'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'x${item.giftQuantity}',
            style: const TextStyle(
              color: AppColors.gold,
              fontWeight: FontWeight.w900,
              fontSize: 20,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Shared Sheet Handle Bar ──────────────────────────────────────────────────

class _SheetDragHandle extends StatelessWidget {
  const _SheetDragHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white24,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

// ─── Live Shopping Bag Bottom Sheet ───────────────────────────────────────────

class _LiveShoppingBagSheet extends StatelessWidget {
  final List<Product> products;
  final String? pinnedProductId;
  final bool isHost;
  final VoidCallback onAddMoreProducts;
  final ValueChanged<Product> onTogglePin;
  final ValueChanged<Product> onAddToCart;
  final ValueChanged<Product> onBuyNow;

  const _LiveShoppingBagSheet({
    required this.products,
    required this.pinnedProductId,
    required this.isHost,
    required this.onAddMoreProducts,
    required this.onTogglePin,
    required this.onAddToCart,
    required this.onBuyNow,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###', 'vi_VN');

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.74,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SheetDragHandle(),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      gradient: AppColors.shopGradient,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.shopping_bag_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Giỏ hàng Livestream (${products.length})',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (isHost)
                    TextButton.icon(
                      onPressed: onAddMoreProducts,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Thêm/Sửa SP'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primarySoft,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                ],
              ),
              const Divider(color: AppColors.borderSubtle, height: 22),
              if (products.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 34),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(
                          Icons.remove_shopping_cart_outlined,
                          color: Colors.white24,
                          size: 48,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          isHost
                              ? 'Chưa gắn sản phẩm nào vào phiên Live'
                              : 'Streamer chưa gắn sản phẩm nào trong phiên Live này',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 13.5,
                          ),
                        ),
                        if (isHost) ...[
                          const SizedBox(height: 14),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: ElevatedButton.icon(
                              onPressed: onAddMoreProducts,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                foregroundColor: Colors.white,
                              ),
                              icon: const Icon(Icons.add),
                              label: const Text('Gắn sản phẩm ngay'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    itemCount: products.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final product = products[index];
                      final isPinned = product.id == pinnedProductId;
                      final imageUrl = product.displayImagePath != null
                          ? StorageImage.productMediaUrl(
                              product.displayImagePath!,
                            )
                          : '';

                      return Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceCard,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isPinned
                                ? AppColors.primary
                                : AppColors.borderSubtle,
                            width: isPinned ? 1.4 : 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(11),
                                  child: SizedBox(
                                    width: 66,
                                    height: 66,
                                    child: imageUrl.isNotEmpty
                                        ? CachedNetworkImage(
                                            imageUrl: imageUrl,
                                            fit: BoxFit.cover,
                                          )
                                        : Container(
                                            color: Colors.white10,
                                            child: const Icon(
                                              Icons.image_outlined,
                                              color: Colors.white38,
                                            ),
                                          ),
                                  ),
                                ),
                                Positioned(
                                  left: 4,
                                  top: 4,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5.5,
                                      vertical: 1.5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black87,
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: Text(
                                      '#${index + 1}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    product.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${fmt.format(product.priceMin)} ₫',
                                    style: const TextStyle(
                                      color: AppColors.gold,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14.5,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Wrap(
                                      spacing: 8,
                                      runSpacing: 6,
                                      alignment: WrapAlignment.end,
                                      children: [
                                        if (isHost)
                                          OutlinedButton.icon(
                                            onPressed: () =>
                                                onTogglePin(product),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: isPinned
                                                  ? AppColors.gold
                                                  : Colors.white70,
                                              side: BorderSide(
                                                color: isPinned
                                                    ? AppColors.gold
                                                    : AppColors.borderHighlight,
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 6,
                                                  ),
                                              minimumSize: Size.zero,
                                            ),
                                            icon: Icon(
                                              isPinned
                                                  ? Icons.push_pin_rounded
                                                  : Icons.push_pin_outlined,
                                              size: 15,
                                            ),
                                            label: Text(
                                              isPinned ? 'Đang ghim' : 'Ghim SP',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          )
                                        else ...[
                                          OutlinedButton(
                                            onPressed: () =>
                                                onAddToCart(product),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: Colors.white,
                                              side: const BorderSide(
                                                color:
                                                    AppColors.borderHighlight,
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 6,
                                                  ),
                                              minimumSize: Size.zero,
                                            ),
                                            child: const Text(
                                              '+ Giỏ hàng',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                          DecoratedBox(
                                            decoration: BoxDecoration(
                                              gradient:
                                                  AppColors.primaryGradient,
                                              borderRadius:
                                                  BorderRadius.circular(18),
                                            ),
                                            child: ElevatedButton(
                                              onPressed: () =>
                                                  onBuyNow(product),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    Colors.transparent,
                                                shadowColor: Colors.transparent,
                                                foregroundColor: Colors.white,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 6,
                                                    ),
                                                minimumSize: Size.zero,
                                              ),
                                              child: const Text(
                                                'Mua ngay',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Host Product Selector Sheet ──────────────────────────────────────────────

class _HostProductSelectorSheet extends StatefulWidget {
  final List<Product> allProducts;
  final List<Product> initiallySelected;

  const _HostProductSelectorSheet({
    required this.allProducts,
    required this.initiallySelected,
  });

  @override
  State<_HostProductSelectorSheet> createState() =>
      _HostProductSelectorSheetState();
}

class _HostProductSelectorSheetState extends State<_HostProductSelectorSheet> {
  late final Set<String> _selectedIds;

  @override
  void initState() {
    super.initState();
    _selectedIds = widget.initiallySelected.map((e) => e.id).toSet();
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###', 'vi_VN');

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.78,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            children: [
              const _SheetDragHandle(),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Chọn sản phẩm gắn vào Live',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: TextButton(
                      onPressed: () {
                        final chosen = widget.allProducts
                            .where((p) => _selectedIds.contains(p.id))
                            .toList();
                        Navigator.pop(context, chosen);
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Xong (${_selectedIds.length})',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(color: AppColors.borderSubtle, height: 22),
              Expanded(
                child: widget.allProducts.isEmpty
                    ? const Center(
                        child: Text(
                          'Chưa có sản phẩm nào trong cửa hàng',
                          style: TextStyle(color: Colors.white54),
                        ),
                      )
                    : ListView.builder(
                        itemCount: widget.allProducts.length,
                        itemBuilder: (context, index) {
                          final product = widget.allProducts[index];
                          final checked = _selectedIds.contains(product.id);
                          final imageUrl = product.displayImagePath != null
                              ? StorageImage.productMediaUrl(
                                  product.displayImagePath!,
                                )
                              : '';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceCard,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: checked
                                    ? AppColors.primary.withValues(alpha: 0.6)
                                    : AppColors.borderSubtle,
                              ),
                            ),
                            child: CheckboxListTile(
                              value: checked,
                              activeColor: AppColors.primary,
                              checkColor: Colors.white,
                              onChanged: (val) {
                                setState(() {
                                  if (val == true) {
                                    _selectedIds.add(product.id);
                                  } else {
                                    _selectedIds.remove(product.id);
                                  }
                                });
                              },
                              secondary: ClipRRect(
                                borderRadius: BorderRadius.circular(9),
                                child: SizedBox(
                                  width: 46,
                                  height: 46,
                                  child: imageUrl.isNotEmpty
                                      ? CachedNetworkImage(
                                          imageUrl: imageUrl,
                                          fit: BoxFit.cover,
                                        )
                                      : Container(
                                          color: Colors.white10,
                                          child: const Icon(
                                            Icons.shopping_bag_outlined,
                                            color: Colors.white38,
                                          ),
                                        ),
                                ),
                              ),
                              title: Text(
                                product.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13.5,
                                ),
                              ),
                              subtitle: Text(
                                '${fmt.format(product.priceMin)} ₫ • Kho: ${product.stockTotal}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.gold,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Live Gift Picker Bottom Sheet ────────────────────────────────────────────

class _LiveGiftBottomSheet extends StatefulWidget {
  final List<GiftCatalogItem> gifts;
  final WalletSummary initialWallet;
  final Future<void> Function(int tabIndex) onOpenWallet;
  final Future<void> Function(GiftCatalogItem gift, int quantity) onSendGift;

  const _LiveGiftBottomSheet({
    required this.gifts,
    required this.initialWallet,
    required this.onOpenWallet,
    required this.onSendGift,
  });

  @override
  State<_LiveGiftBottomSheet> createState() => _LiveGiftBottomSheetState();
}

class _LiveGiftBottomSheetState extends State<_LiveGiftBottomSheet> {
  final _fmt = NumberFormat('#,###', 'vi_VN');
  late WalletSummary _wallet;
  int _selectedGiftIdx = 0;
  int _selectedQty = 1;
  bool _isSending = false;

  static const List<int> _quantities = [1, 5, 10, 99];

  @override
  void initState() {
    super.initState();
    _wallet = widget.initialWallet;
  }

  Future<void> _send() async {
    if (_isSending || widget.gifts.isEmpty) return;
    final gift = widget.gifts[_selectedGiftIdx];
    final totalCost = gift.coinPrice * _selectedQty;

    if (_wallet.coinBalance < totalCost) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.error,
          content: Text(
            'Cần ${_fmt.format(totalCost)} xu để tặng quà (hiện có ${_fmt.format(_wallet.coinBalance)} xu). Vui lòng nạp thêm xu!',
          ),
          action: SnackBarAction(
            label: 'Nạp Xu',
            textColor: Colors.white,
            onPressed: () {
              Navigator.pop(context);
              widget.onOpenWallet(0);
            },
          ),
        ),
      );
      return;
    }

    setState(() => _isSending = true);
    try {
      await widget.onSendGift(gift, _selectedQty);
      if (!mounted) return;
      setState(() {
        _wallet = _wallet.copyWith(
          coinBalance: (_wallet.coinBalance - totalCost).clamp(0, 999999999),
        );
        _isSending = false;
      });
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.error,
          content: Text(e.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedGift = widget.gifts[_selectedGiftIdx];
    final totalCoins = selectedGift.coinPrice * _selectedQty;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SheetDragHandle(),
            // Header: Coin balance + Top-up button
            Row(
              children: [
                const Text('🎁', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Tặng Quà Livestream',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () async {
                    Navigator.pop(context);
                    await widget.onOpenWallet(0);
                  },
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: AppColors.gold.withValues(alpha: 0.45),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🪙', style: TextStyle(fontSize: 14)),
                        const SizedBox(width: 5),
                        Text(
                          '${_fmt.format(_wallet.coinBalance)} Xu',
                          style: const TextStyle(
                            color: AppColors.gold,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 5),
                        const Text(
                          '+ Nạp',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Gift Grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.gifts.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.82,
              ),
              itemBuilder: (context, index) {
                final gift = widget.gifts[index];
                final isSelected = index == _selectedGiftIdx;
                return GestureDetector(
                  onTap: () => setState(() => _selectedGiftIdx = index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary.withValues(alpha: 0.18)
                          : AppColors.surfaceCard,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.borderSubtle,
                        width: isSelected ? 1.8 : 1,
                      ),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(gift.icon, style: const TextStyle(fontSize: 26)),
                          const SizedBox(height: 4),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 72),
                            child: Text(
                              gift.name,
                              maxLines: 1,
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '🪙 ${gift.coinPrice}',
                            style: const TextStyle(
                              color: AppColors.gold,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 14),

            // Quantity selector + Send button
            Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _quantities.map((qty) {
                        final active = qty == _selectedQty;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            visualDensity: VisualDensity.compact,
                            selected: active,
                            selectedColor: AppColors.primary,
                            backgroundColor: AppColors.surfaceCard,
                            side: BorderSide(
                              color: active
                                  ? AppColors.primary
                                  : AppColors.borderSubtle,
                            ),
                            label: Text(
                              'x$qty',
                              style: TextStyle(
                                color: active ? Colors.white : Colors.white70,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                            onSelected: (_) =>
                                setState(() => _selectedQty = qty),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: ElevatedButton(
                    onPressed: _isSending ? null : _send,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 11,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                    ),
                    child: Text(
                      _isSending
                          ? 'Đang gửi...'
                          : 'Tặng (${_fmt.format(totalCoins)} xu)',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Live Discovery Sheet (Danh sách phòng Live đang phát) ───────────────────

class _LiveDiscoverySheet extends StatefulWidget {
  const _LiveDiscoverySheet();

  @override
  State<_LiveDiscoverySheet> createState() => _LiveDiscoverySheetState();
}

class _LiveDiscoverySheetState extends State<_LiveDiscoverySheet> {
  final _liveDs = LivestreamRemoteDataSource.instance;
  List<LivestreamRoomInfo> _rooms = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRooms();
  }

  Future<void> _loadRooms() async {
    setState(() => _loading = true);
    final list = await _liveDs.getActiveLivestreams();
    if (!mounted) return;
    setState(() {
      _rooms = list;
      _loading = false;
    });
  }

  void _openHostLivestream(BuildContext context) {
    VideoControllerCache.pauseAllGlobal();
    final rootNav = Navigator.of(context, rootNavigator: true);
    Navigator.pop(context);
    rootNav.push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => LivestreamScreen(
          channelName: 'live_${DateTime.now().millisecondsSinceEpoch}',
          isHost: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.76,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SheetDragHandle(),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.sensors_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Phòng Livestream Đang Phát',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: ElevatedButton.icon(
                      onPressed: () => _openHostLivestream(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      icon: const Icon(Icons.videocam_rounded, size: 16),
                      label: const Text(
                        'Phát LIVE',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(color: AppColors.borderSubtle, height: 22),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                )
              else if (_rooms.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  child: Center(
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceCard,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.borderSubtle),
                          ),
                          child: const Icon(
                            Icons.live_tv_rounded,
                            color: Colors.white38,
                            size: 40,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Hiện chưa có phòng Live nào đang phát',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: () => _openHostLivestream(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: AppColors.primary),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 11,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(22),
                            ),
                          ),
                          icon: const Icon(
                            Icons.add_circle_outline_rounded,
                            color: AppColors.primarySoft,
                          ),
                          label: const Text(
                            'Bắt đầu phiên Livestream đầu tiên',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    itemCount: _rooms.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final r = _rooms[index];
                      return Container(
                        decoration: BoxDecoration(
                          color: AppColors.surfaceCard,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.borderSubtle),
                        ),
                        child: ListTile(
                          onTap: () {
                            VideoControllerCache.pauseAllGlobal();
                            final rootNav = Navigator.of(
                              context,
                              rootNavigator: true,
                            );
                            Navigator.pop(context);
                            final isMyRoom =
                                r.hostId == SupabaseService.currentUserId;
                            rootNav.push(
                              MaterialPageRoute(
                                fullscreenDialog: true,
                                builder: (_) => LivestreamScreen(
                                  channelName: r.channelName,
                                  isHost: isMyRoom,
                                  livestreamId: r.id,
                                  initialRoom: r,
                                ),
                              ),
                            );
                          },
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          leading: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              shape: BoxShape.circle,
                            ),
                            child: CircleAvatar(
                              backgroundColor: AppColors.surfaceCard,
                              backgroundImage:
                                  (r.hostAvatarUrl?.isNotEmpty == true)
                                  ? CachedNetworkImageProvider(
                                      StorageImage.avatarUrl(r.hostAvatarUrl!),
                                    )
                                  : null,
                              child: (r.hostAvatarUrl?.isNotEmpty != true)
                                  ? const Icon(
                                      Icons.person,
                                      color: Colors.white,
                                    )
                                  : null,
                            ),
                          ),
                          title: Text(
                            r.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            '@${r.hostUsername} • 👁 ${r.viewerCount} đang xem • 💎 ${r.totalGiftCoins} xu',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 12,
                            ),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5.5,
                            ),
                            decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Text(
                              'XEM LIVE',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
