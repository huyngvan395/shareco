import 'package:flutter_bloc/flutter_bloc.dart';
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
  }

  Future<void> _onLoad(CommentLoadRequested event, Emitter<CommentState> emit) async {
    emit(const CommentLoading());
    final r = await repo.getComments(videoId: event.videoId, page: 0);
    r.fold(
          (f) => emit(CommentError(f.message)),
          (p) => emit(CommentLoaded(
          videoId: event.videoId, comments: p.items,
          hasReachedMax: !p.hasMore)),
    );
  }

  Future<void> _onLoadMore(CommentLoadMoreRequested _, Emitter<CommentState> emit) async {
    final current = state;
    if (current is! CommentLoaded) return;
    if (current.isLoadingMore || current.hasReachedMax) return;
    emit(current.copyWith(isLoadingMore: true));
    final next = current.currentPage + 1;
    final r = await repo.getComments(videoId: current.videoId, page: next);
    r.fold(
          (_) => emit(current.copyWith(isLoadingMore: false)),
          (p) => emit(current.copyWith(
        comments: [...current.comments, ...p.items],
        isLoadingMore: false,
        currentPage: next,
        hasReachedMax: !p.hasMore,
      )),
    );
  }

  Future<void> _onPost(CommentPostRequested event, Emitter<CommentState> emit) async {
    final current = state;
    if (current is! CommentLoaded) return;
    emit(current.copyWith(isPosting: true));
    final r = await repo.postComment(
      videoId: current.videoId,
      content: event.content,
      parentId: event.parentId,
    );
    r.fold(
          (f) => emit(current.copyWith(isPosting: false)),
          (c) => emit(current.copyWith(
        comments: [c, ...current.comments],
        isPosting: false,
      )),
    );
  }

  Future<void> _onDelete(CommentDeleteRequested event, Emitter<CommentState> emit) async {
    final current = state;
    if (current is! CommentLoaded) return;
    final r = await repo.deleteComment(event.commentId);
    r.fold(
          (_) {},
          (_) => emit(current.copyWith(
        comments: current.comments.where((c) => c.id != event.commentId).toList(),
      )),
    );
  }

  Future<void> _onLoadReplies(
      CommentRepliesLoadRequested event, Emitter<CommentState> emit) async {
    final current = state;
    if (current is! CommentLoaded) return;
    final r = await repo.getReplies(parentId: event.parentId, page: 0);
    r.fold(
          (_) {},
          (p) => emit(current.copyWith(
        comments: current.comments.map((c) {
          if (c.id == event.parentId) return c.copyWith(replies: p.items);
          return c;
        }).toList(),
      )),
    );
  }
}