import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shareco/features/comment/domain/entities/comment_entity.dart';
import 'package:shareco/features/comment/domain/repositories/comment_repository.dart';
import 'package:shareco/features/comment/presentation/bloc/comment_event.dart';
import 'package:shareco/features/comment/presentation/bloc/comment_state.dart';

class CommentBloc extends Bloc<CommentEvent, CommentState> {
  final CommentRepository repo;

  CommentBloc({required this.repo}) : super(const CommentInitial()) {
    on<CommentLoadRequested>(_onLoad);
    on<CommentLoadMoreRequested>(_onLoadMore);
    on<CommentPostRequested>(_onPost);
    on<CommentDeleteRequested>(_onDelete);
    on<CommentRepliesLoadRequested>(_onLoadReplies);
    on<CommentRepliesCollapseToggled>(_onToggleCollapseReplies);
    on<CommentLikeToggled>(_onToggleLike);
  }

  Future<void> _onLoad(
    CommentLoadRequested event,
    Emitter<CommentState> emit,
  ) async {
    emit(const CommentLoading());
    final r = await repo.getComments(videoId: event.videoId, page: 0);
    r.fold(
      (f) => emit(CommentError(f.message)),
      (p) => emit(
        CommentLoaded(
          videoId: event.videoId,
          comments: p.items,
          hasReachedMax: !p.hasMore,
        ),
      ),
    );
  }

  Future<void> _onLoadMore(
    CommentLoadMoreRequested _,
    Emitter<CommentState> emit,
  ) async {
    final current = state;
    if (current is! CommentLoaded) return;
    if (current.isLoadingMore || current.hasReachedMax) return;
    emit(current.copyWith(isLoadingMore: true));
    final next = current.currentPage + 1;
    final r = await repo.getComments(videoId: current.videoId, page: next);
    r.fold(
      (_) => emit(current.copyWith(isLoadingMore: false)),
      (p) => emit(
        current.copyWith(
          comments: [...current.comments, ...p.items],
          isLoadingMore: false,
          currentPage: next,
          hasReachedMax: !p.hasMore,
        ),
      ),
    );
  }

  Future<void> _onPost(
    CommentPostRequested event,
    Emitter<CommentState> emit,
  ) async {
    final current = state;
    if (current is! CommentLoaded) return;
    emit(current.copyWith(isPosting: true));

    final r = await repo.postComment(
      videoId: current.videoId,
      content: event.content,
      parentId: event.parentId,
    );

    r.fold(
      (_) => emit(current.copyWith(isPosting: false)),
      (created) {
        final latestState = state;
        final base = latestState is CommentLoaded ? latestState : current;

        if (event.parentId != null) {
          final targetRootId =
              created.rootId ?? event.rootId ?? event.parentId!;
          final enrichedReply = created.copyWith(
            rootId: targetRootId,
            replyToUsername:
                created.replyToUsername ?? event.replyToUsername,
            replyToContent:
                created.replyToContent ?? event.replyToContent,
          );

          final updated = base.comments.map((root) {
            if (root.id != targetRootId) return root;
            final alreadyExists =
                root.replies.any((item) => item.id == enrichedReply.id);
            final mergedReplies = alreadyExists
                ? root.replies
                : [...root.replies, enrichedReply];
            final newReplyCount = root.replyCount + 1;
            return root.copyWith(
              replies: mergedReplies,
              replyCount: newReplyCount,
              isRepliesCollapsed: false,
              hasMoreReplies: mergedReplies.length < newReplyCount,
            );
          }).toList();

          emit(base.copyWith(comments: updated, isPosting: false));
        } else {
          emit(
            base.copyWith(
              comments: [created, ...base.comments],
              isPosting: false,
            ),
          );
        }
      },
    );
  }

  Future<void> _onDelete(
    CommentDeleteRequested event,
    Emitter<CommentState> emit,
  ) async {
    final current = state;
    if (current is! CommentLoaded) return;
    final r = await repo.deleteComment(event.commentId);
    r.fold((_) {}, (_) {
      final latestState = state;
      final base = latestState is CommentLoaded ? latestState : current;

      // Xóa nếu là bình luận gốc cấp 1
      if (base.comments.any((c) => c.id == event.commentId)) {
        emit(
          base.copyWith(
            comments: base.comments
                .where((c) => c.id != event.commentId)
                .toList(),
          ),
        );
        return;
      }

      // Xóa nếu là câu trả lời con (và các reply con trực tiếp của nó)
      final updated = base.comments.map((root) {
        final hasTarget = root.replies.any((rep) => rep.id == event.commentId);
        if (!hasTarget) return root;

        final removedIds = <String>{event.commentId};
        bool changed = true;
        while (changed) {
          changed = false;
          for (final rep in root.replies) {
            if (rep.parentId != null &&
                removedIds.contains(rep.parentId) &&
                removedIds.add(rep.id)) {
              changed = true;
            }
          }
        }

        final remaining = root.replies
            .where((rep) => !removedIds.contains(rep.id))
            .toList();
        final nextCount = (root.replyCount - removedIds.length) < 0
            ? 0
            : (root.replyCount - removedIds.length);
        return root.copyWith(
          replies: remaining,
          replyCount: nextCount,
          hasMoreReplies: remaining.length < nextCount,
        );
      }).toList();

      emit(base.copyWith(comments: updated));
    });
  }

  Future<void> _onLoadReplies(
    CommentRepliesLoadRequested event,
    Emitter<CommentState> emit,
  ) async {
    final current = state;
    if (current is! CommentLoaded) return;

    final idx = current.comments.indexWhere((c) => c.id == event.parentId);
    if (idx == -1) return;
    final target = current.comments[idx];

    // Nếu trước đó đã tải câu trả lời nhưng người dùng bấm "Ẩn bớt", chỉ cần mở lại ngay
    if (target.isRepliesCollapsed && target.replies.isNotEmpty) {
      final reopened = List<CommentEntity>.from(current.comments);
      reopened[idx] = target.copyWith(isRepliesCollapsed: false);
      emit(current.copyWith(comments: reopened));
      return;
    }

    if (target.isLoadingReplies) return;

    final nextPage = target.loadedReplyPage + 1;
    final loadingList = List<CommentEntity>.from(current.comments);
    loadingList[idx] = target.copyWith(
      isLoadingReplies: true,
      isRepliesCollapsed: false,
    );
    emit(current.copyWith(comments: loadingList));

    final r = await repo.getReplies(parentId: event.parentId, page: nextPage);

    final latest = state;
    if (latest is! CommentLoaded) return;

    r.fold(
      (_) {
        final reverted = latest.comments.map((c) {
          if (c.id == event.parentId) {
            return c.copyWith(isLoadingReplies: false);
          }
          return c;
        }).toList();
        emit(latest.copyWith(comments: reverted));
      },
      (p) {
        final updated = latest.comments.map((c) {
          if (c.id != event.parentId) return c;

          // Hợp nhất tránh trùng ID (ví dụ câu trả lời người dùng vừa tự đăng xong)
          final existingIds = c.replies.map((e) => e.id).toSet();
          final merged = [
            ...c.replies,
            for (final item in p.items)
              if (!existingIds.contains(item.id)) item,
          ];
          merged.sort((a, b) => a.createdAt.compareTo(b.createdAt));

          final totalKnown =
              merged.length > c.replyCount ? merged.length : c.replyCount;

          return c.copyWith(
            replies: merged,
            replyCount: totalKnown,
            loadedReplyPage: p.items.isEmpty ? c.loadedReplyPage : nextPage,
            hasMoreReplies: p.hasMore,
            isLoadingReplies: false,
            isRepliesCollapsed: false,
          );
        }).toList();

        emit(latest.copyWith(comments: updated));
      },
    );
  }

  void _onToggleCollapseReplies(
    CommentRepliesCollapseToggled event,
    Emitter<CommentState> emit,
  ) {
    final current = state;
    if (current is! CommentLoaded) return;

    final updated = current.comments.map((c) {
      if (c.id != event.parentId) return c;
      return c.copyWith(isRepliesCollapsed: !c.isRepliesCollapsed);
    }).toList();

    emit(current.copyWith(comments: updated));
  }

  Future<void> _onToggleLike(
    CommentLikeToggled event,
    Emitter<CommentState> emit,
  ) async {
    final current = state;
    if (current is! CommentLoaded) return;

    final updated = current.comments.map((c) {
      if (c.id == event.commentId) {
        final nextLiked = !c.isLiked;
        return c.copyWith(
          isLiked: nextLiked,
          likeCount: nextLiked
              ? c.likeCount + 1
              : (c.likeCount > 0 ? c.likeCount - 1 : 0),
        );
      }

      if (c.replies.any((r) => r.id == event.commentId)) {
        final nextReplies = c.replies.map((r) {
          if (r.id != event.commentId) return r;
          final nextLiked = !r.isLiked;
          return r.copyWith(
            isLiked: nextLiked,
            likeCount: nextLiked
                ? r.likeCount + 1
                : (r.likeCount > 0 ? r.likeCount - 1 : 0),
          );
        }).toList();
        return c.copyWith(replies: nextReplies);
      }

      return c;
    }).toList();

    emit(current.copyWith(comments: updated));
    await repo.toggleCommentLike(event.commentId);
  }
}
