// features/comment/presentation/comment_sheet.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shareco/core/helpers/require_auth.dart';
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
    final feedBloc = context.read<FeedBloc>();
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
              child: _CommentSheetBody(videoId: videoId),
            ),
            BlocProvider.value(value: feedBloc),
          ],
          child: _CommentSheetBody(videoId: videoId),
        );
      },
    );
  }
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
  String? _replyingToId;
  String? _replyingToName;

  @override
  void dispose() {
    _ctrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSubmit(BuildContext ctx) {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    ctx.requireAuth(() {
      ctx.read<CommentBloc>().add(
        CommentPostRequested(content: text, parentId: _replyingToId),
      );
      ctx.read<FeedBloc>().add(FeedCommentChanged(videoId: widget.videoId));
      _ctrl.clear();
      setState(() {
        _replyingToId = null;
        _replyingToName = null;
      });
      _focusNode.unfocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, sc) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            // Handle
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),

            // Header
            BlocBuilder<CommentBloc, CommentState>(
              builder: (_, state) {
                final count = state is CommentLoaded
                    ? state.comments.length
                    : 0;
                return Text(
                  '$count Comments',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                );
              },
            ),
            const Divider(color: Color(0xFF2A2A2A)),

            // Comment list
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
                      child: Text(
                        state.message,
                        style: const TextStyle(color: Colors.white38),
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
                              Icons.chat_bubble_outline,
                              color: Colors.white24,
                              size: 48,
                            ),
                            SizedBox(height: 12),
                            Text(
                              'No comments yet\nBe the first!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white38,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return ListView.builder(
                      controller: sc,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.lg,
                      ),
                      itemCount: state.comments.length,
                      itemBuilder: (_, i) => _CommentTile(
                        comment: state.comments[i],
                        onReply: (id, name) {
                          setState(() {
                            _replyingToId = id;
                            _replyingToName = name;
                          });
                          _focusNode.requestFocus();
                        },
                        onDelete: (id) => ctx.read<CommentBloc>().add(
                          CommentDeleteRequested(id),
                        ),
                        onLoadReplies: (id) => ctx.read<CommentBloc>().add(
                          CommentRepliesLoadRequested(id),
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),

            // Reply indicator
            if (_replyingToName != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.lg,
                  vertical: 8,
                ),
                color: AppColors.bgInput,
                child: Row(
                  children: [
                    Text(
                      'Replying to @$_replyingToName',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 13,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => setState(() {
                        _replyingToId = null;
                        _replyingToName = null;
                      }),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white38,
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ),

            _buildInput(context),
          ],
        ),
      ),
    );
  }

  Widget _buildInput(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: AppSizes.lg,
        right: AppSizes.sm,
        top: AppSizes.sm,
        bottom: AppSizes.sm + MediaQuery.of(context).viewInsets.bottom,
      ),
      color: const Color(0xFF1A1A1A),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.bgInput,
            backgroundImage: SupabaseService.currentUserId != null
                ? null
                : null,
            child: const Icon(Icons.person, color: Colors.white54, size: 18),
          ),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: TextField(
              controller: _ctrl,
              focusNode: _focusNode,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              maxLines: 3,
              minLines: 1,
              decoration: InputDecoration(
                hintText: _replyingToName != null
                    ? 'Reply...'
                    : 'Add comment...',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: AppColors.bgInput,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
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
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: posting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final CommentEntity comment;
  final void Function(String id, String name) onReply;
  final void Function(String id) onDelete;
  final void Function(String id) onLoadReplies;

  const _CommentTile({
    required this.comment,
    required this.onReply,
    required this.onDelete,
    required this.onLoadReplies,
  });

  @override
  Widget build(BuildContext context) {
    final uid = SupabaseService.currentUserId;
    final isOwn = uid == comment.userId;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.bgInput,
                backgroundImage: comment.user.avatarUrl != null
                    ? NetworkImage(comment.user.avatarUrl!)
                    : null,
                child: comment.user.avatarUrl == null
                    ? const Icon(Icons.person, color: Colors.white54, size: 18)
                    : null,
              ),
              const SizedBox(width: 10),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Username + content
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: comment.user.username,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          const TextSpan(text: '  '),
                          TextSpan(
                            text: comment.content,
                            style: const TextStyle(
                              color: Color(0xFFE8E8E8),
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Actions row
                    Row(
                      children: [
                        Text(
                          _timeAgo(comment.createdAt),
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 16),
                        if (comment.likeCount > 0)
                          Text(
                            '${comment.likeCount} likes',
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 12,
                            ),
                          ),
                        const SizedBox(width: 16),
                        GestureDetector(
                          onTap: () =>
                              onReply(comment.id, comment.user.username),
                          child: const Text(
                            'Reply',
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (isOwn) ...[
                          const SizedBox(width: 16),
                          GestureDetector(
                            onTap: () => onDelete(comment.id),
                            child: const Text(
                              'Delete',
                              style: TextStyle(
                                color: AppColors.error,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),

                    // Replies
                    if (comment.replyCount > 0 && comment.replies.isEmpty)
                      GestureDetector(
                        onTap: () => onLoadReplies(comment.id),
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            children: [
                              Container(
                                width: 24,
                                height: 1,
                                color: Colors.white24,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'View ${comment.replyCount} replies',
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    if (comment.replies.isNotEmpty)
                      ...comment.replies.map(
                        (r) => Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: _CommentTile(
                            comment: r,
                            onReply: onReply,
                            onDelete: onDelete,
                            onLoadReplies: onLoadReplies,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Like button
              Column(
                children: [
                  const Icon(
                    Icons.favorite_border,
                    color: Colors.white54,
                    size: 18,
                  ),
                  if (comment.likeCount > 0)
                    Text(
                      '${comment.likeCount}',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 7) return '${dt.day}/${dt.month}/${dt.year}';
    if (diff.inDays > 0) return '${diff.inDays}d';
    if (diff.inHours > 0) return '${diff.inHours}h';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m';
    return 'now';
  }
}
