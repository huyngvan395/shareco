// features/chat/presentation/screen/chat_screen.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shareco/core/services/notifications/push_notification_service.dart';
import 'package:shareco/core/services/supabase/presence_service.dart';
import 'package:shareco/core/utils/storage_image.dart';
import 'package:shareco/features/chat/presentation/bloc/conversation_event.dart';
import 'package:shareco/features/chat/presentation/bloc/conversation_state.dart';
import 'package:shareco/features/notification/presentation/screen/notification_screen.dart';
import 'package:shareco/routes/app_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/supabase/index.dart';
import '../../../../di/injector.dart';
import '../../domain/entities/chat_entities.dart';
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
  int _selectedCategoryTab = 0; // 0: Tất cả, 1: Bạn bè, 2: Tin nhắn Shop

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
              .then((_) {
                if (ctx.mounted) {
                  ctx.read<ConversationBloc>().add(
                    const ConversationRefreshRequested(),
                  );
                }
              });
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
            ListenableBuilder(
              listenable: sl<PushNotificationService>(),
              builder: (context, _) {
                final unread = sl<PushNotificationService>().unreadTotal;
                return IconButton(
                  tooltip: 'Trung tâm thông báo',
                  onPressed: () => _openNotifications(context, 'all'),
                  icon: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(
                        Icons.notifications_none_rounded,
                        color: Colors.black87,
                      ),
                      if (unread > 0)
                        Positioned(
                          right: -4,
                          top: -4,
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
                              unread > 99 ? '99+' : '$unread',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
            IconButton(
              tooltip: 'Tin nhắn mới',
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

  void _openNotifications(BuildContext context, String category) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => NotificationScreen(initialCategory: category),
      ),
    );
  }

  Widget _buildActivityRow() {
    final push = sl<PushNotificationService>();
    return ListenableBuilder(
      listenable: push,
      builder: (context, _) => Column(
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
                        onPressed: () => _openNotifications(context, 'all'),
                        child: const Text(
                          'Xem tất cả',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 80,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      _ActivityBubble(
                        icon: Icons.favorite_rounded,
                        label: 'Lượt thích',
                        color: AppColors.like,
                        count: push.unreadLikes,
                        onTap: () => _openNotifications(context, 'likes'),
                      ),
                      _ActivityBubble(
                        icon: Icons.chat_bubble_rounded,
                        label: 'Bình luận',
                        color: AppColors.secondary,
                        count: push.unreadComments,
                        onTap: () => _openNotifications(context, 'comments'),
                      ),
                      _ActivityBubble(
                        icon: Icons.alternate_email_rounded,
                        label: 'Nhắc đến',
                        color: const Color(0xFF8B5CF6),
                        count: push.unreadMentions,
                        onTap: () => _openNotifications(context, 'mentions'),
                      ),
                      _ActivityBubble(
                        icon: Icons.sensors_rounded,
                        label: 'Follow & Live',
                        color: AppColors.primary,
                        count: push.unreadFollowsAndLive,
                        onTap: () =>
                            _openNotifications(context, 'follows_live'),
                      ),
                      _ActivityBubble(
                        icon: Icons.local_shipping_rounded,
                        label: 'Đơn hàng & Ví',
                        color: const Color(0xFFF97316),
                        count: push.unreadOrdersAndWallet,
                        onTap: () => _openNotifications(context, 'orders'),
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
      ),
    );
  }

  Widget _buildList(BuildContext ctx, ConversationListLoaded state) {
    final uid = SupabaseService.currentUserId ?? '';
    final filteredConversations = switch (_selectedCategoryTab) {
      1 => state.conversations.where((c) => !c.isShop).toList(),
      2 => state.conversations.where((c) => c.isShop).toList(),
      _ => state.conversations,
    };

    return Column(
      children: [
        _buildChatCategoryTabs(state.conversations),
        const Divider(color: Color(0xFFEFEFEF), height: 1),
        Expanded(
          child: filteredConversations.isEmpty
              ? _buildEmptyStateForCategory()
              : RefreshIndicator(
                  onRefresh: () async => ctx.read<ConversationBloc>().add(
                    const ConversationRefreshRequested(),
                  ),
                  color: AppColors.primary,
                  backgroundColor: Colors.white,
                  child: ListView.separated(
                    itemCount: filteredConversations.length,
                    separatorBuilder: (_, __) => const Divider(
                      height: 1,
                      indent: 74,
                      color: Color(0xFFF5F5F5),
                    ),
                    itemBuilder: (_, i) {
                      final conv = filteredConversations[i];
                      return _ConvTile(
                        conv: conv,
                        currentUserId: uid,
                        time: _timeAgo(conv.lastMessageAt ?? conv.updatedAt),
                        onTap: () => context
                            .push(Routes.messages, extra: conv)
                            .then((_) {
                              if (ctx.mounted) {
                                ctx.read<ConversationBloc>().add(
                                  const ConversationRefreshRequested(),
                                );
                              }
                            }),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildChatCategoryTabs(List<ConversationEntity> allList) {
    final unreadAll = allList.where((c) => c.hasUnread).length;
    final unreadDirect = allList.where((c) => !c.isShop && c.hasUnread).length;
    final unreadShop = allList.where((c) => c.isShop && c.hasUnread).length;
    final shopCount = allList.where((c) => c.isShop).length;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: Row(
        children: [
          _buildFilterPill(
            index: 0,
            label: 'Tất cả',
            unreadCount: unreadAll,
          ),
          const SizedBox(width: 8),
          _buildFilterPill(
            index: 1,
            label: 'Bạn bè',
            unreadCount: unreadDirect,
          ),
          const SizedBox(width: 8),
          _buildFilterPill(
            index: 2,
            icon: Icons.storefront_rounded,
            label: shopCount > 0 ? 'Shop ($shopCount)' : 'Tin nhắn Shop',
            unreadCount: unreadShop,
            isShopTab: true,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterPill({
    required int index,
    required String label,
    IconData? icon,
    int unreadCount = 0,
    bool isShopTab = false,
  }) {
    final isSelected = _selectedCategoryTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedCategoryTab = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (isShopTab ? const Color(0xFFFF5722) : const Color(0xFF1E232E))
              : const Color(0xFFF2F4F7),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : Colors.black.withValues(alpha: 0.05),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 15,
                color: isSelected ? Colors.white : Colors.black54,
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            if (unreadCount > 0) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  unreadCount > 99 ? '99+' : '$unreadCount',
                  style: TextStyle(
                    color: isSelected
                        ? (isShopTab ? const Color(0xFFFF5722) : AppColors.primary)
                        : Colors.white,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyStateForCategory() {
    if (_selectedCategoryTab == 2) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFF1EB),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.storefront_rounded,
                  color: Color(0xFFFF5722),
                  size: 38,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Chưa có tin nhắn Shop nào',
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Trò chuyện với các shop bán hàng để nhận tư vấn sản phẩm, đơn hàng và ưu đãi đặc quyền.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.black45,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (_selectedCategoryTab == 1) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline_rounded, color: Colors.black12, size: 64),
            SizedBox(height: 14),
            Text(
              'Chưa có cuộc trò chuyện bạn bè nào',
              style: TextStyle(color: Colors.black45, fontSize: 15),
            ),
          ],
        ),
      );
    }
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
  final ConversationEntity conv;
  final String currentUserId;
  final String time;
  final VoidCallback onTap;

  const _ConvTile({
    required this.conv,
    required this.currentUserId,
    required this.time,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final displayName = conv.getDisplayName(currentUserId);
    final rawAvatar = conv.getAvatarUrl(currentUserId);
    final avatarUrl = rawAvatar != null && rawAvatar.isNotEmpty
        ? StorageImage.publicUrl(rawAvatar, bucket: 'avatars')
        : null;
    final other = conv.otherUser(currentUserId);
    final isShop = conv.isShop;
    final isShopOwner = conv.isShopOwner(currentUserId);
    final isVerified = conv.isVerified(currentUserId);
    final hasUnread = conv.hasUnread;

    return Container(
      color: Colors.white,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Stack(
          clipBehavior: Clip.none,
          children: [
            _Avatar(
              url: avatarUrl,
              name: displayName,
              size: 50,
              isShop: isShop && !isShopOwner,
            ),
            if (isShop && !isShopOwner)
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  padding: const EdgeInsets.all(2.5),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFFF7A18), Color(0xFFFF2D55)],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.storefront_rounded,
                    color: Colors.white,
                    size: 11,
                  ),
                ),
              )
            else if (other != null)
              Positioned(
                right: 2,
                bottom: 2,
                child: StreamBuilder<Map<String, dynamic>>(
                  stream: sl<PresenceService>().watchUserPresence(other.id),
                  builder: (_, snapshot) {
                    final isOnline = snapshot.data?['is_online'] == true;
                    return Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: isOnline ? Colors.green : Colors.grey.shade400,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.black87,
                  fontWeight: hasUnread ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
            if (isShop && !isShopOwner) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
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
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
            if (isShop && isShopOwner) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Khách mua',
                  style: TextStyle(
                    color: Color(0xFF2E7D32),
                    fontSize: 9.5,
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
                size: 15,
              ),
            ],
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            conv.lastMessage ?? (isShop ? 'Bắt đầu trò chuyện với Shop' : 'Bắt đầu cuộc hội thoại'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: hasUnread ? Colors.black87 : Colors.black45,
              fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w400,
              fontSize: 13,
            ),
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              time,
              style: TextStyle(
                color: hasUnread ? AppColors.primary : Colors.black38,
                fontSize: 11,
                fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
            if (hasUnread) ...[
              const SizedBox(height: 5),
              Container(
                width: 9,
                height: 9,
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
  final VoidCallback onTap;

  const _ActivityBubble({
    required this.icon,
    required this.label,
    required this.color,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 7),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              if (count > 0)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1.5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      count > 99 ? '99+' : '$count',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );
}

class _Avatar extends StatelessWidget {
  final String? url;
  final String name;
  final double size;
  final bool isShop;

  const _Avatar({
    this.url,
    required this.name,
    this.size = 48,
    this.isShop = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveUrl = url != null && url!.isNotEmpty
        ? StorageImage.publicUrl(url!, bucket: 'avatars')
        : null;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isShop ? const Color(0xFFFFF0EC) : const Color(0xFFE8E8E8),
        border: Border.all(
          color: isShop ? const Color(0xFFFFCCBC) : Colors.black12,
          width: 0.8,
        ),
      ),
      child: ClipOval(
        child: effectiveUrl != null
            ? CachedNetworkImage(
                imageUrl: effectiveUrl,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => _buildFallback(),
                placeholder: (_, __) => Container(
                  color: isShop ? const Color(0xFFFFF0EC) : const Color(0xFFE8E8E8),
                ),
              )
            : _buildFallback(),
      ),
    );
  }

  Widget _buildFallback() {
    if (isShop) {
      return const Center(
        child: Icon(
          Icons.storefront_rounded,
          color: Color(0xFFFF5722),
          size: 22,
        ),
      );
    }
    return Center(
      child: Text(
        name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?',
        style: TextStyle(
          color: Colors.black54,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.38,
        ),
      ),
    );
  }
}
