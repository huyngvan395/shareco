// features/feed/presentation/bloc/search/search_state.dart

import 'package:equatable/equatable.dart';
import 'package:shareco/features/video/domain/entities/video_entity.dart';

enum SearchStatus { idle, loading, success, failure }

class SearchState extends Equatable {
  final String query;
  final SearchStatus status;
  final List<VideoEntity> results;
  final List<String> history;       // lịch sử tìm kiếm (lưu local)
  final String? errorMessage;

  const SearchState({
    this.query = '',
    this.status = SearchStatus.idle,
    this.results = const [],
    this.history = const [],
    this.errorMessage,
  });

  bool get isIdle => status == SearchStatus.idle;
  bool get isLoading => status == SearchStatus.loading;

  SearchState copyWith({
    String? query,
    SearchStatus? status,
    List<VideoEntity>? results,
    List<String>? history,
    String? errorMessage,
  }) =>
      SearchState(
        query: query ?? this.query,
        status: status ?? this.status,
        results: results ?? this.results,
        history: history ?? this.history,
        errorMessage: errorMessage,
      );

  @override
  List<Object?> get props => [query, status, results, history, errorMessage];
}