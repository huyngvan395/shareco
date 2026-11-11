import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/notifications/push_notification_service.dart';
import '../../../../core/utils/storage_image.dart';
import '../../../../di/injector.dart';
import '../../../profile/presentation/screen/settings_privacy_screen.dart';
import '../../domain/entities/notification_entity.dart';
import '../../domain/repositories/notification_repository.dart';

class NotificationScreen extends StatefulWidget {
  final String initialCategory;

  const NotificationScreen({
    super.key,
    this.initialCategory = 'all',
  });

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final NotificationRepository _repo = sl<NotificationRepository>();
  final PushNotificationService _pushService = sl<PushNotificationService>();
  final ScrollController _scrollController = ScrollController();

  late String _selectedCategory = widget.initialCategory;
  List<NotificationEntity> _items = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  int _page = 0;

  static const _categories = <(String, String, IconData)>[
    ('all', 'Tất cả', Icons.notifications_rounded),
    ('likes', 'Lượt thích', Icons.favorite_rounded),
    ('comments', 'Bình luận', Icons.chat_bubble_rounded),
    ('mentions', 'Nhắc đến', Icons.alternate_email_rounded),
    ('follows_live', 'Follow & Live', Icons.sensors_rounded),
    ('orders', 'Đơn hàng & Ví', Icons.local_shipping_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _loadInitial();
    _pushService.addListener(_onPushSummaryChanged);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _pushService.removeListener(_onPushSummaryChanged);
    _scrollController.dispose();
    super.dispose();
  }

  void _onPushSummaryChanged() {
    if (mounted && !_loading) {
      _loadInitial(silent: true);
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_loadingMore &&
        _hasMore) {
      _loadMore();
    }
  }

  Future<void> _loadInitial({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    _page = 0;
    final res = await _repo.getNotifications(page: 0);
    if (!mounted) return;
    res.fold(
      (_) {
        if (!silent) setState(() => _loading = false);
      },
      (paged) {
        setState(() {
          _items = paged.items;
          _hasMore = paged.hasMore;
          _loading = false;
        });
      },
    );
    await _pushService.refreshUnreadSummary();
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    final nextPage = _page + 1;
    final res = await _repo.getNotifications(page: nextPage);
    if (!mounted) return;
    res.fold(
      (_) => setState(() => _loadingMore = false),
      (paged) {
        setState(() {
          _page = nextPage;
          _items = [..._items, ...paged.items];
          _hasMore = paged.hasMore;
          _loadingMore = false;
        });
      },
    );
  }

  Future<void> _markAllAsRead() async {
    await _repo.markAllAsRead();
    await _pushService.refreshUnreadSummary();
    if (!mounted) return;
    setState(() {
      _items = _items.map((e) => e.copyWith(isRead: true)).toList();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã đánh dấu đọc tất cả thông báo'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  bool _matchesCategory(NotificationEntity item, String cat) {
    if (cat == 'all') return true;
    final t = item.type;
    switch (cat) {
      case 'likes':
        return t == 'like' || t == 'video_like' || t == 'comment_like';
      case 'comments':
        return t == 'comment' || t == 'comment_reply';
      case 'mentions':
        return t == 'mention';
      case 'follows_live':
        return t == 'follow' ||
            t == 'new_video' ||
            t == 'livestream' ||
            t == 'gift';
      case 'orders':
        return t == 'order' ||
            t == 'new_order' ||
            t == 'order_status' ||
            t == 'wallet' ||
            t == 'system';
      default:
        return true;
    }
  }

  String _formatRelativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    if (diff.inDays < 7) return '${diff.inDays} ngày trước';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  (IconData, Color) _badgeForType(String type) {
    switch (type) {
      case 'video_like':
      case 'like':
      case 'comment_like':
        return (Icons.favorite_rounded, AppColors.primary);
      case 'comment':
      case 'comment_reply':
        return (Icons.chat_bubble_rounded, AppColors.secondary);
      case 'mention':
        return (Icons.alternate_email_rounded, const Color(0xFF8B5CF6));
      case 'new_video':
        return (Icons.play_circle_fill_rounded, AppColors.secondary);
      case 'livestream':
        return (Icons.sensors_rounded, AppColors.primary);
      case 'follow':
        return (Icons.person_add_alt_1_rounded, const Color(0xFF10B981));
      case 'gift':
      case 'wallet':
        return (Icons.monetization_on_rounded, AppColors.gold);
      case 'order':
      case 'new_order':
      case 'order_status':
        return (Icons.local_shipping_rounded, const Color(0xFFF97316));
      default:
        return (Icons.notifications_active_rounded, AppColors.primary);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _items
        .where((e) => _matchesCategory(e, _selectedCategory))
        .toList();
    final hasUnread = _items.any((e) => !e.isRead);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Trung tâm hoạt động',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: Colors.black87,
          ),
        ),
        actions: [
          if (hasUnread)
            TextButton.icon(
              onPressed: _markAllAsRead,
              icon: const Icon(Icons.done_all_rounded, size: 17),
              label: const Text(
                'Đọc hết',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
            ),
          IconButton(
            tooltip: 'Cài đặt thông báo',
            icon: const Icon(
              Icons.tune_rounded,
              color: Colors.black87,
              size: 21,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SettingsPrivacyScreen(),
                ),
              );
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Container(
            height: 50,
            color: Colors.white,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final (key, label, icon) = _categories[index];
                final active = _selectedCategory == key;
                return ChoiceChip(
                  showCheckmark: false,
                  selected: active,
                  onSelected: (_) => setState(() => _selectedCategory = key),
                  avatar: Icon(
                    icon,
                    size: 15,
                    color: active ? Colors.white : Colors.black54,
                  ),
                  label: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: active ? Colors.white : Colors.black87,
                    ),
                  ),
                  selectedColor: AppColors.primary,
                  backgroundColor: const Color(0xFFF1F2F6),
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                );
              },
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _loadInitial,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : filtered.isEmpty
            ? ListView(
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.18),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        children: [
                          Container(
                            width: 74,
                            height: 74,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.08),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.notifications_none_rounded,
                              size: 36,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Chưa có thông báo nào',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Các lượt thích, bình luận, nhắc tên @username, video mới và Livestream từ người bạn theo dõi sẽ hiển thị tại đây.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.black54,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 20),
                          OutlinedButton.icon(
                            onPressed: () async {
                              await _pushService.sendTestPushNotification();
                              await _loadInitial(silent: true);
                            },
                            icon: const Icon(
                              Icons.notifications_active_outlined,
                              size: 18,
                            ),
                            label: const Text('Gửi thử thông báo đẩy'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            : ListView.separated(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: filtered.length + (_loadingMore ? 1 : 0),
                separatorBuilder: (_, _) => const Divider(
                  height: 1,
                  indent: 74,
                  color: Color(0xFFEEEEEE),
                ),
                itemBuilder: (context, index) {
                  if (index >= filtered.length) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    );
                  }
                  final item = filtered[index];
                  final (icon, accent) = _badgeForType(item.type);
                  final avatarUrl = StorageImage.avatar(
                    item.data?['actor_avatar'] as String?,
                  );
                  final thumbUrl = StorageImage.videoThumbnail(
                    item.data?['thumbnail_url'] as String?,
                  );

                  return Dismissible(
                    key: ValueKey(item.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      color: AppColors.error,
                      child: const Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.white,
                      ),
                    ),
                    onDismissed: (_) async {
                      setState(() {
                        _items.removeWhere((e) => e.id == item.id);
                      });
                      await _repo.deleteNotification(item.id);
                      await _pushService.refreshUnreadSummary();
                    },
                    child: Material(
                      color: item.isRead
                          ? Colors.white
                          : AppColors.primary.withValues(alpha: 0.045),
                      child: InkWell(
                        onTap: () async {
                          setState(() {
                            _items = _items
                                .map(
                                  (e) => e.id == item.id
                                      ? e.copyWith(isRead: true)
                                      : e,
                                )
                                .toList();
                          });
                          await _pushService.openNotificationEntity(item);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 13,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Container(
                                    width: 46,
                                    height: 46,
                                    decoration: BoxDecoration(
                                      color: accent.withValues(alpha: 0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: avatarUrl != null
                                        ? ClipOval(
                                            child: CachedNetworkImage(
                                              imageUrl: avatarUrl,
                                              fit: BoxFit.cover,
                                              errorWidget: (_, _, _) => Icon(
                                                icon,
                                                color: accent,
                                                size: 22,
                                              ),
                                            ),
                                          )
                                        : Icon(icon, color: accent, size: 22),
                                  ),
                                  if (avatarUrl != null)
                                    Positioned(
                                      right: -2,
                                      bottom: -2,
                                      child: Container(
                                        width: 20,
                                        height: 20,
                                        decoration: BoxDecoration(
                                          color: accent,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 1.8,
                                          ),
                                        ),
                                        child: Icon(
                                          icon,
                                          color: Colors.white,
                                          size: 11,
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
                                      item.title ??
                                          PushNotificationService
                                              .defaultTitleForType(item.type),
                                      style: TextStyle(
                                        fontSize: 13.8,
                                        fontWeight: item.isRead
                                            ? FontWeight.w600
                                            : FontWeight.w800,
                                        color: Colors.black87,
                                        height: 1.25,
                                      ),
                                    ),
                                    if (item.body != null &&
                                        item.body!.trim().isNotEmpty) ...[
                                      const SizedBox(height: 3),
                                      Text(
                                        item.body!,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Colors.black54,
                                          height: 1.35,
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 5),
                                    Text(
                                      _formatRelativeTime(item.createdAt),
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        color: Colors.black38,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (thumbUrl != null) ...[
                                const SizedBox(width: 10),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: CachedNetworkImage(
                                    imageUrl: thumbUrl,
                                    width: 44,
                                    height: 56,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, _, _) => Container(
                                      width: 44,
                                      height: 56,
                                      color: Colors.black12,
                                      child: const Icon(
                                        Icons.play_arrow_rounded,
                                        color: Colors.black45,
                                      ),
                                    ),
                                  ),
                                ),
                              ] else if (!item.isRead) ...[
                                const SizedBox(width: 8),
                                Padding(
                                  padding: const EdgeInsets.only(top: 16),
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: AppColors.primary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
