import 'package:equatable/equatable.dart';
import 'package:shareco/features/comment/domain/entities/comment_entity.dart';

abstract class CommentState extends Equatable {
  const CommentState();
  @override List<Object?> get props => [];
}

class CommentInitial extends CommentState { const CommentInitial(); }
class CommentLoading extends CommentState { const CommentLoading(); }

class CommentLoaded extends CommentState {
  final String videoId;
  final List<CommentEntity> comments;
  final bool isLoadingMore;
  final bool hasReachedMax;
  final int currentPage;
  final bool isPosting;

  const CommentLoaded({
    required this.videoId,
    required this.comments,
    this.isLoadingMore = false,
    this.hasReachedMax = false,
    this.currentPage = 0,
    this.isPosting = false,
  });

  CommentLoaded copyWith({
    List<CommentEntity>? comments,
    bool? isLoadingMore,
    bool? hasReachedMax,
    int? currentPage,
    bool? isPosting,
  }) => CommentLoaded(
    videoId: videoId,
    comments: comments ?? this.comments,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    hasReachedMax: hasReachedMax ?? this.hasReachedMax,
    currentPage: currentPage ?? this.currentPage,
    isPosting: isPosting ?? this.isPosting,
  );

  @override
  List<Object?> get props => [videoId, comments, isLoadingMore, hasReachedMax, isPosting];
}

class CommentError extends CommentState {
  final String message;
  const CommentError(this.message);
  @override List<Object?> get props => [message];
}