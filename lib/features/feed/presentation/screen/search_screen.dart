// features/feed/presentation/screen/search_screen.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shareco/features/feed/presentation/bloc/search_bloc.dart';
import 'package:shareco/features/feed/presentation/bloc/search_event.dart';
import 'package:shareco/features/feed/presentation/bloc/search_state.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/storage_image.dart';
import '../../../../routes/app_router.dart';
import '../../../video/domain/entities/video_entity.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with SingleTickerProviderStateMixin {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    // Tự động focus khi mở
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _onSearch(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    _focusNode.unfocus();
    context.read<SearchBloc>().add(SearchSubmitted(trimmed));
  }

  void _onHistoryTap(String query) {
    _controller.text = query;
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: query.length),
    );
    context.read<SearchBloc>().add(SearchSubmitted(query));
  }

  void _onClear() {
    _controller.clear();
    if (!mounted) return;
    context.read<SearchBloc>().add(const SearchReset());
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0A0A),
        body: FadeTransition(
          opacity: _fadeAnim,
          child: Column(
            children: [
              _buildSearchBar(top),
              Expanded(
                child: BlocBuilder<SearchBloc, SearchState>(
                  builder: (_, state) {
                    if (state.isIdle) return _buildIdleView(state.history);
                    if (state.isLoading) return _buildLoading();
                    if (state.status == SearchStatus.failure) {
                      return _buildError(state.errorMessage ?? '');
                    }
                    return _buildResults(state.results, state.query);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Search bar ─────────────────────────────────────────────────────────────

  Widget _buildSearchBar(double top) {
    return Container(
      padding: EdgeInsets.fromLTRB(8, top + 8, 16, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.06)),
        ),
      ),
      child: Row(
        children: [
          // Nút back
          IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: 20,
            ),
            splashRadius: 24,
          ),
          // TextField
          Expanded(
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(12),
              ),
              child: BlocBuilder<SearchBloc, SearchState>(
                buildWhen: (prev, curr) => prev.query != curr.query,
                builder: (_, state) => TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  cursorColor: AppColors.primary,
                  textInputAction: TextInputAction.search,
                  onChanged: (v) =>
                      context.read<SearchBloc>().add(SearchQueryChanged(v)),
                  onSubmitted: _onSearch,
                  decoration: InputDecoration(
                    hintText: 'Tìm video, tài khoản...',
                    hintStyle: TextStyle(
                      color: Colors.white.withOpacity(0.35),
                      fontSize: 15,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: Colors.white38,
                      size: 20,
                    ),
                    suffixIcon: _controller.text.isNotEmpty
                        ? GestureDetector(
                            onTap: _onClear,
                            child: const Icon(
                              Icons.cancel_rounded,
                              color: Colors.white38,
                              size: 18,
                            ),
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Idle: lịch sử tìm kiếm ─────────────────────────────────────────────────

  Widget _buildIdleView(List<String> history) {
    if (history.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.manage_search_rounded,
              color: Colors.white.withOpacity(0.15),
              size: 72,
            ),
            const SizedBox(height: 16),
            Text(
              'Khám phá video thú vị',
              style: TextStyle(
                color: Colors.white.withOpacity(0.3),
                fontSize: 15,
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        _buildSectionHeader(
          'Tìm kiếm gần đây',
          trailing: TextButton(
            onPressed: () =>
                context.read<SearchBloc>().add(const SearchHistoryCleared()),
            child: const Text(
              'Xoá tất cả',
              style: TextStyle(color: AppColors.primary, fontSize: 13),
            ),
          ),
        ),
        const SizedBox(height: 4),
        ...history.map((h) => _buildHistoryTile(h)),
      ],
    );
  }

  Widget _buildHistoryTile(String query) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: const Icon(
        Icons.history_rounded,
        color: Colors.white38,
        size: 20,
      ),
      title: Text(
        query,
        style: const TextStyle(color: Colors.white, fontSize: 15),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.close_rounded, color: Colors.white38, size: 18),
        splashRadius: 18,
        onPressed: () =>
            context.read<SearchBloc>().add(SearchHistoryRemoved(query)),
      ),
      onTap: () => _onHistoryTap(query),
    );
  }

  // ─── Loading ─────────────────────────────────────────────────────────────────

  Widget _buildLoading() => const Center(
    child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
  );

  // ─── Error ───────────────────────────────────────────────────────────────────

  Widget _buildError(String msg) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.search_off_rounded,
          color: Colors.white.withOpacity(0.25),
          size: 64,
        ),
        const SizedBox(height: 16),
        Text(
          msg,
          style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 15),
        ),
      ],
    ),
  );

  // ─── Kết quả ─────────────────────────────────────────────────────────────────

  Widget _buildResults(List<VideoEntity> videos, String query) {
    if (videos.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.videocam_off_outlined,
              color: Colors.white.withOpacity(0.2),
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              'Không có kết quả cho "$query"',
              style: TextStyle(
                color: Colors.white.withOpacity(0.35),
                fontSize: 15,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          sliver: SliverToBoxAdapter(
            child: Text(
              '${videos.length} kết quả cho "$query"',
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 13,
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate(
              (_, i) => _VideoResultCard(
                video: videos[i],
                onTap: () => context.push(
                  Routes.searchFeedViewer,
                  extra: {
                    'videos': videos,
                    'initialIndex': i,
                  },
                ),
              ),
              childCount: videos.length,
            ),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 9 / 16,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  Widget _buildSectionHeader(String title, {Widget? trailing}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }
}

// ─── Video result card ────────────────────────────────────────────────────────

class _VideoResultCard extends StatelessWidget {
  final VideoEntity video;
  final VoidCallback onTap;

  const _VideoResultCard({required this.video, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final thumbUrl = video.thumbnailPath != null
        ? StorageImage.thumbnailUrl(video.thumbnailPath!)
        : null;

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: thumbUrl != null
                ? CachedNetworkImage(
                    imageUrl: thumbUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) =>
                        Container(color: const Color(0xFF1A1A1A)),
                    errorWidget: (_, __, ___) =>
                        Container(color: const Color(0xFF1A1A1A)),
                  )
                : Container(color: const Color(0xFF1A1A1A)),
          ),
          // Gradient + thông tin
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xCC000000)],
                  stops: [0.55, 1],
                ),
              ),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Like count
                      Row(
                        children: [
                          const Icon(
                            Icons.favorite,
                            color: Colors.white70,
                            size: 12,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            StorageImage.formatCount(video.likeCount),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      // Username
                      Text(
                        '@${video.author.username}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
