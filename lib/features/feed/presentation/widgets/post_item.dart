// features/feed/presentation/widgets/post_item.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shareco/features/feed/domain/entities/feed_entity.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/utils/storage_image.dart';
import '../bloc/feed_bloc.dart';

class PostItem extends StatefulWidget {
  final PostEntity post;
  const PostItem({super.key, required this.post});

  @override
  State<PostItem> createState() => _PostItemState();
}

class _PostItemState extends State<PostItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _likeCtrl;
  late Animation<double> _likeScale;

  @override
  void initState() {
    super.initState();
    _likeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _likeScale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.4), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.4, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _likeCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _likeCtrl.dispose();
    super.dispose();
  }

  void _onLikeTap() {
    _likeCtrl.forward(from: 0);
    // context.read<FeedBloc>().add(FeedPostLikeToggled(widget.post.id));
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSizes.sm),
        color: AppColors.bgCard,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(post),
            if (post.content.isNotEmpty) _buildContent(post.content),
            if (post.imageUrls.isNotEmpty) _buildImages(post.imageUrls),
            _buildStats(post),
            _buildActions(post),
            const Divider(color: AppColors.divider, height: 1),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(PostEntity post) => Padding(
    padding: const EdgeInsets.all(AppSizes.md),
    child: Row(
      children: [
        ClipOval(
          child: SizedBox(
            width: AppSizes.avatarMd,
            height: AppSizes.avatarMd,
            child: CachedNetworkImage(
              imageUrl: post.user.avatarUrl,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(color: Colors.grey[800]),
              errorWidget: (_, __, ___) => Container(
                color: AppColors.border,
                child: const Icon(Icons.person, color: AppColors.iconMuted),
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSizes.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text(
                  post.user.displayName,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: AppSizes.fontLg,
                  ),
                ),
                if (post.user.isVerified) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.verified,
                      color: AppColors.verified,
                      size: AppSizes.iconSm),
                ],
              ]),
              const SizedBox(height: 2),
              Row(children: [
                Text(
                  post.timeAgo,
                  style: const TextStyle(
                      color: AppColors.textHint,
                      fontSize: AppSizes.fontSm),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.public,
                    color: AppColors.textHint,
                    size: AppSizes.iconSm),
              ]),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.more_horiz, color: AppColors.iconMuted),
          onPressed: () {},
        ),
      ],
    ),
  );

  Widget _buildContent(String content) => Padding(
    padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.lg, vertical: AppSizes.sm),
    child: Text(
      content,
      style: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: AppSizes.fontLg - 1,
        height: 1.45,
      ),
    ),
  );

  Widget _buildImages(List<String> urls) {
    if (urls.length == 1) return _SingleImage(url: urls[0]);
    if (urls.length == 2) return _TwoImages(urls: urls);
    return _GridImages(urls: urls);
  }

  Widget _buildStats(PostEntity post) => Padding(
    padding: const EdgeInsets.fromLTRB(
        AppSizes.lg, AppSizes.sm, AppSizes.lg, 4),
    child: Row(children: [
      _LikeEmojiStack(),
      const SizedBox(width: 6),
      Text(
        StorageImage.formatCount(post.likes),
        style: const TextStyle(
            color: AppColors.textHint,
            fontSize: AppSizes.fontSm + 1),
      ),
      const Spacer(),
      Text(
        '${StorageImage.formatCount(post.comments)} comments',
        style: const TextStyle(
            color: AppColors.textHint,
            fontSize: AppSizes.fontSm + 1),
      ),
    ]),
  );

  Widget _buildActions(PostEntity post) {
    final isLiked = post.isLiked;
    return Column(children: [
      const Divider(color: AppColors.divider, height: 1),
      Row(children: [
        Expanded(
          child: _PostActionBtn(
            icon: isLiked
                ? Icons.thumb_up_alt_rounded
                : Icons.thumb_up_alt_outlined,
            label: 'Like',
            color:
            isLiked ? AppColors.facebookLike : AppColors.iconMuted,
            scale: _likeScale,
            onTap: _onLikeTap,
          ),
        ),
        Expanded(
          child: _PostActionBtn(
            icon: Icons.chat_bubble_outline_rounded,
            label: 'Comment',
            color: AppColors.iconMuted,
            onTap: () {},
          ),
        ),
        Expanded(
          child: _PostActionBtn(
            icon: Icons.share_outlined,
            label: 'Share',
            color: AppColors.iconMuted,
            onTap: () {},
          ),
        ),
      ]),
    ]);
  }
}

// ─── Image Layouts ─────────────────────────────────────────────────────────────

class _SingleImage extends StatelessWidget {
  final String url;
  const _SingleImage({required this.url});

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 16 / 9,
    child: CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (_, __) =>
          Container(color: AppColors.bgInput),
      errorWidget: (_, __, ___) => Container(
        color: AppColors.bgInput,
        child: const Icon(Icons.image_outlined,
            color: Colors.white24, size: 48),
      ),
    ),
  );
}

class _TwoImages extends StatelessWidget {
  final List<String> urls;
  const _TwoImages({required this.urls});

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 2,
    child: Row(
      children: urls
          .map((url) => Expanded(
        child: Container(
          margin: const EdgeInsets.only(right: 1),
          child: CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.cover,
            placeholder: (_, __) =>
                Container(color: AppColors.bgInput),
            errorWidget: (_, __, ___) =>
                Container(color: AppColors.bgInput),
          ),
        ),
      ))
          .toList(),
    ),
  );
}

class _GridImages extends StatelessWidget {
  final List<String> urls;
  const _GridImages({required this.urls});

  @override
  Widget build(BuildContext context) {
    final rest = urls.skip(1).take(2).toList();
    final extra = urls.length - 3;
    return SizedBox(
      height: 280,
      child: Row(children: [
        Expanded(
          flex: 3,
          child: CachedNetworkImage(
            imageUrl: urls[0],
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(color: AppColors.bgInput),
            errorWidget: (_, __, ___) => Container(color: AppColors.bgInput),
          ),
        ),
        const SizedBox(width: 2),
        Expanded(
          flex: 2,
          child: Column(
            children: List.generate(rest.length, (i) {
              final isLast = i == rest.length - 1;
              return Expanded(
                child: Container(
                  margin: i == 0 ? const EdgeInsets.only(bottom: 2) : null,
                  child: Stack(fit: StackFit.expand, children: [
                    CachedNetworkImage(
                      imageUrl: rest[i],
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          Container(color: AppColors.bgInput),
                      errorWidget: (_, __, ___) =>
                          Container(color: AppColors.bgInput),
                    ),
                    if (isLast && extra > 0)
                      Container(
                        color: Colors.black54,
                        alignment: Alignment.center,
                        child: Text(
                          '+$extra',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                  ]),
                ),
              );
            }),
          ),
        ),
      ]),
    );
  }
}

// ─── Helper widgets ────────────────────────────────────────────────────────────

class _LikeEmojiStack extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Row(children: [
    Container(
      width: 20,
      height: 20,
      decoration: const BoxDecoration(
          color: AppColors.facebookLike, shape: BoxShape.circle),
      child: const Icon(Icons.thumb_up_rounded,
          color: Colors.white, size: 12),
    ),
    Transform.translate(
      offset: const Offset(-6, 0),
      child: Container(
        width: 20,
        height: 20,
        decoration: const BoxDecoration(
            color: AppColors.like, shape: BoxShape.circle),
        child: const Icon(Icons.favorite, color: Colors.white, size: 12),
      ),
    ),
  ]);
}

class _PostActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final Animation<double>? scale;

  const _PostActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.scale,
  });

  @override
  Widget build(BuildContext context) {
    Widget iconW = Icon(icon, color: color, size: AppSizes.iconMd);
    if (scale != null) {
      iconW = AnimatedBuilder(
        animation: scale!,
        builder: (_, child) =>
            Transform.scale(scale: scale!.value, child: child),
        child: iconW,
      );
    }
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          iconW,
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: AppSizes.fontMd,
              fontWeight: FontWeight.w600,
            ),
          ),
        ]),
      ),
    );
  }
}