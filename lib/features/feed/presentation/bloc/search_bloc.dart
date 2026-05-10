// features/feed/presentation/bloc/search/search_bloc.dart

import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shareco/features/feed/presentation/bloc/search_event.dart';
import 'package:shareco/features/feed/presentation/bloc/search_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../../features/video/domain/entities/video_entity.dart';
import '../../../../../features/video/domain/repositories/video_repository.dart';

class SearchBloc extends Bloc<SearchEvent, SearchState> {
  final VideoRepository _videoRepository;

  static const _historyKey = 'search_history';
  static const _maxHistory = 10;
  static const _debounce = Duration(milliseconds: 450);

  Timer? _debounceTimer;

  SearchBloc({required VideoRepository videoRepository})
      : _videoRepository = videoRepository,
        super(const SearchState()) {
    on<SearchQueryChanged>(_onQueryChanged);
    on<SearchSubmitted>(_onSubmitted);
    on<SearchHistoryRemoved>(_onHistoryRemoved);
    on<SearchHistoryCleared>(_onHistoryCleared);
    on<SearchReset>(_onReset);

    _loadHistory();
  }

  // ─── Lịch sử ────────────────────────────────────────────────────────────────

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList(_historyKey) ?? [];
    emit(state.copyWith(history: history));
  }

  Future<void> _saveHistory(List<String> history) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_historyKey, history);
  }

  List<String> _addToHistory(List<String> current, String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return current;
    final updated = [trimmed, ...current.where((h) => h != trimmed)];
    return updated.take(_maxHistory).toList();
  }

  // ─── Handlers ───────────────────────────────────────────────────────────────

  void _onQueryChanged(SearchQueryChanged event, Emitter<SearchState> emit) {
    _debounceTimer?.cancel();
    final query = event.query.trim();

    if (query.isEmpty) {
      emit(state.copyWith(
        query: '',
        status: SearchStatus.idle,
        results: [],
      ));
      return;
    }

    emit(state.copyWith(query: query, status: SearchStatus.loading));

    _debounceTimer = Timer(_debounce, () {
      if (!isClosed) add(SearchSubmitted(query));
    });
  }

  Future<void> _onSubmitted(
      SearchSubmitted event, Emitter<SearchState> emit) async {
    _debounceTimer?.cancel();
    final query = event.query.trim();
    if (query.isEmpty) return;

    emit(state.copyWith(query: query, status: SearchStatus.loading));

    try {
      // Gọi repository — bạn có thể thay bằng AI search nếu muốn
      final result = await _videoRepository.searchVideos(query);

      final newHistory = _addToHistory(state.history, query);
      _saveHistory(newHistory);

      emit(state.copyWith(
        status: SearchStatus.success,
        results: result,
        history: newHistory,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: SearchStatus.failure,
        errorMessage: 'Không tìm thấy kết quả. Thử lại nhé!',
      ));
    }
  }

  void _onHistoryRemoved(
      SearchHistoryRemoved event, Emitter<SearchState> emit) {
    final updated = state.history.where((h) => h != event.query).toList();
    _saveHistory(updated);
    emit(state.copyWith(history: updated));
  }

  void _onHistoryCleared(
      SearchHistoryCleared event, Emitter<SearchState> emit) {
    _saveHistory([]);
    emit(state.copyWith(history: []));
  }

  void _onReset(SearchReset event, Emitter<SearchState> emit) {
    _debounceTimer?.cancel();
    emit(state.copyWith(
      query: '',
      status: SearchStatus.idle,
      results: [],
      errorMessage: null,
    ));
  }

  @override
  Future<void> close() {
    _debounceTimer?.cancel();
    return super.close();
  }
}