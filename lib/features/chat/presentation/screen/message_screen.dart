// features/chat/presentation/screen/message_screen.dart

import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shareco/core/services/media/audio_recorder_service.dart';
import 'package:shareco/core/services/media/image_picker_service.dart';
import 'package:shareco/features/chat/presentation/bloc/message_event.dart';
import 'package:shareco/features/chat/presentation/widgets/recording_wave.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
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

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    _audioRecorder = sl<AudioRecorderService>();
    _imagePicker = sl<ImagePickerService>();
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    _inputFocus.dispose();
    _recordTimer?.cancel();
    _audioRecorder.dispose();
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
    if (file == null) return;
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
      print('❌ Start recording error: $e');
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
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: _buildAppBar(),
      body: Column(
        children: [
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
              return _ReplyPreview(
                message: state.replyingTo!,
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

  // ── AppBar ──────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() {
    final other = _other;
    String _timeAgo(DateTime dt) {
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
        onTap: () {}, // navigate to profile
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.bgInput,
              backgroundImage: other?.avatarUrl != null
                  ? CachedNetworkImageProvider(other!.avatarUrl!)
                  : null,
              child: other?.avatarUrl == null
                  ? Text(
                      (other?.username ?? '?')[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    other?.displayName.isNotEmpty == true
                        ? other!.displayName
                        : (other?.username ?? 'Unknown'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
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
                            width: 8,
                            height: 8,
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
                                  ? _timeAgo(lastSeen)
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
        IconButton(icon: const Icon(Icons.info_outline), onPressed: () {}),
      ],
    );
  }

  // ── Message list ────────────────────────────────────────────────────────────

  Widget _buildMessageList(BuildContext ctx, MessageLoaded state) {
    if (state.messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: AppColors.bgInput,
              backgroundImage: _other?.avatarUrl != null
                  ? CachedNetworkImageProvider(_other!.avatarUrl!)
                  : null,
              child: _other?.avatarUrl == null
                  ? Text(
                      (_other?.username ?? '?')[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 12),
            Text(
              _other?.displayName.isNotEmpty == true
                  ? _other!.displayName
                  : (_other?.username ?? 'Unknown'),
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '@${_other?.username ?? ''}',
              style: const TextStyle(color: Colors.black45, fontSize: 13),
            ),
            const SizedBox(height: 16),
            const Text(
              'Chưa có tin nhắn nào\nXin chào! 👋',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black45, height: 1.6),
            ),
          ],
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
        print('''
   Message ${idx + 1}/${state.messages.length}
   ID       : ${msg.id}
   Type     : ${msg.type}
   Content  : ${msg.content}
   MediaURL : ${msg.mediaUrl}
   IsMine   : ${msg.isMine}
   IsPending: ${msg.isPending}
   CreatedAt: ${msg.createdAt}
  ────────────────────────────────
  ''');
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

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showTimestamp) _TimestampDivider(dt: msg.createdAt),
            _MessageBubble(
              message: msg,
              showAvatar: showAvatar,
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
                    onChanged: (_) => setState(() {}),
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

                // Send hoặc Mic
                _textCtrl.text.trim().isNotEmpty
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
  final VoidCallback onReply;
  final VoidCallback? onDelete;
  final VoidCallback onLongPress;

  const _MessageBubble({
    required this.message,
    required this.showAvatar,
    required this.onReply,
    this.onDelete,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    if (message.isDeleted) return _buildDeleted();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: message.isMine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          // Other user avatar
          if (!message.isMine)
            SizedBox(
              width: 32,
              child: showAvatar
                  ? CircleAvatar(
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
                    )
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

  Widget _buildReplyPreviewInBubble() => Container(
    margin: const EdgeInsets.only(bottom: 6),
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: Colors.black.withOpacity(0.06),
      borderRadius: BorderRadius.circular(8),
      border: const Border(
        left: BorderSide(color: AppColors.primary, width: 3),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          message.replyTo!.sender.username,
          style: const TextStyle(
            color: AppColors.primary,
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

  const _ReplyPreview({required this.message, required this.onDismiss});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    color: AppColors.bgLight,
    child: Row(
      children: [
        Container(width: 3, height: 40, color: AppColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Trả lời @${message.sender.username}',
                style: const TextStyle(
                  color: AppColors.primary,
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

  Future<void> _init() async {
    if (widget.audioUrl.isEmpty) return;

    try {
      if (widget.audioUrl.startsWith('/')) {
        await _player.setFilePath(widget.audioUrl);
      } else {
        await _player.setUrl(widget.audioUrl);
      }
      final dur = await _player.load();
      if (dur != null) setState(() => _duration = dur);
    } catch (e) {
      print('Audio init error: $e');
    }

    _playerSub = _player.playerStateStream.listen((s) {
      setState(() => _isPlaying = s.playing);
      if (s.processingState == ProcessingState.completed) {
        _player.pause();
        _player.seek(Duration.zero);
        setState(() => _isPlaying = false);
      }
    });
    _positionSub = _player.positionStream.listen((p) {
      setState(() => _position = p);
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
