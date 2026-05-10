// features/chat/presentation/screen/chat_screen.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shareco/core/services/supabase/presence_service.dart';
import 'package:shareco/features/chat/presentation/bloc/conversation_event.dart';
import 'package:shareco/features/chat/presentation/bloc/conversation_state.dart';
import 'package:shareco/features/chat/presentation/screen/message_screen.dart';
import 'package:shareco/routes/app_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/supabase/index.dart';
import '../../../../di/injector.dart';
import '../bloc/conversation_bloc.dart';
import 'package:go_router/go_router.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ConversationBloc(
        getConversations: sl(),
        getOrCreateConversation: sl(),
        searchUsers: sl(),
      )..add(const ConversationListLoadRequested()),
      child: const _ChatView(),
    );
  }
}

class _ChatView extends StatefulWidget {
  const _ChatView();

  @override
  State<_ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<_ChatView> {
  final _searchCtrl = TextEditingController();
  bool _searchFocused = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ConversationBloc, ConversationState>(
      listener: (ctx, state) {
        if (state is ConversationNavigateTo) {
          context
              .push(Routes.messages, extra: state.conversation)
              .then(
                (_) => ctx.read<ConversationBloc>().add(
                  const ConversationRefreshRequested(),
                ),
              );
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: const Text(
            'Tin nhắn',
            style: TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w700,
              fontSize: 20,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: Colors.black87),
              onPressed: () => _showNewChatSheet(context),
            ),
          ],
        ),
        body: Column(
          children: [
            _buildSearchBar(context),
            BlocBuilder<ConversationBloc, ConversationState>(
              builder: (_, state) {
                if (state is ConversationListLoaded && !state.isSearching) {
                  return _buildActivityRow();
                }
                return const SizedBox.shrink();
              },
            ),
            Expanded(
              child: BlocBuilder<ConversationBloc, ConversationState>(
                builder: (ctx, state) {
                  if (state is ConversationLoading) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                        strokeWidth: 2,
                      ),
                    );
                  }
                  if (state is ConversationError) {
                    return _buildError(ctx, state.message);
                  }
                  if (state is ConversationListLoaded) {
                    return state.isSearching
                        ? _buildSearchResults(ctx, state)
                        : _buildList(ctx, state);
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(BuildContext ctx) => Container(
    color: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Row(
      children: [
        Expanded(
          child: TextField(
            controller: _searchCtrl,
            style: const TextStyle(color: Colors.black87),
            onChanged: (q) => ctx.read<ConversationBloc>().add(
              q.trim().isEmpty
                  ? const ConversationSearchCleared()
                  : ConversationSearchRequested(q),
            ),
            onTap: () {
              setState(() => _searchFocused = true);
              ctx.read<ConversationBloc>().add(
                const ConversationSearchRequested(''),
              );
            },
            decoration: InputDecoration(
              hintText: 'Tìm người dùng hoặc tin nhắn',
              hintStyle: const TextStyle(color: Colors.black38),
              prefixIcon: const Icon(Icons.search, color: Colors.black38),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? GestureDetector(
                      onTap: () {
                        _searchCtrl.clear();
                        ctx.read<ConversationBloc>().add(
                          const ConversationSearchCleared(),
                        );
                        FocusScope.of(context).unfocus();
                        setState(() => _searchFocused = false);
                      },
                      child: const Icon(
                        Icons.close,
                        color: Colors.black38,
                        size: 18,
                      ),
                    )
                  : null,
              filled: true,
              fillColor: const Color(0xFFF0F0F0),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        if (_searchFocused) ...[
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () {
              _searchCtrl.clear();
              ctx.read<ConversationBloc>().add(
                const ConversationSearchCleared(),
              );
              FocusScope.of(context).unfocus();
              setState(() => _searchFocused = false);
            },
            child: const Text(
              'Thoát',
              style: TextStyle(color: AppColors.primary, fontSize: 14),
            ),
          ),
        ],
      ],
    ),
  );

  Widget _buildActivityRow() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        color: Colors.white,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
              child: Row(
                children: [
                  const Text(
                    'Hoạt động',
                    style: TextStyle(
                      color: Colors.black38,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {},
                    child: const Text(
                      'Xem tất cả',
                      style: TextStyle(color: AppColors.primary, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 76,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  _ActivityBubble(
                    icon: Icons.favorite,
                    label: 'Thích',
                    color: AppColors.like,
                    count: 42,
                  ),
                  _ActivityBubble(
                    icon: Icons.chat_bubble,
                    label: 'Bình luận',
                    color: AppColors.secondary,
                    count: 8,
                  ),
                  _ActivityBubble(
                    icon: Icons.alternate_email,
                    label: 'Nhắc đến',
                    color: Colors.amber,
                    count: 3,
                  ),
                  _ActivityBubble(
                    icon: Icons.person_add,
                    label: 'Theo dõi',
                    color: AppColors.primary,
                    count: 12,
                  ),
                  _ActivityBubble(
                    icon: Icons.share,
                    label: 'Chia sẻ',
                    color: Colors.green,
                    count: 5,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
      const Divider(color: Color(0xFFE0E0E0), height: 1),
    ],
  );

  Widget _buildList(BuildContext ctx, ConversationListLoaded state) {
    if (state.conversations.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              color: Colors.black12,
              size: 64,
            ),
            SizedBox(height: 16),
            Text(
              'Chưa có cuộc hội thoại nào',
              style: TextStyle(color: Colors.black38, fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              "Nhấn ✏️ để bắt đầu cuộc trò chuyện mới",
              style: TextStyle(color: Colors.black26, fontSize: 13),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () async => ctx.read<ConversationBloc>().add(
        const ConversationRefreshRequested(),
      ),
      color: AppColors.primary,
      backgroundColor: Colors.white,
      child: ListView.builder(
        itemCount: state.conversations.length,
        itemBuilder: (_, i) {
          final conv = state.conversations[i];
          final uid = SupabaseService.currentUserId ?? '';
          final other = conv.otherUser(uid);
          return _ConvTile(
            avatarUrl: other?.avatarUrl,
            name: other?.displayName.isNotEmpty == true
                ? other!.displayName
                : (other?.username ?? 'Unknown'),
            username: other?.username ?? '',
            lastMessage: conv.lastMessage ?? 'Bắt đầu cuộc hội thoại',
            time: _timeAgo(conv.lastMessageAt ?? conv.updatedAt),
            userId: other!.id,
            hasUnread: conv.hasUnread,
            onTap: () => context
                .push(Routes.messages, extra: conv)
                .then(
                  (_) => ctx.read<ConversationBloc>().add(
                    const ConversationRefreshRequested(),
                  ),
                ),
          );
        },
      ),
    );
  }

  Widget _buildSearchResults(BuildContext ctx, ConversationListLoaded state) {
    if (state.searchQuery.isEmpty) {
      return const Center(
        child: Text(
          'Tìm kiếm người dùng để nhắn tin',
          style: TextStyle(color: Colors.black38),
        ),
      );
    }
    if (state.searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off, color: Colors.black12, size: 48),
            const SizedBox(height: 12),
            Text(
              'Không tìm thấy người dùng nào cho "${state.searchQuery}"',
              style: const TextStyle(color: Colors.black38),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      itemCount: state.searchResults.length,
      itemBuilder: (_, i) {
        final u = state.searchResults[i];
        return Container(
          color: Colors.white,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            leading: _Avatar(url: u.avatarUrl, name: u.username, size: 44),
            title: Text(
              u.displayName.isNotEmpty ? u.displayName : u.username,
              style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              '@${u.username}',
              style: const TextStyle(color: Colors.black38, fontSize: 12),
            ),
            trailing: OutlinedButton(
              onPressed: () {
                _searchCtrl.clear();
                FocusScope.of(context).unfocus();
                setState(() => _searchFocused = false);
                ctx.read<ConversationBloc>().add(
                  ConversationOpenRequested(u.id),
                );
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text(
                'Tin nhắn',
                style: TextStyle(color: AppColors.primary, fontSize: 12),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildError(BuildContext ctx, String msg) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.wifi_off_rounded, color: Colors.black12, size: 48),
        const SizedBox(height: 12),
        Text(
          msg,
          style: const TextStyle(color: Colors.black38),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => ctx.read<ConversationBloc>().add(
            const ConversationListLoadRequested(),
          ),
          child: const Text(
            'Thử lại',
            style: TextStyle(color: AppColors.primary),
          ),
        ),
      ],
    ),
  );

  void _showNewChatSheet(BuildContext ctx) => showModalBottomSheet(
    context: ctx,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => BlocProvider.value(
      value: ctx.read<ConversationBloc>(),
      child: const _NewChatSheet(),
    ),
  );

  String _timeAgo(DateTime? dt) {
    if (dt == null) return '';
    final d = DateTime.now().difference(dt);
    if (d.inDays > 6) return '${dt.day}/${dt.month}';
    if (d.inDays > 0) return '${d.inDays}d';
    if (d.inHours > 0) return '${d.inHours}h';
    if (d.inMinutes > 0) return '${d.inMinutes}m';
    return 'now';
  }
}

class _ConvTile extends StatelessWidget {
  final String? avatarUrl;
  final String name, username, lastMessage, time;
  final String userId;
  final bool hasUnread;
  final VoidCallback onTap;

  const _ConvTile({
    this.avatarUrl,
    required this.name,
    required this.username,
    required this.lastMessage,
    required this.time,
    required this.userId,
    required this.hasUnread,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Container(
    color: Colors.white,
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: StreamBuilder<Map<String, dynamic>>(
        stream: sl<PresenceService>().watchUserPresence(userId),
        builder: (_, snapshot) {
          final isOnline = snapshot.data?['is_online'] == true;
          return Stack(
            children: [
              _Avatar(url: avatarUrl, name: name, size: 50),
              Positioned(
                right: 2,
                bottom: 2,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: isOnline ? Colors.green : Colors.grey.shade400,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ],
          );
        },
      ),
      title: Text(
        name,
        style: TextStyle(
          color: Colors.black87,
          fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w500,
          fontSize: 15,
        ),
      ),
      subtitle: Text(
        lastMessage,
        style: TextStyle(
          color: hasUnread ? Colors.black54 : Colors.black38,
          fontSize: 13,
        ),
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            time,
            style: const TextStyle(color: Colors.black38, fontSize: 11),
          ),
          if (hasUnread) ...[
            const SizedBox(height: 4),
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ],
      ),
      onTap: onTap,
    ),
  );
}

class _NewChatSheet extends StatefulWidget {
  const _NewChatSheet();

  @override
  State<_NewChatSheet> createState() => _NewChatSheetState();
}

class _NewChatSheetState extends State<_NewChatSheet> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DraggableScrollableSheet(
    initialChildSize: 0.75,
    minChildSize: 0.5,
    maxChildSize: 0.95,
    expand: false,
    builder: (_, sc) => Column(
      children: [
        const SizedBox(height: 8),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.black12,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Tin nhắn mới',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _ctrl,
            autofocus: true,
            style: const TextStyle(color: Colors.black87),
            onChanged: (q) => context.read<ConversationBloc>().add(
              ConversationSearchRequested(q),
            ),
            decoration: InputDecoration(
              hintText: 'Tìm bởi tên hoặc @username',
              hintStyle: const TextStyle(color: Colors.black38),
              prefixIcon: const Icon(Icons.search, color: Colors.black38),
              filled: true,
              fillColor: const Color(0xFFF0F0F0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
        const Divider(color: Color(0xFFE0E0E0), height: 20),
        Expanded(
          child: BlocBuilder<ConversationBloc, ConversationState>(
            builder: (ctx, state) {
              if (state is! ConversationListLoaded ||
                  state.searchResults.isEmpty)
                return const SizedBox.shrink();
              return ListView.builder(
                controller: sc,
                itemCount: state.searchResults.length,
                itemBuilder: (_, i) {
                  final u = state.searchResults[i];
                  return ListTile(
                    leading: _Avatar(
                      url: u.avatarUrl,
                      name: u.username,
                      size: 44,
                    ),
                    title: Text(
                      u.displayName.isNotEmpty ? u.displayName : u.username,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      '@${u.username}',
                      style: const TextStyle(
                        color: Colors.black38,
                        fontSize: 12,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      ctx.read<ConversationBloc>().add(
                        ConversationOpenRequested(u.id),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    ),
  );
}

class _ActivityBubble extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final int count;

  const _ActivityBubble({
    required this.icon,
    required this.label,
    required this.color,
    required this.count,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 6),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            if (count > 0)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.black38, fontSize: 9)),
      ],
    ),
  );
}

class _Avatar extends StatelessWidget {
  final String? url;
  final String name;
  final double size;

  const _Avatar({this.url, required this.name, this.size = 48});

  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: size / 2,
    backgroundColor: const Color(0xFFE8E8E8),
    backgroundImage: url != null ? CachedNetworkImageProvider(url!) : null,
    child: url == null
        ? Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.w700,
              fontSize: size * 0.35,
            ),
          )
        : null,
  );
}
