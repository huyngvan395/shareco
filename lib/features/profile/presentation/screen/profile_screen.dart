// features/profile/presentation/screen/profile_screen.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shareco/core/notifier/auth_notifier.dart';
import 'package:shareco/core/notifier/video_posted_notifier.dart';
import 'package:shareco/core/services/saved_videos_service.dart';
import 'package:shareco/core/utils/video_controller_cache.dart';
import 'package:shareco/features/chat/domain/usecases/chat_usecases.dart';
import 'package:shareco/features/notification/presentation/screen/notification_screen.dart';
import 'package:shareco/features/profile/data/datasources/profile_remote_datasource.dart';
import 'package:shareco/features/profile/data/models/profile_model.dart';
import 'package:shareco/features/profile/presentation/bloc/profile_event.dart';
import 'package:shareco/features/profile/presentation/bloc/profile_state.dart';
import 'package:shareco/features/profile/presentation/screen/profile_feed_screen.dart';
import 'package:shareco/features/profile/presentation/screen/saved_videos_screen.dart';
import 'package:shareco/features/profile/presentation/screen/settings_privacy_screen.dart';
import 'package:shareco/features/video/data/models/video_model.dart';
import 'package:shareco/routes/app_router.dart';
import 'package:shareco/shared/widgets/report_bottom_sheet.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/helpers/require_auth.dart';
import '../../../../core/services/supabase/index.dart';
import '../../../../core/utils/storage_image.dart';
import '../../../../di/injector.dart';
import '../../../chat/presentation/screen/message_screen.dart';
import '../../../ecommerce/order/presentation/screen/order_list_screen.dart';
import '../../../ecommerce/shop/presentation/screen/seller_center_screen.dart';
import '../../../video/domain/entities/video_entity.dart';
import '../../../video/presentation/screen/livestream_screen.dart';
import '../../../wallet/presentation/screen/wallet_screen.dart';
import '../bloc/profile_bloc.dart';

class ProfileScreen extends StatelessWidget {
  final String userId;

  const ProfileScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          ProfileBloc(profileRepo: sl(), getUserVideos: sl())
            ..add(ProfileLoadRequested(userId)),
      child: _ProfileView(userId: userId),
    );
  }
}

class _ProfileView extends StatefulWidget {
  final String userId;

  const _ProfileView({required this.userId});

  @override
  State<_ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<_ProfileView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  bool _loadMoreQueued = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    VideoPostedNotifier.instance.addListener(_onVideoPosted);
  }

  void _onVideoPosted() {
    if (!mounted) return;
    context.read<ProfileBloc>().add(const ProfileVideosRefreshRequested());
  }

  @override
  void didUpdateWidget(covariant _ProfileView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId && widget.userId.isNotEmpty) {
      context.read<ProfileBloc>().add(ProfileLoadRequested(widget.userId));
    }
  }

  @override
  void dispose() {
    VideoPostedNotifier.instance.removeListener(_onVideoPosted);
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 512,
      maxHeight: 512,
    );
    if (picked == null || !mounted) return;

    context.read<ProfileBloc>().add(
      ProfileAvatarUpdateRequested(picked.path),
    );
  }

  Future<void> _openMessageScreen(
    BuildContext context,
    String otherUserId,
  ) async {
    final result = await sl<GetOrCreateConversationUseCase>()(otherUserId);
    if (!context.mounted) return;

    result.fold(
      (failure) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message)));
      },
      (conversation) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MessageScreen(conversation: conversation),
          ),
        );
      },
    );
  }

  void _openProfileFeed(BuildContext context, int initialIndex) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: true,
        barrierColor: Colors.black,
        pageBuilder: (_, __, ___) => BlocProvider.value(
          value: context.read<ProfileBloc>(),
          child: ProfileFeedScreen(initialIndex: initialIndex),
        ),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 220),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: BlocBuilder<ProfileBloc, ProfileState>(
        builder: (ctx, state) {
          if (state is ProfileLoading || state is ProfileInitial) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          if (state is ProfileError) {
            return _ProfileError(
              message: state.message,
              onRetry: () {
                ctx.read<ProfileBloc>().add(
                  ProfileLoadRequested(widget.userId),
                );
              },
            );
          }

          if (state is! ProfileLoaded) return const SizedBox.shrink();

          final profile = state.profile;
          final isMe =
              profile.isCurrentUser ||
              SupabaseService.currentUserId == profile.id;

          return NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              SliverAppBar(
                pinned: true,
                centerTitle: true,
                elevation: 0,
                backgroundColor: Colors.white,
                foregroundColor: Colors.black87,
                title: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        '@${profile.username}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: AppSizes.fontXl,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (profile.isVerified) ...[
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.verified_rounded,
                        color: AppColors.verified,
                        size: 17,
                      ),
                    ],
                  ],
                ),
                actions: [
                  if (isMe) ...[
                    IconButton(
                      tooltip: 'Ví Xu & Rút tiền',
                      icon: const Icon(
                        Icons.account_balance_wallet_outlined,
                        color: Colors.black87,
                      ),
                      onPressed: () {
                        Navigator.of(context, rootNavigator: true).push(
                          MaterialPageRoute(
                            builder: (_) => const WalletScreen(),
                          ),
                        );
                      },
                    ),
                    IconButton(
                      tooltip: 'Phát trực tiếp (Live)',
                      icon: const Icon(
                        Icons.sensors_rounded,
                        color: AppColors.primary,
                      ),
                      onPressed: () {
                        Navigator.of(context, rootNavigator: true).push(
                          MaterialPageRoute(
                            builder: (_) => LivestreamScreen(
                              channelName:
                                  'live_${DateTime.now().millisecondsSinceEpoch}',
                              isHost: true,
                            ),
                          ),
                        );
                      },
                    ),
                    IconButton(
                      tooltip: 'Menu',
                      icon: const Icon(
                        Icons.menu_rounded,
                        color: Colors.black87,
                      ),
                      onPressed: () => _showOwnerMenu(context),
                    ),
                  ] else
                    IconButton(
                      tooltip: 'Thêm',
                      icon: const Icon(
                        Icons.more_horiz_rounded,
                        color: Colors.black87,
                      ),
                      onPressed: () =>
                          _showViewerMenu(context, profile.username),
                    ),
                ],
              ),
              SliverToBoxAdapter(
                child: _ProfileHeader(
                  state: state,
                  isMe: isMe,
                  onEdit: () => _showEditProfile(ctx, state),
                  onFollow: () => ctx.requireAuth(
                    () => ctx.read<ProfileBloc>().add(
                      ProfileFollowToggled(profile.id),
                    ),
                  ),
                  onAvatarTap: _pickAndUploadAvatar,
                  onMessage: () => _openMessageScreen(context, profile.id),
                ),
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: _TabBarDelegate(
                  TabBar(
                    controller: _tabCtrl,
                    indicatorColor: AppColors.primary,
                    indicatorWeight: 2,
                    labelColor: Colors.black87,
                    unselectedLabelColor: Colors.black38,
                    tabs: [
                       const Tab(icon: Icon(Icons.grid_on_rounded)),
                      Tab(
                        icon: Icon(
                          isMe
                              ? Icons.bookmark_border_rounded
                              : Icons.playlist_play,
                        ),
                      ),
                      const Tab(icon: Icon(Icons.favorite_border_rounded)),
                    ],
                  ),
                ),
              ),
            ],
            body: TabBarView(
              controller: _tabCtrl,
              children: [
                _VideoGrid(
                  videos: state.videos,
                  isLoadingMore: state.isLoadingMoreVideos,
                  onLoadMore: _queueLoadMore,
                  onVideoTap: (int index) => _openProfileFeed(ctx, index),
                ),
                isMe
                    ? _SavedOwnerTab(
                        privateOrDraftVideos: state.videos
                            .where(
                              (v) =>
                                  v.visibility != 'public' ||
                                  v.status == 'draft',
                            )
                            .toList(),
                      )
                    : const _EmptyProfileTab(
                        icon: Icons.video_library_outlined,
                        title: 'Không có danh sách phát công khai',
                        subtitle:
                            'Người sáng tạo này chưa chia sẻ bất kỳ bộ sưu tập nào.',
                      ),
                isMe
                    ? const _LikedOwnerTab()
                    : const _EmptyProfileTab(
                        icon: Icons.favorite_border_rounded,
                        title: 'Video đã thích là riêng tư',
                        subtitle:
                            'Chỉ người dùng này mới có thể xem các video mà họ đã thích.',
                      ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _queueLoadMore() {
    if (_loadMoreQueued) return;
    _loadMoreQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ProfileBloc>().add(const ProfileVideosLoadMoreRequested());
      _loadMoreQueued = false;
    });
  }

  void _showOwnerMenu(BuildContext context) {
    final profileContext = context;
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Owner menu',
      barrierColor: Colors.black38,
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (ctx, anim1, anim2) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim1, anim2, child) {
        final slide = Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic));

        return Stack(
          children: [
            GestureDetector(
              onTap: () => Navigator.of(ctx).pop(),
              child: Container(color: Colors.transparent),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: SlideTransition(
                position: slide,
                child: _OwnerSideMenu(
                  onClose: () => Navigator.of(ctx).pop(),
                  onLogout: () => _confirmAndLogout(
                    profileContext: profileContext,
                    menuContext: ctx,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmAndLogout({
    required BuildContext profileContext,
    required BuildContext menuContext,
  }) async {
    final confirmed = await showDialog<bool>(
      context: menuContext,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Đăng xuất tài khoản?',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: const Text(
          'Bạn có chắc chắn muốn đăng xuất khỏi tài khoản hiện tại không?',
          style: TextStyle(color: Colors.black54, fontSize: 14, height: 1.4),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            style: TextButton.styleFrom(foregroundColor: Colors.black54),
            child: const Text(
              'Hủy',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            child: const Text(
              'Đăng xuất',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    if (menuContext.mounted) {
      Navigator.of(menuContext).pop();
    }

    final router = profileContext.mounted
        ? GoRouter.maybeOf(profileContext)
        : null;
    final messenger = profileContext.mounted
        ? ScaffoldMessenger.maybeOf(profileContext)
        : null;

    VideoControllerCache.pauseAllGlobal();
    await sl<AuthNotifier>().signOut();

    router?.go(Routes.feed);
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Đã đăng xuất tài khoản thành công'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.surfaceElevated,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
  }

  void _showViewerMenu(BuildContext context, String username) {
    final shareUrl = 'https://shareco/profile/${widget.userId}';
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _SheetHandle(),
            _MenuTile(
              icon: Icons.share_outlined,
              title: 'Chia sẻ hồ sơ',
              onTap: () async {
                Navigator.pop(sheetContext);
                await SharePlus.instance.share(
                  ShareParams(
                    text: 'Xem kênh @$username trên ShareCo: $shareUrl',
                  ),
                );
              },
            ),
            _MenuTile(
              icon: Icons.flag_outlined,
              title: 'Báo cáo tài khoản',
              color: AppColors.error,
              onTap: () {
                Navigator.pop(sheetContext);
                ReportBottomSheet.show(
                  context,
                  targetType: 'user',
                  targetId: widget.userId,
                  title: 'Báo cáo tài khoản @$username',
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEditProfile(BuildContext context, ProfileLoaded state) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => BlocProvider.value(
        value: context.read<ProfileBloc>(),
        child: _EditProfileSheet(state: state),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final ProfileLoaded state;
  final bool isMe;
  final VoidCallback onEdit;
  final VoidCallback onFollow;
  final VoidCallback onAvatarTap;
  final VoidCallback? onMessage;

  const _ProfileHeader({
    required this.state,
    required this.isMe,
    required this.onEdit,
    required this.onFollow,
    required this.onAvatarTap,
    required this.onMessage,
  });

  @override
  Widget build(BuildContext context) {
    final profile = state.profile;
    final displayName = profile.displayName?.trim();

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(
        AppSizes.lg,
        AppSizes.sm,
        AppSizes.lg,
        AppSizes.lg,
      ),
      child: Column(
        children: [
          _ProfileAvatar(
            avatarPath: profile.avatarUrl,
            canAdd: isMe,
            isUploading: state.isUploadingAvatar,
            onTap: isMe ? onAvatarTap : null,
          ),
          const SizedBox(height: AppSizes.md),
          if (displayName != null && displayName.isNotEmpty)
            Text(
              displayName,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
          const SizedBox(height: AppSizes.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Stat(
                count: profile.followingCount,
                label: 'Đang theo dõi',
                onTap: () => _FollowListSheet.show(
                  context,
                  userId: profile.id,
                  isFollowers: false,
                ),
              ),
              const _StatDivider(),
              _Stat(
                count: profile.followerCount,
                label: 'Người theo dõi',
                onTap: () => _FollowListSheet.show(
                  context,
                  userId: profile.id,
                  isFollowers: true,
                ),
              ),
              const _StatDivider(),
              _Stat(
                count: profile.likeReceivedCount,
                label: 'Lượt thích',
                onTap: () {
                  showDialog<void>(
                    context: context,
                    builder: (dCtx) => AlertDialog(
                      backgroundColor: Colors.white,
                      surfaceTintColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      title: Text(
                        '@${profile.username}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      content: Text(
                        'Đã nhận được tổng cộng ${StorageImage.formatCount(profile.likeReceivedCount)} lượt thả tim trên các video.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.black54),
                      ),
                      actionsAlignment: MainAxisAlignment.center,
                      actions: [
                        ElevatedButton(
                          onPressed: () => Navigator.pop(dCtx),
                          child: const Text('Đóng'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
          if (profile.bio?.trim().isNotEmpty == true) ...[
            const SizedBox(height: AppSizes.lg),
            Text(
              profile.bio!.trim(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF555555),
                fontSize: AppSizes.fontMd,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: AppSizes.lg),
          if (isMe)
            Row(
              children: [
                Expanded(
                  child: _ProfileActionButton(
                    label: 'Sửa hồ sơ',
                    icon: Icons.edit_outlined,
                    onPressed: onEdit,
                  ),
                ),
                const SizedBox(width: AppSizes.sm),
                Expanded(
                  child: _ProfileActionButton(
                    label: 'Ví Xu & Rút tiền',
                    icon: Icons.monetization_on_outlined,
                    isPrimary: true,
                    onPressed: () {
                      Navigator.of(context, rootNavigator: true).push(
                        MaterialPageRoute(
                          builder: (_) => const WalletScreen(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: _ProfileActionButton(
                    label: profile.isFollowing ? 'Đang theo dõi' : 'Theo dõi',
                    isPrimary: !profile.isFollowing,
                    onPressed: onFollow,
                  ),
                ),
                const SizedBox(width: AppSizes.sm),
                Expanded(
                  child: _ProfileActionButton(
                    label: 'Nhắn tin',
                    icon: Icons.chat_bubble_outline_rounded,
                    onPressed: onMessage,
                  ),
                ),
                const SizedBox(width: AppSizes.sm),
                _SquareProfileButton(
                  icon: Icons.share_outlined,
                  onPressed: () {
                    final shareUrl = 'https://shareco/profile/${profile.id}';
                    SharePlus.instance.share(
                      ShareParams(
                        text:
                            'Xem kênh @${profile.username} trên ShareCo: $shareUrl',
                      ),
                    );
                  },
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  final String? avatarPath;
  final bool canAdd;
  final bool isUploading;
  final VoidCallback? onTap;


  const _ProfileAvatar({
    required this.avatarPath,
    required this.canAdd,
    this.isUploading = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasAvatar = avatarPath != null && avatarPath!.trim().isNotEmpty;
    final imageProvider = hasAvatar
        ? CachedNetworkImageProvider(StorageImage.avatarUrl(avatarPath!))
        : null;

    return GestureDetector(
      onTap: isUploading?  null: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            radius: 48,
            backgroundColor: const Color(0xFFE8E8E8),
            backgroundImage: imageProvider,
            child: imageProvider == null
                ? const Icon(Icons.person, size: 48, color: Color(0xFFAAAAAA))
                : null,
          ),
          if (isUploading)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black45,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          if (canAdd && !isUploading)
            Positioned(
              right: -1,
              bottom: 2,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 14),
              ),
            ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final int count;
  final String label;
  final VoidCallback? onTap;

  const _Stat({required this.count, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 86,
        child: Column(
          children: [
            Text(
              StorageImage.formatCount(count),
              style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF777777),
                fontSize: AppSizes.fontSm,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(height: 24, width: 1, color: const Color(0xFFDDDDDD));
  }
}

class _ProfileActionButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool isPrimary;
  final VoidCallback? onPressed;

  const _ProfileActionButton({
    required this.label,
    this.icon,
    this.isPrimary = false,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final background = isPrimary ? AppColors.primary : const Color(0xFFF0F0F0);
    final border = isPrimary ? AppColors.primary : const Color(0xFFDDDDDD);
    final foreground = isPrimary ? Colors.white : Colors.black87;

    return SizedBox(
      height: 42,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: background,
          foregroundColor: foreground,
          disabledBackgroundColor: background.withAlpha(120),
          shape: RoundedRectangleBorder(
            side: BorderSide(color: border),
            borderRadius: BorderRadius.circular(AppSizes.radiusSm),
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 17),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: AppSizes.fontMd,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SquareProfileButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _SquareProfileButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 42,
      height: 42,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.black87,
          backgroundColor: const Color(0xFFF0F0F0),
          side: const BorderSide(color: Color(0xFFDDDDDD)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusSm),
          ),
          padding: EdgeInsets.zero,
        ),
        child: Icon(icon, size: 20),
      ),
    );
  }
}

class _VideoGrid extends StatelessWidget {
  final List<VideoEntity> videos;
  final bool isLoadingMore;
  final VoidCallback onLoadMore;
  final void Function(int index) onVideoTap;

  const _VideoGrid({
    required this.videos,
    required this.isLoadingMore,
    required this.onLoadMore,
    required this.onVideoTap,
  });

  @override
  Widget build(BuildContext context) {
    if (videos.isEmpty) {
      return const _EmptyProfileTab(
        icon: Icons.video_camera_back_outlined,
        title: 'No videos yet',
        subtitle: 'Uploaded videos will appear here.',
      );
    }

    return GridView.builder(
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 9 / 16,
        mainAxisSpacing: 1,
        crossAxisSpacing: 1,
      ),
      itemCount: videos.length + (isLoadingMore ? 1 : 0),
      itemBuilder: (_, index) {
        if (index >= videos.length) {
          return const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 2,
              ),
            ),
          );
        }

        if (index >= videos.length - 3) onLoadMore();

        final video = videos[index];
        final thumbnailUrl = video.thumbnailPath != null
            ? StorageImage.thumbnailUrl(video.thumbnailPath!)
            : null;

        return InkWell(
          onTap: () => onVideoTap(index),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (thumbnailUrl != null)
                CachedNetworkImage(
                  imageUrl: thumbnailUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) =>
                      Container(color: const Color(0xFFE8E8E8)),
                  errorWidget: (context, url, error) =>
                      const _VideoPlaceholder(),
                )
              else
                const _VideoPlaceholder(),
              Positioned(
                left: 5,
                bottom: 5,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(80),
                    borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          StorageImage.formatCount(video.viewCount),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _VideoPlaceholder extends StatelessWidget {
  const _VideoPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFE8E8E8),
      child: const Icon(Icons.video_file_outlined, color: Color(0xFFBBBBBB)),
    );
  }
}

class _EmptyProfileTab extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyProfileTab({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.black26, size: 48),
            const SizedBox(height: AppSizes.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: AppSizes.fontXl,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSizes.xs),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF777777),
                fontSize: AppSizes.fontMd,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final int maxLines;

  const _ProfileTextField({
    required this.controller,
    required this.label,
    required this.maxLines,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.black45),
        filled: true,
        fillColor: const Color(0xFFF5F5F5),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.primary),
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  const _MenuTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.color = Colors.black87,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        title,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
      onTap: onTap,
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 36,
        height: 4,
        margin: const EdgeInsets.only(bottom: AppSizes.md),
        decoration: BoxDecoration(
          color: Colors.black12,
          borderRadius: BorderRadius.circular(AppSizes.radiusCircle),
        ),
      ),
    );
  }
}

class _ProfileError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ProfileError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: AppColors.error,
              size: 44,
            ),
            const SizedBox(height: AppSizes.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: AppSizes.lg),
            _ProfileActionButton(
              label: 'Try again',
              isPrimary: true,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  const _TabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE0E0E0))),
      ),
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) {
    return oldDelegate.tabBar != tabBar;
  }
}

class _OwnerSideMenu extends StatelessWidget {
  final VoidCallback onClose;
  final VoidCallback onLogout;

  const _OwnerSideMenu({
    required this.onClose,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Material(
        color: Colors.white,
        borderRadius: const BorderRadius.horizontal(left: Radius.circular(20)),
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.82,
          height: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 12, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Menu',
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    IconButton(
                      onPressed: onClose,
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.black45,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black12,
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(32, 32),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: Color(0xFFE0E0E0), height: 1),
              const SizedBox(height: 8),
              _MenuTile(
                icon: Icons.account_balance_wallet_rounded,
                title: 'Ví Xu & Rút Tiền',
                color: AppColors.primary,
                onTap: () {
                  onClose();
                  Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute(builder: (_) => const WalletScreen()),
                  );
                },
              ),
              _MenuTile(
                icon: Icons.sensors_rounded,
                title: 'Phát Trực Tiếp (Livestream Bán Hàng)',
                onTap: () {
                  onClose();
                  Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute(
                      builder: (_) => LivestreamScreen(
                        channelName:
                            'live_${DateTime.now().millisecondsSinceEpoch}',
                        isHost: true,
                      ),
                    ),
                  );
                },
              ),
              _MenuTile(
                icon: Icons.receipt_long_outlined,
                title: 'Đơn hàng của tôi',
                onTap: () {
                  onClose();
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const OrderListScreen()),
                  );
                },
              ),
              _MenuTile(
                icon: Icons.storefront_outlined,
                title: 'Kênh Người Bán / Đăng Ký Shop',
                onTap: () {
                  onClose();
                  Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute(
                      builder: (_) => const SellerCenterScreen(),
                    ),
                  );
                },
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Divider(color: Color(0xFFE0E0E0), height: 1),
              ),
              _MenuTile(
                icon: Icons.notifications_active_outlined,
                title: 'Trung tâm hoạt động',
                onTap: () {
                  onClose();
                  Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute(
                      builder: (_) => const NotificationScreen(),
                    ),
                  );
                },
              ),
              _MenuTile(
                icon: Icons.bookmark_border_rounded,
                title: 'Nội dung đã lưu',
                onTap: () {
                  onClose();
                  Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute(
                      builder: (_) => const SavedVideosScreen(),
                    ),
                  );
                },
              ),
              _MenuTile(
                icon: Icons.settings_outlined,
                title: 'Cài đặt và quyền riêng tư',
                onTap: () {
                  onClose();
                  Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute(
                      builder: (_) => const SettingsPrivacyScreen(),
                    ),
                  );
                },
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Divider(color: Color(0xFFE0E0E0), height: 1),
              ),
              _MenuTile(
                icon: Icons.logout_rounded,
                title: 'Đăng xuất',
                color: AppColors.error,
                onTap: onLogout,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditProfileSheet extends StatefulWidget {
  final ProfileLoaded state;

  const _EditProfileSheet({required this.state});

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late final TextEditingController nameCtrl;
  late final TextEditingController bioCtrl;

  @override
  void initState() {
    super.initState();

    nameCtrl = TextEditingController(
      text: widget.state.profile.displayName,
    );

    bioCtrl = TextEditingController(
      text: widget.state.profile.bio,
    );
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    bioCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSizes.xl,
        right: AppSizes.xl,
        top: AppSizes.lg,
        bottom:
        MediaQuery.of(context).viewInsets.bottom + AppSizes.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SheetHandle(),
          const Text(
            'Sửa hồ sơ',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: AppSizes.xl),

          _ProfileTextField(
            controller: nameCtrl,
            label: 'Tên hiển thị',
            maxLines: 1,
          ),

          const SizedBox(height: AppSizes.md),

          _ProfileTextField(
            controller: bioCtrl,
            label: 'Bio',
            maxLines: 3,
          ),

          const SizedBox(height: AppSizes.xl),

          _ProfileActionButton(
            label: 'Lưu',
            isPrimary: true,
            onPressed: () {
              context.read<ProfileBloc>().add(
                ProfileUpdateRequested(
                  displayName: nameCtrl.text.trim(),
                  bio: bioCtrl.text.trim(),
                ),
              );

              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}

class _FollowListSheet extends StatefulWidget {
  final String userId;
  final bool isFollowers;

  const _FollowListSheet({
    required this.userId,
    required this.isFollowers,
  });

  static Future<void> show(
    BuildContext context, {
    required String userId,
    required bool isFollowers,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.72,
        child: _FollowListSheet(userId: userId, isFollowers: isFollowers),
      ),
    );
  }

  @override
  State<_FollowListSheet> createState() => _FollowListSheetState();
}

class _FollowListSheetState extends State<_FollowListSheet> {
  final ProfileRemoteDataSource _ds = sl<ProfileRemoteDataSource>();
  List<ProfileModel> _users = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = widget.isFollowers
          ? await _ds.getFollowers(userId: widget.userId)
          : await _ds.getFollowing(userId: widget.userId);
      if (!mounted) return;
      setState(() {
        _users = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _SheetHandle(),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            widget.isFollowers ? 'Người theo dõi' : 'Đang theo dõi',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _users.isEmpty
              ? Center(
                  child: Text(
                    widget.isFollowers
                        ? 'Chưa có người theo dõi nào'
                        : 'Chưa theo dõi tài khoản nào',
                    style: const TextStyle(color: Colors.black54),
                  ),
                )
              : ListView.builder(
                  itemCount: _users.length,
                  itemBuilder: (ctx, index) {
                    final u = _users[index];
                    final avatar = StorageImage.avatar(u.avatarUrl);
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFFEEEEEE),
                        backgroundImage: avatar != null
                            ? CachedNetworkImageProvider(avatar)
                            : null,
                        child: avatar == null
                            ? Text(
                                (u.username.isNotEmpty ? u.username[0] : '?')
                                    .toUpperCase(),
                              )
                            : null,
                      ),
                      title: Text(
                        (u.displayName?.trim().isNotEmpty == true)
                            ? u.displayName!
                            : u.username,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text('@${u.username}'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () {
                        Navigator.pop(context);
                        context.push(Routes.profileOf(u.id));
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _SavedOwnerTab extends StatefulWidget {
  final List<VideoEntity> privateOrDraftVideos;

  const _SavedOwnerTab({required this.privateOrDraftVideos});

  @override
  State<_SavedOwnerTab> createState() => _SavedOwnerTabState();
}

class _SavedOwnerTabState extends State<_SavedOwnerTab> {
  final SavedVideosService _savedService = sl<SavedVideosService>();
  List<VideoEntity> _saved = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    _savedService.addListener(_load);
  }

  @override
  void dispose() {
    _savedService.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final res = await _savedService.fetchSavedVideos();
    if (!mounted) return;
    setState(() {
      _saved = res;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final byId = <String, VideoEntity>{};
    for (final v in _saved) {
      byId[v.id] = v;
    }
    for (final v in widget.privateOrDraftVideos) {
      byId.putIfAbsent(v.id, () => v);
    }
    final merged = byId.values.toList();
    if (merged.isEmpty) {
      return const _EmptyProfileTab(
        icon: Icons.bookmark_border_rounded,
        title: 'Nội dung đã lưu & Bản nháp',
        subtitle:
            'Các video bạn đã lưu hoặc video chờ duyệt / riêng tư sẽ xuất hiện tại đây.',
      );
    }
    return _VideoGrid(
      videos: merged,
      isLoadingMore: false,
      onLoadMore: () {},
      onVideoTap: (index) {
        context.push(
          Routes.searchFeedViewer,
          extra: {'videos': merged, 'initialIndex': index},
        );
      },
    );
  }
}

class _LikedOwnerTab extends StatefulWidget {
  const _LikedOwnerTab();

  @override
  State<_LikedOwnerTab> createState() => _LikedOwnerTabState();
}

class _LikedOwnerTabState extends State<_LikedOwnerTab> {
  List<VideoEntity> _likedVideos = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadLiked();
  }

  Future<void> _loadLiked() async {
    final uid = SupabaseService.currentUserId;
    if (uid == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final likeRows = await SupabaseService.from('video_likes')
          .select('video_id, created_at')
          .eq('user_id', uid)
          .order('created_at', ascending: false)
          .limit(60) as List;
      final ids = [
        for (final r in likeRows)
          (r as Map<String, dynamic>)['video_id'] as String,
      ];
      if (ids.isEmpty) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      final rows = await SupabaseService.from('videos')
          .select('''
            *,
            profiles:author_id (
              id, username, display_name, avatar_url, is_verified,
              follower_count, following_count, like_received_count
            )
          ''')
          .inFilter('id', ids)
          .eq('status', 'published') as List;

      final byId = {
        for (final r in rows) (r as Map<String, dynamic>)['id'] as String: r,
      };
      final list = <VideoEntity>[
        for (final id in ids)
          if (byId.containsKey(id))
            VideoModel.fromJson(byId[id]!, isLiked: true),
      ];
      if (!mounted) return;
      setState(() {
        _likedVideos = list;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_likedVideos.isEmpty) {
      return const _EmptyProfileTab(
        icon: Icons.favorite_border_rounded,
        title: 'Video đã thích',
        subtitle: 'Các video bạn thả tim sẽ được tập hợp tại đây.',
      );
    }
    return _VideoGrid(
      videos: _likedVideos,
      isLoadingMore: false,
      onLoadMore: () {},
      onVideoTap: (index) {
        context.push(
          Routes.searchFeedViewer,
          extra: {'videos': _likedVideos, 'initialIndex': index},
        );
      },
    );
  }
}