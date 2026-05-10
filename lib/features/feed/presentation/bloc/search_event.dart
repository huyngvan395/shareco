// features/feed/presentation/bloc/search/search_event.dart
import 'package:equatable/equatable.dart';

abstract class SearchEvent extends Equatable {
  const SearchEvent();

  @override
  List<Object?> get props => [];
}

/// Người dùng gõ vào ô tìm kiếm
class SearchQueryChanged extends SearchEvent {
  final String query;
  const SearchQueryChanged(this.query);

  @override
  List<Object?> get props => [query];
}

/// Người dùng nhấn submit / enter
class SearchSubmitted extends SearchEvent {
  final String query;
  const SearchSubmitted(this.query);

  @override
  List<Object?> get props => [query];
}

/// Xoá một từ khoá khỏi lịch sử
class SearchHistoryRemoved extends SearchEvent {
  final String query;
  const SearchHistoryRemoved(this.query);

  @override
  List<Object?> get props => [query];
}

/// Xoá toàn bộ lịch sử
class SearchHistoryCleared extends SearchEvent {
  const SearchHistoryCleared();
}

/// Reset về màn hình ban đầu (khi bấm X)
class SearchReset extends SearchEvent {
  const SearchReset();
}