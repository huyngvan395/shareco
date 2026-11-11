// features/chat/presentation/screen/message_screen.dart

import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shareco/core/services/media/audio_recorder_service.dart';
import 'package:shareco/core/services/media/image_picker_service.dart';
import 'package:shareco/core/services/notifications/push_notification_service.dart';
import 'package:shareco/core/utils/storage_image.dart';
import 'package:shareco/features/chat/presentation/bloc/message_event.dart';
import 'package:shareco/routes/app_router.dart';
import 'package:shareco/shared/widgets/report_bottom_sheet.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/supabase/index.dart';
import '../../../../di/injector.dart';
import '../../../../shared/domain/entities/base_entity.dart';
import '../../domain/entities/chat_entities.dart';
import '../bloc/message_bloc.dart';
import '../bloc/message_state.dart';
import '../widgets/recording_wave.dart';

class MessageScreen extends StatelessWidget {
  final ConversationEntity conversation;

  const MessageScreen({super.key, required this.conversation});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          MessageBloc(
            getMessages: sl(),
            sendMessage: sl(),
            deleteMessage: sl(),
            markAsRead: sl(),
            watchMessages: sl(),
            watchUserPresence: sl(),
            uploadMedia: sl(),
          )..add(
            MessageLoadRequested(
              conversation.id,
              otherUserId: conversation
                  .otherUser(SupabaseService.currentUserId ?? '')
                  ?.id,
            ),
          ),
      child: _MessageView(conversation: conversation),
    );
  }
}

class _MessageView extends StatefulWidget {
  final ConversationEntity conversation;

  const _MessageView({required this.conversation});

  @override
  State<_MessageView> createState() => _MessageViewState();
}

class _MessageViewState extends State<_MessageView> {
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _inputFocus = FocusNode();
  bool _showEmojiPanel = false;
  bool _isRecording = false;
  Duration _recordDuration = Duration.zero;
  Timer? _recordTimer;
  late AudioRecorderService _audioRecorder;
  late ImagePickerService _imagePicker;

  String get _uid => SupabaseService.currentUserId ?? '';

  ProfileStub? get _other => widget.conversation.otherUser(_uid);

  String? _shopLogo;
  String? _shopName;
  String? _shopOwnerId;
  bool _isShopVerified = false;

  @override
  void initState() {
    super.initState();
    _shopLogo = widget.conversation.shopLogo;
    _shopName = widget.conversation.shopName;
    _shopOwnerId = widget.conversation.shopOwnerId;
    _isShopVerified = widget.conversation.isShopVerified;

    if (widget.conversation.isShop) {
      _loadShopInfoIfNeeded();
    }

    _scrollCtrl.addListener(_onScroll);
    _audioRecorder = sl<AudioRecorderService>();
    _imagePicker = sl<ImagePickerService>();
    if (sl.isRegistered<PushNotificationService>()) {
      sl<PushNotificationService>().activeConversationId =
          widget.conversation.id;
    }
  }

  Future<void> _loadShopInfoIfNeeded() async {
    final shopId = widget.conversation.shopId;
    if (shopId != null && shopId.isNotEmpty) {
      try {
        final res = await SupabaseService.from('shops')
            .select('id, shop_name, logo_path, is_verified, owner_id')
            .eq('id', shopId)
            .maybeSingle();
        if (res != null && mounted) {
          setState(() {
            _shopLogo = res['logo_path'] as String?;
            if (_shopName == null || _shopName!.isEmpty) {
              _shopName = res['shop_name'] as String?;
            }
            if (_shopOwnerId == null || _shopOwnerId!.isEmpty) {
              _shopOwnerId = res['owner_id'] as String?;
            }
            if (res['is_verified'] == true) {
              _isShopVerified = true;
            }
          });
        }
      } catch (e) {
        debugPrint('Error loading shop info in MessageScreen: $e');
      }
    } else {
      final otherId = _other?.id;
      if (otherId != null && otherId.isNotEmpty) {
        try {
          final res = await SupabaseService.from('shops')
              .select('id, shop_name, logo_path, is_verified, owner_id')
              .eq('owner_id', otherId)
              .maybeSingle();
          if (res != null && mounted) {
            setState(() {
              _shopLogo = res['logo_path'] as String?;
              _shopName = res['shop_name'] as String?;
              _shopOwnerId = res['owner_id'] as String?;
              if (res['is_verified'] == true) {
                _isShopVerified = true;
              }
            });
          }
        } catch (_) {}
      }
    }
  }

  @override
  void dispose() {
    if (sl.isRegistered<PushNotificationService>() &&
        sl<PushNotificationService>().activeConversationId ==
            widget.conversation.id) {
      sl<PushNotificationService>().activeConversationId = null;
    }
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    _inputFocus.dispose();
    _recordTimer?.cancel();
    if (_isRecording) {
      _audioRecorder.cancelRecording();
    }
    super.dispose();
  }

  void _onScroll() {
    // Load older messages when scrolling to top
    if (_scrollCtrl.position.pixels <= 100) {
      context.read<MessageBloc>().add(const MessageLoadMoreRequested());
    }
  }

  void _scrollToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      if (animated) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      } else {
        _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
      }
    });
  }

  void _sendText() {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    final state = context.read<MessageBloc>().state;
    final replyTo = state is MessageLoaded ? state.replyingTo : null;

    context.read<MessageBloc>().add(
      MessageSendRequested(content: text, replyToId: replyTo?.id),
    );
    _textCtrl.clear();
    _scrollToBottom();
  }

  void _sendSticker(String emoji) {
    context.read<MessageBloc>().add(
      MessageSendRequested(content: emoji, type: MessageType.sticker),
    );
    setState(() => _showEmojiPanel = false);
    _scrollToBottom();
  }

  Future<void> _pickAndSendImage(ImageSource source) async {
    final file = source == ImageSource.gallery
        ? await _imagePicker.pickFromGallery()
        : await _imagePicker.pickFromCamera();
    if (file == null || !mounted) return;
    context.read<MessageBloc>().add(
      MessageSendImageRequested(file: file, localPath: file.path),
    );
    _scrollToBottom();
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Chọn từ thư viện'),
              onTap: () {
                Navigator.pop(context);
                _pickAndSendImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Chụp ảnh'),
              onTap: () {
                Navigator.pop(context);
                _pickAndSendImage(ImageSource.camera);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── Ghi âm ──
  Future<void> _startRecording() async {
    try {
      final hasPermission = await _audioRecorder.hasPermission();
      if (!hasPermission) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cần quyền truy cập micro')),
        );
        return;
      }

      await _audioRecorder.startRecording();

      if (!mounted) return;
      setState(() {
        _isRecording = true;
        _recordDuration = Duration.zero;
      });

      _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _recordDuration += const Duration(seconds: 1));
      });
    } catch (e) {
      debugPrint('❌ Start recording error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Không thể bắt đầu ghi âm: $e')));
      setState(() => _isRecording = false);
    }
  }

  Future<void> _stopAndSendRecording() async {
    _recordTimer?.cancel();
    _recordTimer = null;

    final path = await _audioRecorder.stopRecording();

    if (!mounted) return;
    setState(() {
      _isRecording = false;
      _recordDuration = Duration.zero;
    });

    if (path != null && path.isNotEmpty) {
      context.read<MessageBloc>().add(
        MessageSendAudioRequested(localPath: path),
      );
      _scrollToBottom();
    }
  }

  Future<void> _cancelRecording() async {
    _recordTimer?.cancel();
    _recordTimer = null;

    await _audioRecorder.cancelRecording();

    if (!mounted) return;
    setState(() {
      _isRecording = false;
      _recordDuration = Duration.zero;
    });
  }

  String _formatDuration(Duration d) {
    final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final isShop = widget.conversation.isShop || (_shopName != null && _shopName!.isNotEmpty);
    final isShopOwner = widget.conversation.isShopOwner(_uid) || (_shopOwnerId == _uid);

    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          if (isShop && !isShopOwner) _buildShopCsBanner(),
          if (isShop && isShopOwner) _buildShopOwnerCsBanner(),
          // Message list
          Expanded(
            child: BlocConsumer<MessageBloc, MessageState>(
              listener: (_, state) {
                if (state is MessageLoaded && state.messages.isNotEmpty) {
                  final lastMsg = state.messages.last;
                  if (!lastMsg.isPending || lastMsg.isMine) {
                    _scrollToBottom(animated: lastMsg.isMine);
                  }
                }
              },
              builder: (ctx, state) {
                if (state is MessageLoading) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                      strokeWidth: 2,
                    ),
                  );
                }
                if (state is MessageError) {
                  return Center(
                    child: Text(
                      state.message,
                      style: const TextStyle(color: Colors.black45),
                    ),
                  );
                }
                if (state is MessageLoaded) {
                  return _buildMessageList(ctx, state);
                }
                return const SizedBox.shrink();
              },
            ),
          ),

          // Reply preview
          BlocBuilder<MessageBloc, MessageState>(
            buildWhen: (p, c) {
              final prev = p is MessageLoaded ? p.replyingTo : null;
              final curr = c is MessageLoaded ? c.replyingTo : null;
              return prev?.id != curr?.id;
            },
            builder: (ctx, state) {
              if (state is! MessageLoaded || state.replyingTo == null) {
                return const SizedBox.shrink();
              }
              final isReplyingToShop = isShop && !isShopOwner && state.replyingTo!.senderId == _shopOwnerId;
              final effectiveSenderName = isReplyingToShop
                  ? (_shopName ?? widget.conversation.shopName ?? 'Gian hàng')
                  : null;

              return _ReplyPreview(
                message: state.replyingTo!,
                senderName: effectiveSenderName,
                onDismiss: () => ctx.read<MessageBloc>().add(
                  const MessageReplySelected(null),
                ),
              );
            },
          ),

          // Emoji quick panel
          if (_showEmojiPanel) _buildEmojiPanel(),

          // Input bar
          _buildInputBar(context),
        ],
      ),
    );
  }

  // ── Shop Customer Service Banner ─────────────────────────────────────────────

  Widget _buildShopCsBanner() {
    final shopName = (_shopName != null && _shopName!.isNotEmpty)
        ? _shopName!
        : widget.conversation.getDisplayName(_uid);
    final shopId = widget.conversation.shopId;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4EE),
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFFFFCCBC).withValues(alpha: 0.6),
            width: 0.8,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              color: Color(0xFFFF5722),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.headset_mic_rounded,
              color: Colors.white,
              size: 14,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Bạn đang trò chuyện với $shopName',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFD84315),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Text(
                  'Tư vấn sản phẩm & giải đáp đơn hàng',
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          if (shopId != null && shopId.isNotEmpty)
            GestureDetector(
              onTap: () => context.push('/shop/$shopId'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF7A18), Color(0xFFFF2D55)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.storefront_rounded, size: 12, color: Colors.white),
                    SizedBox(width: 4),
                    Text(
                      'Xem Shop',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildShopOwnerCsBanner() {
    final name = (_shopName != null && _shopName!.isNotEmpty)
        ? _shopName!
        : (widget.conversation.shopName ?? 'Gian hàng');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFF86EFAC).withValues(alpha: 0.6),
            width: 0.8,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: const BoxDecoration(
              color: Color(0xFF16A34A),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.storefront_rounded,
              color: Colors.white,
              size: 13,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Bạn đang trả lời khách hàng với tư cách Shop: $name',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF15803D),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ── AppBar ──────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() {
    final other = _other;
    final isShop = widget.conversation.isShop || (_shopName != null && _shopName!.isNotEmpty);
    final isShopOwner = widget.conversation.isShopOwner(_uid) || (_shopOwnerId == _uid);
    final displayName = (isShop && !isShopOwner && _shopName != null && _shopName!.isNotEmpty)
        ? _shopName!
        : widget.conversation.getDisplayName(_uid);
    final rawAvatar = (isShop && !isShopOwner)
        ? (_shopLogo ?? widget.conversation.getAvatarUrl(_uid))
        : widget.conversation.getAvatarUrl(_uid);
    final avatarUrl = rawAvatar != null && rawAvatar.isNotEmpty
        ? StorageImage.publicUrl(rawAvatar, bucket: 'avatars')
        : null;
    final isVerified = (isShop && !isShopOwner)
        ? (_isShopVerified || widget.conversation.isVerified(_uid))
        : widget.conversation.isVerified(_uid);

    String timeAgo(DateTime dt) {
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Vừa hoạt động';
      if (diff.inMinutes < 60) return 'Hoạt động ${diff.inMinutes} phút trước';
      if (diff.inHours < 24) return 'Hoạt động ${diff.inHours} giờ trước';
      return 'Hoạt động ${diff.inDays} ngày trước';
    }

    return AppBar(
      backgroundColor: AppColors.bgLight,
      foregroundColor: Colors.black,
      elevation: 0,
      leadingWidth: 44,
      title: GestureDetector(
        onTap: () {
          if (isShop && !isShopOwner) {
            final shopId = widget.conversation.shopId;
            if (shopId != null && shopId.isNotEmpty) {
              context.push('/shop/$shopId');
            }
          } else if (other != null && other.id.isNotEmpty) {
            context.push(Routes.profileOf(other.id));
          }
        },
        behavior: HitTestBehavior.opaque,
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isShop && !isShopOwner
                    ? const Color(0xFFFFF0EC)
                    : AppColors.bgInput,
                border: Border.all(
                  color: isShop && !isShopOwner
                      ? const Color(0xFFFFCCBC)
                      : Colors.black12,
                  width: 0.8,
                ),
              ),
              child: ClipOval(
                child: avatarUrl != null
                    ? CachedNetworkImage(
                        imageUrl: avatarUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => _buildHeaderFallback(
                          displayName: displayName,
                          isShop: isShop && !isShopOwner,
                        ),
                        placeholder: (_, __) => Container(
                          color: isShop && !isShopOwner
                              ? const Color(0xFFFFF0EC)
                              : AppColors.bgInput,
                        ),
                      )
                    : _buildHeaderFallback(
                        displayName: displayName,
                        isShop: isShop && !isShopOwner,
                      ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      if (isShop && !isShopOwner) ...[
                        const SizedBox(width: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4.5,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF7A18), Color(0xFFFF2D55)],
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'SHOP',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                      if (isShop && isShopOwner) ...[
                        const SizedBox(width: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4.5,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Khách mua',
                            style: TextStyle(
                              color: Color(0xFF2E7D32),
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                      if (isVerified) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.verified_rounded,
                          color: Color(0xFF20D5EC),
                          size: 14,
                        ),
                      ],
                    ],
                  ),
                  if (isShop && !isShopOwner)
                    const Text(
                      'Gian hàng chính hãng · Chăm sóc khách hàng',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFFFF5722),
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  else
                    BlocBuilder<MessageBloc, MessageState>(
                      buildWhen: (p, c) {
                        final prev = p is MessageLoaded ? p.presenceData : null;
                        final curr = c is MessageLoaded ? c.presenceData : null;
                        return prev != curr;
                      },
                      builder: (_, state) {
                        final data = state is MessageLoaded
                            ? state.presenceData
                            : {};
                        final loaded = state is MessageLoaded
                            ? state.hasPresenceLoaded
                            : false;

                        final isOnline = loaded && data['is_online'] == true;

                        final lastSeen = data['last_seen'] != null
                            ? DateTime.parse(data['last_seen']).toLocal()
                            : null;

                        return Row(
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: isOnline ? Colors.green : Colors.grey,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                isOnline
                                    ? 'Đang hoạt động'
                                    : lastSeen != null
                                        ? timeAgo(lastSeen)
                                        : '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isOnline ? Colors.green : Colors.black45,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        IconButton(
          tooltip: 'Thông tin cuộc trò chuyện',
          icon: const Icon(Icons.info_outline),
          onPressed: () => _showConversationInfoSheet(context),
        ),
      ],
    );
  }

  Widget _buildHeaderFallback({
    required String displayName,
    required bool isShop,
  }) {
    if (isShop) {
      final initial = displayName.trim().isNotEmpty
          ? displayName.trim()[0].toUpperCase()
          : 'S';
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFF8A00), Color(0xFFFF3D00)],
          ),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            initial,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
        ),
      );
    }
    return Center(
      child: Text(
        displayName.trim().isNotEmpty ? displayName.trim()[0].toUpperCase() : '?',
        style: const TextStyle(
          color: Colors.black87,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
    );
  }

  Future<void> _showConversationInfoSheet(BuildContext context) async {
    final other = _other;
    final isShop = widget.conversation.isShop || (_shopName != null && _shopName!.isNotEmpty);
    final isShopOwner = widget.conversation.isShopOwner(_uid) || (_shopOwnerId == _uid);
    final displayName = (isShop && !isShopOwner && _shopName != null && _shopName!.isNotEmpty)
        ? _shopName!
        : widget.conversation.getDisplayName(_uid);
    final rawAvatar = (isShop && !isShopOwner)
        ? (_shopLogo ?? widget.conversation.getAvatarUrl(_uid))
        : widget.conversation.getAvatarUrl(_uid);
    final avatarUrl = rawAvatar != null && rawAvatar.isNotEmpty
        ? StorageImage.publicUrl(rawAvatar, bucket: 'avatars')
        : null;
    final shopId = widget.conversation.shopId;

    bool isMuted = false;
    try {
      final row = await SupabaseService.from('conversation_participants')
          .select('is_muted')
          .eq('conversation_id', widget.conversation.id)
          .eq('user_id', _uid)
          .maybeSingle();
      isMuted = (row?['is_muted'] as bool?) ?? false;
    } catch (_) {}

    if (!context.mounted) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isShop && !isShopOwner
                        ? const Color(0xFFFFF0EC)
                        : AppColors.bgInput,
                    border: Border.all(
                      color: isShop && !isShopOwner
                          ? const Color(0xFFFFCCBC)
                          : Colors.black12,
                      width: 0.8,
                    ),
                  ),
                  child: ClipOval(
                    child: avatarUrl != null
                        ? CachedNetworkImage(
                            imageUrl: avatarUrl,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => _buildHeaderFallback(
                              displayName: displayName,
                              isShop: isShop && !isShopOwner,
                            ),
                          )
                        : _buildHeaderFallback(
                            displayName: displayName,
                            isShop: isShop && !isShopOwner,
                          ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    if (isShop && !isShopOwner) ...[
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4.5,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF7A18), Color(0xFFFF2D55)],
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'SHOP',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  isShop && !isShopOwner
                      ? 'Gian hàng chính hãng · Chăm sóc khách hàng'
                      : '@${other?.username ?? ''}',
                  style: const TextStyle(fontSize: 13, color: Colors.black45),
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                if (isShop && !isShopOwner && shopId != null && shopId.isNotEmpty)
                  ListTile(
                    leading: const Icon(
                      Icons.storefront_rounded,
                      color: Color(0xFFFF5722),
                    ),
                    title: const Text(
                      'Xem thông tin Gian hàng Shop',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFFF5722),
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      context.push('/shop/$shopId');
                    },
                  )
                else if (other != null && other.id.isNotEmpty)
                  ListTile(
                    leading: const Icon(Icons.person_outline_rounded),
                    title: const Text(
                      'Xem trang cá nhân',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      context.push(Routes.profileOf(other.id));
                    },
                  ),
                SwitchListTile(
                  secondary: Icon(
                    isMuted
                        ? Icons.notifications_off_outlined
                        : Icons.notifications_active_outlined,
                  ),
                  title: const Text(
                    'Tắt thông báo cuộc trò chuyện',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Không hiển thị thông báo đẩy khi có tin nhắn mới',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  value: isMuted,
                  onChanged: (v) async {
                    setSheetState(() => isMuted = v);
                    try {
                      await SupabaseService.from('conversation_participants')
                          .update({'is_muted': v})
                          .eq('conversation_id', widget.conversation.id)
                          .eq('user_id', _uid);
                    } catch (_) {}
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.flag_outlined,
                    color: AppColors.error,
                  ),
                  title: const Text(
                    'Báo cáo cuộc trò chuyện',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.error,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    ReportBottomSheet.show(
                      context,
                      targetType: 'conversation',
                      targetId: widget.conversation.id,
                      title: 'Báo cáo cuộc trò chuyện',
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Message list ────────────────────────────────────────────────────────────

  Widget _buildMessageList(BuildContext ctx, MessageLoaded state) {
    final isShop = widget.conversation.isShop;
    final isShopOwner = widget.conversation.isShopOwner(_uid);
    final displayName = widget.conversation.getDisplayName(_uid);
    final rawAvatar = widget.conversation.getAvatarUrl(_uid);
    final avatarUrl = rawAvatar != null && rawAvatar.isNotEmpty
        ? StorageImage.publicUrl(rawAvatar, bucket: 'avatars')
        : null;

    if (state.messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isShop && !isShopOwner
                      ? const Color(0xFFFFF0EC)
                      : AppColors.bgInput,
                  border: Border.all(
                    color: isShop && !isShopOwner
                        ? const Color(0xFFFFCCBC)
                        : Colors.black12,
                    width: 1,
                  ),
                ),
                child: ClipOval(
                  child: avatarUrl != null
                      ? CachedNetworkImage(
                          imageUrl: avatarUrl,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => _buildHeaderFallback(
                            displayName: displayName,
                            isShop: isShop && !isShopOwner,
                          ),
                        )
                      : _buildHeaderFallback(
                          displayName: displayName,
                          isShop: isShop && !isShopOwner,
                        ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (isShop && !isShopOwner) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF7A18), Color(0xFFFF2D55)],
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'SHOP',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(
                isShop && !isShopOwner
                    ? 'Gian hàng chính hãng · Chăm sóc khách hàng'
                    : '@${_other?.username ?? ''}',
                style: const TextStyle(color: Colors.black45, fontSize: 13),
              ),
              const SizedBox(height: 16),
              Text(
                isShop && !isShopOwner
                    ? 'Gửi tin nhắn để nhận tư vấn về sản phẩm, kích cỡ, khuyến mãi và hỗ trợ giao vận.'
                    : 'Chưa có tin nhắn nào\nXin chào! 👋',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black45, height: 1.5),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      itemCount: state.messages.length + (state.isLoadingMore ? 1 : 0),
      itemBuilder: (ctx, i) {
        if (state.isLoadingMore && i == 0) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(8),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                  strokeWidth: 2,
                ),
              ),
            ),
          );
        }

        final idx = state.isLoadingMore ? i - 1 : i;
        final msg = state.messages[idx];
        final prevMsg = idx > 0 ? state.messages[idx - 1] : null;
        final nextMsg = idx < state.messages.length - 1
            ? state.messages[idx + 1]
            : null;

        final showAvatar =
            !msg.isMine &&
            (nextMsg == null || nextMsg.senderId != msg.senderId);
        final showTimestamp =
            prevMsg == null ||
            msg.createdAt.difference(prevMsg.createdAt).inMinutes > 10;

        final isShop = widget.conversation.isShop || (_shopName != null && _shopName!.isNotEmpty);
        final isShopOwner = widget.conversation.isShopOwner(_uid) || (_shopOwnerId == _uid);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showTimestamp) _TimestampDivider(dt: msg.createdAt),
            _MessageBubble(
              message: msg,
              showAvatar: showAvatar,
              isShopMessage: isShop && !isShopOwner,
              shopLogo: _shopLogo ?? widget.conversation.shopLogo,
              shopName: _shopName ?? widget.conversation.shopName,
              shopId: widget.conversation.shopId,
              onReply: () =>
                  ctx.read<MessageBloc>().add(MessageReplySelected(msg)),
              onDelete: msg.isMine
                  ? () => ctx.read<MessageBloc>().add(
                      MessageDeleteRequested(msg.id),
                    )
                  : null,
              onLongPress: () => _showMessageOptions(ctx, msg),
            ),
          ],
        );
      },
    );
  }

  // ── Input bar ───────────────────────────────────────────────────────────────

  Widget _buildInputBar(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 8,
        right: 8,
        top: 8,
        bottom: 8 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.bgLight,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: _isRecording
          ? _buildRecordingBar()
          : Row(
              children: [
                // Attachment → mở sheet chọn ảnh/camera
                IconButton(
                  icon: const Icon(
                    Icons.add_circle_outline,
                    color: Colors.black54,
                    size: 26,
                  ),
                  onPressed: _showImageSourceSheet,
                ),

                // Text field
                Expanded(
                  child: TextField(
                    controller: _textCtrl,
                    focusNode: _inputFocus,
                    maxLines: 5,
                    minLines: 1,
                    style: const TextStyle(color: Colors.black87, fontSize: 15),
                    decoration: InputDecoration(
                      hintText: 'Nhập tin nhắn...',
                      hintStyle: const TextStyle(color: Colors.black45),
                      filled: true,
                      fillColor: const Color(0xFFF2F2F2),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      suffixIcon: GestureDetector(
                        onTap: () {
                          setState(() => _showEmojiPanel = !_showEmojiPanel);
                          if (_showEmojiPanel) {
                            FocusScope.of(context).unfocus();
                          } else {
                            _inputFocus.requestFocus();
                          }
                        },
                        child: Icon(
                          _showEmojiPanel
                              ? Icons.keyboard_alt_outlined
                              : Icons.emoji_emotions_outlined,
                          color: Colors.black45,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // Send hoặc Mic (chỉ rebuild nút này khi gõ phím)
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _textCtrl,
                  builder: (_, value, __) => value.text.trim().isNotEmpty
                      ? GestureDetector(
                          onTap: _sendText,
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.send_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        )
                      : GestureDetector(
                          onLongPressStart: (_) => _startRecording(),
                          onLongPressEnd: (_) => _stopAndSendRecording(),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.mic_outlined,
                              color: Colors.black54,
                              size: 22,
                            ),
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildRecordingBar() {
    return Row(
      children: [
        // Huỷ
        GestureDetector(
          onTap: _cancelRecording,
          child: Container(
            padding: const EdgeInsets.all(10),
            child: const Icon(
              Icons.delete_outline,
              color: AppColors.error,
              size: 26,
            ),
          ),
        ),
        const SizedBox(width: 8),

        // Waveform + timer
        Expanded(
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF2F2F2),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                const RecordingWave(),
                const Spacer(),
                Text(
                  _formatDuration(_recordDuration),
                  style: const TextStyle(
                    color: AppColors.error,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),

        // Gửi
        GestureDetector(
          onTap: _stopAndSendRecording,
          child: Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.send_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ],
    );
  }

  // ── Emoji quick panel ───────────────────────────────────────────────────────

  Widget _buildEmojiPanel() {
    const emojis = [
      '😂',
      '❤️',
      '🔥',
      '😍',
      '👏',
      '🎉',
      '💯',
      '🙏',
      '😊',
      '🤩',
      '💪',
      '✨',
      '😭',
      '🫡',
      '🤣',
      '👑',
    ];
    return Container(
      height: 80,
      color: AppColors.bgLight,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        itemCount: emojis.length,
        itemBuilder: (_, i) => GestureDetector(
          onTap: () => _sendSticker(emojis[i]),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(emojis[i], style: const TextStyle(fontSize: 32)),
          ),
        ),
      ),
    );
  }

  // ── Message options ─────────────────────────────────────────────────────────

  void _showMessageOptions(BuildContext ctx, MessageEntity msg) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (bottomSheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            // Quick reactions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: ['❤️', '😂', '😍', '🔥', '👏', '😮']
                    .map(
                      (e) => GestureDetector(
                        onTap: () {
                          Navigator.pop(bottomSheetContext);
                        },
                        child: Text(e, style: const TextStyle(fontSize: 28)),
                      ),
                    )
                    .toList(),
              ),
            ),
            const Divider(color: AppColors.divider, height: 24),
            ListTile(
              leading: const Icon(Icons.reply_rounded, color: Colors.black87),
              title: const Text(
                'Reply',
                style: TextStyle(color: Colors.black87),
              ),
              onTap: () {
                Navigator.pop(bottomSheetContext);
                ctx.read<MessageBloc>().add(MessageReplySelected(msg));
                _inputFocus.requestFocus();
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy_rounded, color: Colors.black87),
              title: const Text(
                'Sao chép',
                style: TextStyle(color: Colors.black87),
              ),
              onTap: () {
                Clipboard.setData(ClipboardData(text: msg.content ?? ''));
                Navigator.pop(bottomSheetContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Đã sao chép vào bảng nhớ tạm'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
            ),
            if (msg.isMine)
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: AppColors.error,
                ),
                title: const Text(
                  'Xóa',
                  style: TextStyle(color: AppColors.error),
                ),
                onTap: () {
                  Navigator.pop(bottomSheetContext);
                  ctx.read<MessageBloc>().add(MessageDeleteRequested(msg.id));
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ─── Message bubble ────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final MessageEntity message;
  final bool showAvatar;
  final bool isShopMessage;
  final String? shopLogo;
  final String? shopName;
  final String? shopId;
  final VoidCallback onReply;
  final VoidCallback? onDelete;
  final VoidCallback onLongPress;

  const _MessageBubble({
    required this.message,
    required this.showAvatar,
    this.isShopMessage = false,
    this.shopLogo,
    this.shopName,
    this.shopId,
    required this.onReply,
    this.onDelete,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    if (message.isDeleted) return _buildDeleted();

    final shopAvatarUrl = (shopLogo != null && shopLogo!.isNotEmpty)
        ? StorageImage.publicUrl(shopLogo, bucket: 'avatars')
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        crossAxisAlignment: message.isMine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          // Nếu là tin nhắn nhận từ Shop và có hiển thị avatar (đầu cụm tin nhắn)
          if (!message.isMine && isShopMessage && showAvatar) ...[
            Padding(
              padding: const EdgeInsets.only(left: 36, bottom: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    (shopName != null && shopName!.isNotEmpty)
                        ? shopName!
                        : 'Gian hàng chính hãng',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFE65100),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF7A18), Color(0xFFFF2D55)],
                      ),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: const Text(
                      'SHOP',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: message.isMine
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            children: [
              // Other user / Shop avatar
              if (!message.isMine)
                SizedBox(
                  width: 32,
                  child: showAvatar
                      ? (isShopMessage
                          ? GestureDetector(
                              onTap: () {
                                if (shopId != null && shopId!.isNotEmpty) {
                                  context.push('/shop/$shopId');
                                }
                              },
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFFFFF0EC),
                                  border: Border.all(
                                    color: const Color(0xFFFFCCBC),
                                    width: 0.8,
                                  ),
                                ),
                                child: ClipOval(
                                  child: shopAvatarUrl != null
                                      ? CachedNetworkImage(
                                          imageUrl: shopAvatarUrl,
                                          fit: BoxFit.cover,
                                          errorWidget: (_, __, ___) => _buildShopInitial(),
                                          placeholder: (_, __) =>
                                              const ColoredBox(color: Color(0xFFFFF0EC)),
                                        )
                                      : _buildShopInitial(),
                                ),
                              ),
                            )
                          : CircleAvatar(
                              radius: 14,
                              backgroundColor: AppColors.bgInput,
                              backgroundImage: message.sender.avatarUrl != null
                                  ? CachedNetworkImageProvider(
                                      message.sender.avatarUrl!,
                                    )
                                  : null,
                              child: message.sender.avatarUrl == null
                                  ? Text(
                                      message.sender.username.isNotEmpty
                                          ? message.sender.username[0].toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                        color: Colors.black87,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    )
                                  : null,
                            ))
                      : null,
                ),

              const SizedBox(width: 4),

              // Bubble
              GestureDetector(
            onLongPress: onLongPress,
            child: Column(
              crossAxisAlignment: message.isMine
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                // Reply preview in bubble
                if (message.replyTo != null) _buildReplyPreviewInBubble(),

                // Sticker
                if (message.type == MessageType.sticker)
                  Text(
                    message.content ?? '',
                    style: const TextStyle(fontSize: 48),
                  )
                // Image
                else if (message.type == MessageType.image)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _buildImageBubble(
                      message.mediaUrl ?? message.content ?? '',
                    ),
                  )
                else if (message.type == MessageType.audio)
                  _AudioBubble(
                    audioUrl: message.mediaUrl ?? message.content ?? '',
                    isMine: message.isMine,
                    isPending: message.isPending,
                  )
                // Text
                else
                  Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.70,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: message.isMine
                          ? AppColors.primary
                          : AppColors.textMuted,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: Radius.circular(message.isMine ? 18 : 4),
                        bottomRight: Radius.circular(message.isMine ? 4 : 18),
                      ),
                      border: message.hasFailed
                          ? Border.all(color: AppColors.error)
                          : null,
                    ),
                    child: Text(
                      message.content ?? '',
                      style: TextStyle(
                        color: message.isMine ? Colors.white : Colors.black87,
                        fontSize: 15,
                        height: 1.4,
                      ),
                    ),
                  ),

                // Status + time
                const SizedBox(height: 3),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _fmt(message.createdAt),
                      style: const TextStyle(
                        color: Colors.black45,
                        fontSize: 10,
                      ),
                    ),
                    if (message.isMine) ...[
                      const SizedBox(width: 4),
                      Icon(
                        message.hasFailed
                            ? Icons.error_outline
                            : message.isPending
                            ? Icons.access_time
                            : Icons.done_all,
                        size: 12,
                        color: message.hasFailed
                            ? AppColors.error
                            : message.isPending
                            ? Colors.black45
                            : AppColors.primary,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
    ],
  ),
);
  }

  Widget _buildShopInitial() {
    final initial = (shopName != null && shopName!.trim().isNotEmpty)
        ? shopName!.trim()[0].toUpperCase()
        : 'S';
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF8A00), Color(0xFFFF3D00)],
        ),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _buildImageBubble(String url) {
    if (url.isEmpty) return const SizedBox(width: 220, height: 160);

    // Local file (optimistic/pending upload)
    if (!url.startsWith('http')) {
      return Image.file(
        File(url),
        width: 220,
        height: 160,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const _ImageErrorPlaceholder(),
      );
    }

    // Remote URL
    return CachedNetworkImage(
      imageUrl: url,
      width: 220,
      height: 160,
      fit: BoxFit.cover,
      placeholder: (_, _) => const _ImageLoadingPlaceholder(),
      errorWidget: (_, _, _) => const _ImageErrorPlaceholder(),
    );
  }

  Widget _buildDeleted() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 40),
    child: Align(
      alignment: message.isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.bgInput,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.block, color: Colors.white24, size: 13),
            const SizedBox(width: 4),
            const Text(
              'Đã xóa tin nhắn',
              style: TextStyle(
                color: Colors.black45,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _buildReplyPreviewInBubble() {
    final isReplyFromShop = isShopMessage && message.replyTo != null;
    final replySenderName = isReplyFromShop
        ? (shopName ?? 'Gian hàng')
        : message.replyTo!.sender.username;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color: isShopMessage ? const Color(0xFFFF5722) : AppColors.primary,
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            replySenderName,
            style: TextStyle(
              color: isShopMessage ? const Color(0xFFE65100) : AppColors.primary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            message.replyTo!.displayContent,
            style: const TextStyle(color: Colors.black54, fontSize: 12),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime dt) {
    final local = dt.toLocal();

    final now = DateTime.now();

    if (local.year == now.year &&
        local.month == now.month &&
        local.day == now.day) {
      return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    }

    return '${local.day}/${local.month} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}

// ─── Reply preview bar ─────────────────────────────────────────────────────────

class _ReplyPreview extends StatelessWidget {
  final MessageEntity message;
  final VoidCallback onDismiss;
  final String? senderName;

  const _ReplyPreview({
    required this.message,
    required this.onDismiss,
    this.senderName,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    color: AppColors.bgLight,
    child: Row(
      children: [
        Container(
          width: 3,
          height: 40,
          color: senderName != null ? const Color(0xFFFF5722) : AppColors.primary,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                senderName != null ? 'Trả lời $senderName' : 'Trả lời @${message.sender.username}',
                style: TextStyle(
                  color: senderName != null ? const Color(0xFFE65100) : AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                message.displayContent,
                style: const TextStyle(color: Colors.black54, fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: onDismiss,
          child: const Icon(Icons.close, color: Colors.black45, size: 20),
        ),
      ],
    ),
  );
}

// ─── Timestamp divider ─────────────────────────────────────────────────────────

class _TimestampDivider extends StatelessWidget {
  final DateTime dt;

  const _TimestampDivider({required this.dt});

  String _label() {
    final local = dt.toLocal();

    final now = DateTime.now();

    final today = DateTime(now.year, now.month, now.day);

    final yesterday = today.subtract(const Duration(days: 1));

    final msgDay = DateTime(local.year, local.month, local.day);

    if (msgDay == today) return 'Hôm nay';

    if (msgDay == yesterday) return 'Hôm qua';

    return '${local.day}/${local.month}/${local.year}';
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Row(
      children: [
        const Expanded(child: Divider(color: AppColors.divider)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            _label(),
            style: const TextStyle(color: Colors.black45, fontSize: 11),
          ),
        ),
        const Expanded(child: Divider(color: AppColors.divider)),
      ],
    ),
  );
}

class _AudioBubble extends StatefulWidget {
  final String audioUrl;
  final bool isMine;
  final bool isPending;

  const _AudioBubble({
    required this.audioUrl,
    required this.isMine,
    this.isPending = false,
  });

  @override
  State<_AudioBubble> createState() => _AudioBubbleState();
}

class _AudioBubbleState extends State<_AudioBubble> {
  late AudioPlayer _player;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  StreamSubscription? _playerSub;
  StreamSubscription? _positionSub;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _init();
  }

  @override
  void didUpdateWidget(covariant _AudioBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.audioUrl != widget.audioUrl && widget.audioUrl.isNotEmpty) {
      _playerSub?.cancel();
      _positionSub?.cancel();
      _init();
    }
  }

  Future<void> _init() async {
    if (widget.audioUrl.isEmpty) return;

    try {
      if (widget.audioUrl.startsWith('/')) {
        await _player.setFilePath(widget.audioUrl);
      } else {
        await _player.setUrl(widget.audioUrl);
      }
      final dur = await _player.load();
      if (!mounted) return;
      if (dur != null) setState(() => _duration = dur);
    } catch (e) {
      debugPrint('Audio init error: $e');
    }

    if (!mounted) return;
    _playerSub = _player.playerStateStream.listen((s) {
      if (!mounted) return;
      setState(() => _isPlaying = s.playing);
      if (s.processingState == ProcessingState.completed) {
        _player.pause();
        _player.seek(Duration.zero);
        if (mounted) setState(() => _isPlaying = false);
      }
    });
    _positionSub = _player.positionStream.listen((p) {
      if (mounted) setState(() => _position = p);
    });
  }

  @override
  void dispose() {
    _playerSub?.cancel();
    _positionSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  String _fmt(Duration d) {
    final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final progress = _duration.inMilliseconds > 0
        ? _position.inMilliseconds / _duration.inMilliseconds
        : 0.0;

    return Container(
      width: 220,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: widget.isMine ? AppColors.primary : AppColors.textMuted,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(widget.isMine ? 18 : 4),
          bottomRight: Radius.circular(widget.isMine ? 4 : 18),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              if (_isPlaying) {
                _player.pause();
              } else {
                _player.play();
              }
            },
            child: Icon(
              _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
              color: Colors.white,
              size: 34,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    backgroundColor: Colors.white30,
                    valueColor: const AlwaysStoppedAnimation(Colors.white),
                    minHeight: 3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.isPending
                      ? '...'
                      : _fmt(_isPlaying ? _position : _duration),
                  style: const TextStyle(color: Colors.white70, fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageLoadingPlaceholder extends StatelessWidget {
  const _ImageLoadingPlaceholder();

  @override
  Widget build(BuildContext context) => Container(
    width: 220,
    height: 160,
    color: AppColors.bgInput,
    child: const Center(
      child: CircularProgressIndicator(
        color: AppColors.primary,
        strokeWidth: 2,
      ),
    ),
  );
}

class _ImageErrorPlaceholder extends StatelessWidget {
  const _ImageErrorPlaceholder();

  @override
  Widget build(BuildContext context) => Container(
    width: 220,
    height: 160,
    color: AppColors.bgInput,
    child: const Center(
      child: Icon(Icons.broken_image_outlined, color: Colors.black26, size: 32),
    ),
  );
}
