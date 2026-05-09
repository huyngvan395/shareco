// features/chat/presentation/screen/message_screen.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shareco/features/chat/presentation/bloc/message_event.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/services/supabase/index.dart';
import '../../../../di/injector.dart';
import '../../../../shared/domain/entities/base_entity.dart';
import '../../domain/entities/chat_entities.dart';
import '../bloc/message_bloc.dart';
import '../bloc/message_state.dart';

class MessageScreen extends StatelessWidget {
  final ConversationEntity conversation;
  const MessageScreen({super.key, required this.conversation});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => MessageBloc(
        getMessages: sl(),
        sendMessage: sl(),
        deleteMessage: sl(),
        markAsRead: sl(),
        watchMessages: sl(),
      )..add(MessageLoadRequested(conversation.id)),
      child: _MessageView(conversation: conversation),
    );
  }
}

class _MessageView extends StatefulWidget {
  final ConversationEntity conversation;
  const _MessageView({required this.conversation});
  @override State<_MessageView> createState() => _MessageViewState();
}

class _MessageViewState extends State<_MessageView> {
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _inputFocus = FocusNode();
  bool _showEmojiPanel = false;

  String get _uid => SupabaseService.currentUserId ?? '';

  ProfileStub? get _other =>
      widget.conversation.otherUser(_uid);

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    _inputFocus.dispose();
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

    context.read<MessageBloc>().add(MessageSendRequested(
      content: text,
      replyToId: replyTo?.id,
    ));
    _textCtrl.clear();
    _scrollToBottom();
  }

  void _sendSticker(String emoji) {
    context.read<MessageBloc>().add(MessageSendRequested(
      content: emoji,
      type: MessageType.sticker,
    ));
    setState(() => _showEmojiPanel = false);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: _buildAppBar(),
      body: Column(children: [
        // Message list
        Expanded(
          child: BlocConsumer<MessageBloc, MessageState>(
            listener: (_, state) {
              if (state is MessageLoaded && state.messages.isNotEmpty) {
                _scrollToBottom(animated: false);
              }
            },
            builder: (ctx, state) {
              if (state is MessageLoading) {
                return const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primary, strokeWidth: 2));
              }
              if (state is MessageError) {
                return Center(
                    child: Text(state.message,
                        style: const TextStyle(color: Colors.white38)));
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
              onDismiss: () => ctx
                  .read<MessageBloc>()
                  .add(const MessageReplySelected(null)),
            );
          },
        ),

        // Emoji quick panel
        if (_showEmojiPanel) _buildEmojiPanel(),

        // Input bar
        _buildInputBar(context),
      ]),
    );
  }

  // ── AppBar ──────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() {
    final other = _other;
    return AppBar(
      backgroundColor: AppColors.bgCard,
      foregroundColor: Colors.white,
      leadingWidth: 44,
      title: GestureDetector(
        onTap: () {}, // navigate to profile
        child: Row(children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.bgInput,
            backgroundImage: other?.avatarUrl != null
                ? CachedNetworkImageProvider(other!.avatarUrl!) : null,
            child: other?.avatarUrl == null
                ? Text((other?.username ?? '?')[0].toUpperCase(),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))
                : null,
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              other?.displayName.isNotEmpty == true
                  ? other!.displayName : (other?.username ?? 'Unknown'),
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700),
            ),
            Row(children: [
              Container(width: 8, height: 8,
                  decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
              const SizedBox(width: 4),
              const Text('Active now',
                  style: TextStyle(fontSize: 11, color: Colors.green)),
            ]),
          ]),
        ]),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.videocam_outlined),
          onPressed: () {},
        ),
        IconButton(
          icon: const Icon(Icons.call_outlined),
          onPressed: () {},
        ),
        IconButton(
          icon: const Icon(Icons.info_outline),
          onPressed: () {},
        ),
      ],
    );
  }

  // ── Message list ────────────────────────────────────────────────────────────

  Widget _buildMessageList(BuildContext ctx, MessageLoaded state) {
    if (state.messages.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: AppColors.bgInput,
            backgroundImage: _other?.avatarUrl != null
                ? CachedNetworkImageProvider(_other!.avatarUrl!) : null,
            child: _other?.avatarUrl == null
                ? Text((_other?.username ?? '?')[0].toUpperCase(),
                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700))
                : null,
          ),
          const SizedBox(height: 12),
          Text(
            _other?.displayName.isNotEmpty == true
                ? _other!.displayName : (_other?.username ?? 'Unknown'),
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text('@${_other?.username ?? ''}',
              style: const TextStyle(color: Colors.white38, fontSize: 13)),
          const SizedBox(height: 16),
          const Text('No messages yet\nSay hello! 👋',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white38, height: 1.6)),
        ]),
      );
    }

    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      itemCount: state.messages.length +
          (state.isLoadingMore ? 1 : 0),
      itemBuilder: (ctx, i) {
        if (state.isLoadingMore && i == 0) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(8),
              child: SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(
                      color: AppColors.primary, strokeWidth: 2)),
            ),
          );
        }

        final idx = state.isLoadingMore ? i - 1 : i;
        final msg = state.messages[idx];
        final prevMsg = idx > 0 ? state.messages[idx - 1] : null;
        final nextMsg = idx < state.messages.length - 1
            ? state.messages[idx + 1] : null;

        final showAvatar = !msg.isMine &&
            (nextMsg == null || nextMsg.senderId != msg.senderId);
        final showTimestamp = prevMsg == null ||
            msg.createdAt.difference(prevMsg.createdAt).inMinutes > 10;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showTimestamp) _TimestampDivider(dt: msg.createdAt),
            _MessageBubble(
              message: msg,
              showAvatar: showAvatar,
              onReply: () => ctx
                  .read<MessageBloc>()
                  .add(MessageReplySelected(msg)),
              onDelete: msg.isMine
                  ? () => ctx
                  .read<MessageBloc>()
                  .add(MessageDeleteRequested(msg.id))
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
        left: 8, right: 8, top: 8,
        bottom: 8 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.bgCard,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Row(children: [
        // Attachment
        IconButton(
          icon: const Icon(Icons.add_circle_outline,
              color: Colors.white54, size: 26),
          onPressed: () {},
        ),

        // Text field
        Expanded(
          child: BlocBuilder<MessageBloc, MessageState>(
            buildWhen: (p, c) => false,
            builder: (_, __) => TextField(
              controller: _textCtrl,
              focusNode: _inputFocus,
              maxLines: 5, minLines: 1,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Message...',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: AppColors.bgInput,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none),
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
                      color: Colors.white38, size: 20),
                ),
              ),
            ),
          ),
        ),

        const SizedBox(width: 8),

        // Send / audio button
        _textCtrl.text.trim().isNotEmpty
            ? GestureDetector(
          onTap: _sendText,
          child: Container(
            width: 44, height: 44,
            decoration: const BoxDecoration(
                color: AppColors.primary, shape: BoxShape.circle),
            child: const Icon(Icons.send_rounded,
                color: Colors.white, size: 20),
          ),
        )
            : GestureDetector(
          onTap: () {},
          child: Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                shape: BoxShape.circle),
            child: const Icon(Icons.mic_outlined,
                color: Colors.white54, size: 22),
          ),
        ),
      ]),
    );
  }

  // ── Emoji quick panel ───────────────────────────────────────────────────────

  Widget _buildEmojiPanel() {
    const emojis = [
      '😂','❤️','🔥','😍','👏','🎉','💯','🙏',
      '😊','🤩','💪','✨','😭','🫡','🤣','👑',
    ];
    return Container(
      height: 80,
      color: AppColors.bgCard,
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
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (bottomSheetContext) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          Container(width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.white24,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 12),
          // Quick reactions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: ['❤️', '😂', '😍', '🔥', '👏', '😮']
                  .map((e) => GestureDetector(
                onTap: () { Navigator.pop(bottomSheetContext); },
                child: Text(e, style: const TextStyle(fontSize: 28)),
              ))
                  .toList(),
            ),
          ),
          const Divider(color: AppColors.divider, height: 24),
          ListTile(
            leading: const Icon(Icons.reply_rounded, color: Colors.white),
            title: const Text('Reply', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(bottomSheetContext);
              ctx.read<MessageBloc>().add(MessageReplySelected(msg));
              _inputFocus.requestFocus();
            },
          ),
          ListTile(
            leading: const Icon(Icons.copy_rounded, color: Colors.white),
            title: const Text('Copy', style: TextStyle(color: Colors.white)),
            onTap: () {
              Clipboard.setData(ClipboardData(text: msg.content ?? ''));
              Navigator.pop(bottomSheetContext);
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied to clipboard'), duration: Duration(seconds: 1)));
            },
          ),
          if (msg.isMine)
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.error),
              title: const Text('Delete', style: TextStyle(color: AppColors.error)),
              onTap: () {
                Navigator.pop(bottomSheetContext);
                ctx.read<MessageBloc>().add(MessageDeleteRequested(msg.id));
              },
            ),
          const SizedBox(height: 8),
        ]),
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
            ? MainAxisAlignment.end : MainAxisAlignment.start,
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
                    ? CachedNetworkImageProvider(message.sender.avatarUrl!)
                    : null,
                child: message.sender.avatarUrl == null
                    ? Text(
                    message.sender.username.isNotEmpty
                        ? message.sender.username[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 10,
                        fontWeight: FontWeight.w700))
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
                  ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                // Reply preview in bubble
                if (message.replyTo != null) _buildReplyPreviewInBubble(),

                // Sticker
                if (message.type == MessageType.sticker)
                  Text(message.content ?? '',
                      style: const TextStyle(fontSize: 48))

                // Image
                else if (message.type == MessageType.image)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                        imageUrl: message.mediaUrl ?? '',
                        width: 220, height: 160, fit: BoxFit.cover),
                  )

                // Text
                else
                  Container(
                    constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.70),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: message.isMine
                          ? AppColors.primary
                          : AppColors.bgCard,
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
                    child: Text(message.content ?? '',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 15, height: 1.4)),
                  ),

                // Status + time
                const SizedBox(height: 3),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_fmt(message.createdAt),
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 10)),
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
                            ? Colors.white38
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
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.block, color: Colors.white24, size: 13),
          const SizedBox(width: 4),
          const Text('Message deleted',
              style: TextStyle(color: Colors.white38, fontSize: 12,
                  fontStyle: FontStyle.italic)),
        ]),
      ),
    ),
  );

  Widget _buildReplyPreviewInBubble() => Container(
    margin: const EdgeInsets.only(bottom: 6),
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: Colors.black26,
      borderRadius: BorderRadius.circular(8),
      border: const Border(
          left: BorderSide(color: AppColors.primary, width: 3)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(message.replyTo!.sender.username,
          style: const TextStyle(
              color: AppColors.primary, fontSize: 11,
              fontWeight: FontWeight.w600)),
      const SizedBox(height: 2),
      Text(message.replyTo!.displayContent,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
          maxLines: 2, overflow: TextOverflow.ellipsis),
    ]),
  );

  String _fmt(DateTime dt) {
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${dt.day}/${dt.month} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
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
    color: AppColors.bgCard,
    child: Row(children: [
      Container(width: 3, height: 40, color: AppColors.primary),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Reply to @${message.sender.username}',
                style: const TextStyle(
                    color: AppColors.primary, fontSize: 12,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(message.displayContent,
                style: const TextStyle(color: Colors.white54, fontSize: 13),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
      GestureDetector(
        onTap: onDismiss,
        child: const Icon(Icons.close, color: Colors.white38, size: 20),
      ),
    ]),
  );
}

// ─── Timestamp divider ─────────────────────────────────────────────────────────

class _TimestampDivider extends StatelessWidget {
  final DateTime dt;
  const _TimestampDivider({required this.dt});

  String _label() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final msgDay = DateTime(dt.year, dt.month, dt.day);
    if (msgDay == today) return 'Today';
    if (msgDay == yesterday) return 'Yesterday';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Row(children: [
      const Expanded(child: Divider(color: AppColors.divider)),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(_label(),
            style: const TextStyle(color: Colors.white38, fontSize: 11)),
      ),
      const Expanded(child: Divider(color: AppColors.divider)),
    ]),
  );
}