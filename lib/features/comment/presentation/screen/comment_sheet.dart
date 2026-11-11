// features/comment/presentation/screen/comment_sheet.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shareco/core/helpers/require_auth.dart';
import 'package:shareco/core/utils/storage_image.dart';
import 'package:shareco/features/comment/domain/entities/comment_entity.dart';
import 'package:shareco/features/comment/presentation/bloc/comment_bloc.dart';
import 'package:shareco/features/comment/presentation/bloc/comment_event.dart';
import 'package:shareco/features/comment/presentation/bloc/comment_state.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/services/supabase/index.dart';
import '../../../../di/injector.dart';
import '../../../feed/presentation/bloc/feed_bloc.dart';
import '../../../feed/presentation/bloc/feed_event.dart';

class CommentSheet {
  static void show(BuildContext context, {required String videoId}) {
    FeedBloc? feedBloc;
    try {
      feedBloc = context.read<FeedBloc>();
    } catch (_) {}

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (_) {
        return MultiBlocProvider(
          providers: [
            BlocProvider(
              create: (_) =>
                  CommentBloc(repo: sl())..add(CommentLoadRequested(videoId)),
            ),
            if (feedBloc != null) BlocProvider.value(value: feedBloc),
          ],
          child: _CommentSheetBody(videoId: videoId),
        );
      },
    );
  }
}

class _ReplyDraftTarget {
  final String parentId;
  final String rootId;
  final String username;
  final String contentSnippet;

  const _ReplyDraftTarget({
    required this.parentId,
    required this.rootId,
    required this.username,
    required this.contentSnippet,
  });
}

class _CommentSheetBody extends StatefulWidget {
  final String videoId;

  const _CommentSheetBody({required this.videoId});

  @override
  State<_CommentSheetBody> createState() => _CommentSheetBodyState();
}

class _CommentSheetBodyState extends State<_CommentSheetBody> {
  final _ctrl = TextEditingController();
  final _focusNode = FocusNode();
  _ReplyDraftTarget? _replyTarget;
  String? _myAvatarUrl;

  static const _quickEmojis = ['❤️', '🔥', '😂', '🥰', '👏', '😮', '😢'];

  @override
  void initState() {
    super.initState();
    _loadCurrentUserAvatar();
  }

  Future<void> _loadCurrentUserAvatar() async {
    final uid = SupabaseService.currentUserId;
    if (uid == null) return;
    try {
      final row = await SupabaseService.from('profiles')
          .select('avatar_url')
          .eq('id', uid)
          .maybeSingle();
      if (!mounted || row == null) return;
      final url = StorageImage.publicUrl(row['avatar_url']?.toString());
      if (url != null) {
        setState(() => _myAvatarUrl = url);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _startReply(_ReplyDraftTarget target) {
    setState(() => _replyTarget = target);
    _focusNode.requestFocus();
  }

  void _insertEmoji(String emoji) {
    final text = _ctrl.text;
    final sel = _ctrl.selection;
    final insertAt = sel.isValid ? sel.start : text.length;
    final endAt = sel.isValid ? sel.end : text.length;
    final newText = text.replaceRange(insertAt, endAt, emoji);
    _ctrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: insertAt + emoji.length),
    );
  }

  void _onSubmit(BuildContext ctx) {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;

    final target = _replyTarget;
    ctx.requireAuth(() {
      ctx.read<CommentBloc>().add(
            CommentPostRequested(
              content: text,
              parentId: target?.parentId,
              rootId: target?.rootId,
              replyToUsername: target?.username,
              replyToContent: target?.contentSnippet,
            ),
          );
      try {
        ctx
            .read<FeedBloc>()
            .add(FeedCommentChanged(videoId: widget.videoId, delta: 1));
      } catch (_) {}
      _ctrl.clear();
      setState(() => _replyTarget = null);
      _focusNode.unfocus();
    });
  }

  void _onDelete(BuildContext ctx, CommentEntity comment) {
    final removedEstimate = comment.parentId == null
        ? (1 +
            (comment.replyCount > comment.replies.length
                ? comment.replyCount
                : comment.replies.length))
        : 1;
    ctx.read<CommentBloc>().add(CommentDeleteRequested(comment.id));
    try {
      ctx.read<FeedBloc>().add(
            FeedCommentChanged(
              videoId: widget.videoId,
              delta: -removedEstimate,
            ),
          );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.76,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, sc) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surfaceSheet,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          border: Border(top: BorderSide(color: AppColors.borderSubtle)),
        ),
        child: Column(
          children: [
            // Drag Handle
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 10, 6),
              child: Row(
                children: [
                  const SizedBox(width: 32),
                  Expanded(
                    child: BlocBuilder<CommentBloc, CommentState>(
                      builder: (_, state) {
                        final count = state is CommentLoaded
                            ? state.totalCommentCount
                            : 0;
                        return Text(
                          '$count bình luận',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15.5,
                          ),
                        );
                      },
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white60,
                      size: 21,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.borderSubtle),

            // Comment List
            Expanded(
              child: BlocBuilder<CommentBloc, CommentState>(
                builder: (ctx, state) {
                  if (state is CommentLoading) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                        strokeWidth: 2,
                      ),
                    );
                  }
                  if (state is CommentError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          state.message,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white54),
                        ),
                      ),
                    );
                  }
                  if (state is CommentLoaded) {
                    if (state.comments.isEmpty) {
                      return const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline_rounded,
                              color: Colors.white24,
                              size: 46,
                            ),
                            SizedBox(height: 12),
                            Text(
                              'Chưa có bình luận nào\nHãy là người đầu tiên chia sẻ cảm nghĩ!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 13.5,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return NotificationListener<ScrollNotification>(
                      onNotification: (notif) {
                        if (notif.metrics.pixels >=
                                notif.metrics.maxScrollExtent - 180 &&
                            !state.isLoadingMore &&
                            !state.hasReachedMax) {
                          ctx
                              .read<CommentBloc>()
                              .add(const CommentLoadMoreRequested());
                        }
                        return false;
                      },
                      child: ListView.builder(
                        controller: sc,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        itemCount: state.comments.length +
                            (state.isLoadingMore ? 1 : 0),
                        itemBuilder: (_, i) {
                          if (i >= state.comments.length) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 14),
                              child: Center(
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

                          final rootComment = state.comments[i];
                          return _RootCommentThread(
                            comment: rootComment,
                            onReplyTargetSelected: _startReply,
                            onDelete: (target) => _onDelete(ctx, target),
                            onLoadMoreReplies: () => ctx
                                .read<CommentBloc>()
                                .add(CommentRepliesLoadRequested(
                                  rootComment.id,
                                )),
                            onCollapseReplies: () => ctx
                                .read<CommentBloc>()
                                .add(CommentRepliesCollapseToggled(
                                  rootComment.id,
                                )),
                            onToggleLike: (commentId) => ctx.requireAuth(
                              () => ctx
                                  .read<CommentBloc>()
                                  .add(CommentLikeToggled(commentId)),
                            ),
                          );
                        },
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),

            // Reply Target Context Banner
            if (_replyTarget != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 9,
                ),
                decoration: const BoxDecoration(
                  color: AppColors.surfaceCard,
                  border: Border(top: BorderSide(color: AppColors.borderSubtle)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.subdirectory_arrow_right_rounded,
                      color: AppColors.secondary,
                      size: 17,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: RichText(
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        text: TextSpan(
                          children: [
                            const TextSpan(
                              text: 'Đang trả lời ',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12.5,
                              ),
                            ),
                            TextSpan(
                              text: '@${_replyTarget!.username}',
                              style: const TextStyle(
                                color: AppColors.secondary,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (_replyTarget!.contentSnippet.isNotEmpty)
                              TextSpan(
                                text: ' · "${_replyTarget!.contentSnippet}"',
                                style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => setState(() => _replyTarget = null),
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: Colors.white60,
                          size: 15,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Quick Emoji Row + Modern Synchronized Input
            _buildBottomComposer(context),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomComposer(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 14,
        right: 12,
        top: 8,
        bottom: 10 + MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surfaceDark,
        border: Border(top: BorderSide(color: AppColors.borderSubtle)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Quick Emoji Strip (TikTok style)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: _quickEmojis
                  .map(
                    (e) => GestureDetector(
                      onTap: () => _insertEmoji(e),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        child: Text(e, style: const TextStyle(fontSize: 20)),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _UserAvatar(url: _myAvatarUrl, radius: 17),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  focusNode: _focusNode,
                  cursorColor: AppColors.primary,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.35,
                  ),
                  maxLines: 4,
                  minLines: 1,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _onSubmit(context),
                  decoration: InputDecoration(
                    hintText: _replyTarget != null
                        ? 'Trả lời @${_replyTarget!.username}...'
                        : 'Thêm bình luận...',
                    hintStyle: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 13.5,
                    ),
                    filled: true,
                    fillColor: AppColors.surfaceCard,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: const BorderSide(
                        color: AppColors.borderSubtle,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: const BorderSide(
                        color: AppColors.borderSubtle,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: const BorderSide(
                        color: AppColors.primary,
                        width: 1.4,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSizes.sm),
              BlocBuilder<CommentBloc, CommentState>(
                builder: (ctx, state) {
                  final posting = state is CommentLoaded && state.isPosting;
                  return GestureDetector(
                    onTap: posting ? null : () => _onSubmit(ctx),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.32),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Center(
                        child: posting
                            ? const SizedBox(
                                width: 17,
                                height: 17,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.arrow_upward_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                      ),
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

// ─── Root Comment + Flattened TikTok Thread ──────────────────────────────────

class _RootCommentThread extends StatelessWidget {
  final CommentEntity comment;
  final ValueChanged<_ReplyDraftTarget> onReplyTargetSelected;
  final ValueChanged<CommentEntity> onDelete;
  final VoidCallback onLoadMoreReplies;
  final VoidCallback onCollapseReplies;
  final ValueChanged<String> onToggleLike;

  const _RootCommentThread({
    required this.comment,
    required this.onReplyTargetSelected,
    required this.onDelete,
    required this.onLoadMoreReplies,
    required this.onCollapseReplies,
    required this.onToggleLike,
  });

  @override
  Widget build(BuildContext context) {
    final uid = SupabaseService.currentUserId;
    final isOwn = uid != null && uid == comment.userId;
    final avatarUrl = StorageImage.publicUrl(comment.user.avatarUrl);

    final totalReplies = comment.replyCount > comment.replies.length
        ? comment.replyCount
        : comment.replies.length;
    final visibleReplies =
        comment.isRepliesCollapsed ? const <CommentEntity>[] : comment.replies;
    final remainingCount = (totalReplies - visibleReplies.length) > 0
        ? (totalReplies - visibleReplies.length)
        : 0;
    final showLoadMoreButton = totalReplies > 0 &&
        (comment.isRepliesCollapsed ||
            visibleReplies.isEmpty ||
            comment.hasMoreReplies ||
            remainingCount > 0);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _UserAvatar(url: avatarUrl, radius: 18),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Root Author & Content + Like Button
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  comment.user.displayName.isNotEmpty
                                      ? comment.user.displayName
                                      : comment.user.username,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              if (comment.user.isVerified) ...[
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.verified_rounded,
                                  color: AppColors.verified,
                                  size: 13,
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            comment.content,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 6),
                          _CommentMetaActions(
                            createdAt: comment.createdAt,
                            isOwn: isOwn,
                            onReply: () => onReplyTargetSelected(
                              _ReplyDraftTarget(
                                parentId: comment.id,
                                rootId: comment.id,
                                username: comment.user.username,
                                contentSnippet: comment.content,
                              ),
                            ),
                            onDelete: () => onDelete(comment),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _CommentLikeButton(
                      isLiked: comment.isLiked,
                      likeCount: comment.likeCount,
                      onTap: () => onToggleLike(comment.id),
                    ),
                  ],
                ),

                // Visible Replies List (Flattened TikTok Thread)
                if (visibleReplies.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Container(
                      decoration: const BoxDecoration(
                        border: Border(
                          left: BorderSide(
                            color: AppColors.borderSubtle,
                            width: 1.5,
                          ),
                        ),
                      ),
                      padding: const EdgeInsets.only(left: 11),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final reply in visibleReplies)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _ReplyCommentTile(
                                reply: reply,
                                rootAuthorUsername: comment.user.username,
                                onReply: () => onReplyTargetSelected(
                                  _ReplyDraftTarget(
                                    parentId: reply.id,
                                    rootId: comment.id,
                                    username: reply.user.username,
                                    contentSnippet: reply.content,
                                  ),
                                ),
                                onDelete: () => onDelete(reply),
                                onToggleLike: () => onToggleLike(reply.id),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                // TikTok Expand / Load More / Collapse Controls
                if (totalReplies > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      children: [
                        Container(
                          width: 22,
                          height: 1,
                          color: Colors.white24,
                        ),
                        const SizedBox(width: 8),
                        if (comment.isLoadingReplies)
                          const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 13,
                                height: 13,
                                child: CircularProgressIndicator(
                                  color: AppColors.secondary,
                                  strokeWidth: 1.8,
                                ),
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Đang tải câu trả lời...',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          )
                        else ...[
                          if (showLoadMoreButton)
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: onLoadMoreReplies,
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 3),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      visibleReplies.isEmpty
                                          ? 'Xem $totalReplies câu trả lời'
                                          : 'Xem thêm ${remainingCount > 0 ? remainingCount : ''} câu trả lời',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(width: 2),
                                    const Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      color: Colors.white70,
                                      size: 17,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          if (visibleReplies.isNotEmpty) ...[
                            if (showLoadMoreButton) const SizedBox(width: 16),
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: onCollapseReplies,
                              child: const Padding(
                                padding: EdgeInsets.symmetric(vertical: 3),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Ẩn bớt',
                                      style: TextStyle(
                                        color: Colors.white54,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    SizedBox(width: 2),
                                    Icon(
                                      Icons.keyboard_arrow_up_rounded,
                                      color: Colors.white54,
                                      size: 17,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
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
  }
}

// ─── Single Reply Tile (Shows exact target user & quoted comment) ────────────

class _ReplyCommentTile extends StatelessWidget {
  final CommentEntity reply;
  final String rootAuthorUsername;
  final VoidCallback onReply;
  final VoidCallback onDelete;
  final VoidCallback onToggleLike;

  const _ReplyCommentTile({
    required this.reply,
    required this.rootAuthorUsername,
    required this.onReply,
    required this.onDelete,
    required this.onToggleLike,
  });

  @override
  Widget build(BuildContext context) {
    final uid = SupabaseService.currentUserId;
    final isOwn = uid != null && uid == reply.userId;
    final avatarUrl = StorageImage.publicUrl(reply.user.avatarUrl);
    final authorLabel = reply.user.displayName.isNotEmpty
        ? reply.user.displayName
        : reply.user.username;
    final targetUsername = (reply.replyToUsername?.isNotEmpty == true)
        ? reply.replyToUsername!
        : rootAuthorUsername;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _UserAvatar(url: avatarUrl, radius: 13),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // TikTok "Author ▸ @TargetUser" attribution header
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 3,
                children: [
                  Text(
                    authorLabel,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                  ),
                  if (reply.user.isVerified)
                    const Icon(
                      Icons.verified_rounded,
                      color: AppColors.verified,
                      size: 12,
                    ),
                  const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white38,
                    size: 13,
                  ),
                  Text(
                    '@$targetUsername',
                    style: const TextStyle(
                      color: AppColors.secondary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),

              // Quoted snippet of the exact comment being answered
              if (reply.replyToContent != null &&
                  reply.replyToContent!.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCard.withValues(alpha: 0.78),
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: Text(
                    '↳ "${reply.replyToContent!.trim()}"',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 11.5,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 4),
              Text(
                reply.content,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13.5,
                  height: 1.38,
                ),
              ),
              const SizedBox(height: 5),
              _CommentMetaActions(
                createdAt: reply.createdAt,
                isOwn: isOwn,
                onReply: onReply,
                onDelete: onDelete,
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        _CommentLikeButton(
          isLiked: reply.isLiked,
          likeCount: reply.likeCount,
          onTap: onToggleLike,
          iconSize: 16,
        ),
      ],
    );
  }
}

class _CommentMetaActions extends StatelessWidget {
  final DateTime createdAt;
  final bool isOwn;
  final VoidCallback onReply;
  final VoidCallback onDelete;

  const _CommentMetaActions({
    required this.createdAt,
    required this.isOwn,
    required this.onReply,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          _formatRelativeVi(createdAt),
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 11.5,
          ),
        ),
        const SizedBox(width: 16),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onReply,
          child: const Text(
            'Trả lời',
            style: TextStyle(
              color: Colors.white60,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (isOwn) ...[
          const SizedBox(width: 16),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onDelete,
            child: const Text(
              'Xóa',
              style: TextStyle(
                color: AppColors.primarySoft,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }

  static String _formatRelativeVi(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút';
    if (diff.inHours < 24) return '${diff.inHours} giờ';
    if (diff.inDays < 7) return '${diff.inDays} ngày';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
  }
}

class _CommentLikeButton extends StatelessWidget {
  final bool isLiked;
  final int likeCount;
  final VoidCallback onTap;
  final double iconSize;

  const _CommentLikeButton({
    required this.isLiked,
    required this.likeCount,
    required this.onTap,
    this.iconSize = 18,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Column(
          children: [
            Icon(
              isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: isLiked ? AppColors.like : Colors.white38,
              size: iconSize,
            ),
            if (likeCount > 0) ...[
              const SizedBox(height: 2),
              Text(
                '$likeCount',
                style: TextStyle(
                  color: isLiked ? AppColors.like : Colors.white38,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _UserAvatar extends StatelessWidget {
  final String? url;
  final double radius;

  const _UserAvatar({required this.url, required this.radius});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.surfaceElevated,
      child: ClipOval(
        child: url != null && url!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: url!,
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                errorWidget: (_, _, _) => Icon(
                  Icons.person_rounded,
                  color: Colors.white54,
                  size: radius * 1.05,
                ),
              )
            : Icon(
                Icons.person_rounded,
                color: Colors.white54,
                size: radius * 1.05,
              ),
      ),
    );
  }
}
