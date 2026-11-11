// features/video/domain/entities/filter_entity.dart

import 'dart:convert';
import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

// ─── Colour & AR Effect Filter ────────────────────────────────────────────────

class VideoFilter {
  final String id;
  final String name;
  final String subtitle;
  final String creator;
  final String category;
  final String? thumbnailUrl;
  final String? overlayType;
  final String? badgeText;
  final ColorFilter? colorFilter;
  final double intensity;
  final List<Color> previewColors;

  const VideoFilter({
    required this.id,
    required this.name,
    this.subtitle = '',
    this.creator = 'shareco_studio',
    this.category = 'Thịnh hành',
    this.thumbnailUrl,
    this.overlayType,
    this.badgeText,
    this.colorFilter,
    this.intensity = 1.0,
    this.previewColors = const [Color(0xFF3A7BD5), Color(0xFF00D2FF)],
  });
}

abstract class AppFilters {
  /// Bộ nhớ lưu các filter đã bấm "Đã lưu" (Bookmark)
  static final Set<String> savedIds = {'1994', 'ulzzang_glow', 'peach'};

  static bool isSaved(String id) => savedIds.contains(id);

  static bool toggleSaved(String id) {
    if (id == 'none') return false;
    if (savedIds.contains(id)) {
      savedIds.remove(id);
      return false;
    } else {
      savedIds.add(id);
      return true;
    }
  }

  static const List<String> categories = [
    'Thịnh hành',
    'Game',
    'Vui nhộn',
    'Chân dung',
    'Vintage',
    'Điện ảnh',
  ];

  static const none = VideoFilter(
    id: 'none',
    name: 'Gốc',
    subtitle: 'Mặc định',
    creator: 'shareco',
    category: 'Thịnh hành',
    previewColors: [Color(0xFF434343), Color(0xFF1A1A1A)],
  );

  // ── 1. Nhóm Thịnh hành & Vintage / AR nổi bật (Giống ảnh mẫu) ──────────────
  static const f1994 = VideoFilter(
    id: '1994',
    name: '1994',
    subtitle: 'Nắng vàng cổ điển',
    creator: 'truongmehanh',
    category: 'Thịnh hành',
    thumbnailUrl:
        'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=240&q=80',
    overlayType: '1994_glow',
    previewColors: [Color(0xFFF6D365), Color(0xFFFDA085)],
    colorFilter: ColorFilter.matrix([
      1.16, 0.12, 0.04, 0, 18,
      0.06, 1.12, 0.04, 0, 14,
      -0.02, 0.04, 0.82, 0, -6,
      0, 0, 0, 1, 0,
    ]),
  );

  static const moustacheBeret = VideoFilter(
    id: 'moustache_beret',
    name: 'Quý ông 90s',
    subtitle: 'Ria mép & Mũ nồi',
    creator: 'ar_vibe_vn',
    category: 'Thịnh hành',
    thumbnailUrl:
        'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=240&q=80',
    overlayType: 'moustache_beret',
    badgeText: '🥸',
    previewColors: [Color(0xFF8E7852), Color(0xFF3E3529)],
    colorFilter: ColorFilter.matrix([
      1.08, 0.06, 0.02, 0, 12,
      0.04, 1.04, 0.02, 0, 8,
      0.02, 0.04, 0.90, 0, 4,
      0, 0, 0, 1, 0,
    ]),
  );

  static const cryTear = VideoFilter(
    id: 'cry_tear',
    name: 'Khóc nhè',
    subtitle: 'Nước mắt cute',
    creator: 'linh_cute_ar',
    category: 'Thịnh hành',
    thumbnailUrl:
        'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=240&q=80',
    overlayType: 'cry_tears',
    badgeText: '😭',
    previewColors: [Color(0xFF74EBD5), Color(0xFF9FACE6)],
    colorFilter: ColorFilter.matrix([
      1.12, 0.03, 0.04, 0, 10,
      0.02, 1.08, 0.04, 0, 8,
      0.02, 0.05, 1.12, 0, 12,
      0, 0, 0, 1, 0,
    ]),
  );

  static const ulzzangGlow = VideoFilter(
    id: 'ulzzang_glow',
    name: 'Nàng thơ Hàn',
    subtitle: 'Da trắng hồng mịn',
    creator: 'seoul_beauty',
    category: 'Thịnh hành',
    thumbnailUrl:
        'https://images.unsplash.com/photo-1529626455594-4ff0802cfb7e?w=240&q=80',
    overlayType: 'soft_bloom',
    previewColors: [Color(0xFFFF9A9E), Color(0xFFFECFEF)],
    colorFilter: ColorFilter.matrix([
      1.18, 0.05, 0.05, 0, 16,
      0.03, 1.10, 0.04, 0, 12,
      0.03, 0.06, 1.12, 0, 14,
      0, 0, 0, 1, 0,
    ]),
  );

  static const f1Driver = VideoFilter(
    id: 'f1_driver',
    name: 'Favorite F1 driver',
    subtitle: 'Mini Game F1',
    creator: 'motorsport_fx',
    category: 'Game',
    overlayType: 'f1_game',
    badgeText: 'Favorite\nF1 driver',
    previewColors: [Color(0xFFE50914), Color(0xFFB81D24)],
    colorFilter: ColorFilter.matrix([
      1.10, 0.0, 0.0, 0, 6,
      0.0, 1.05, 0.0, 0, 4,
      0.0, 0.0, 1.05, 0, 4,
      0, 0, 0, 1, 0,
    ]),
  );

  static const pinkCap = VideoFilter(
    id: 'pink_cap',
    name: 'Mũ heo hồng',
    subtitle: 'Má hồng kawaii',
    creator: 'kawaii_studio',
    category: 'Thịnh hành',
    thumbnailUrl:
        'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=240&q=80',
    overlayType: 'pink_cap',
    badgeText: '🧢💕',
    previewColors: [Color(0xFFFF758C), Color(0xFFFF7EB3)],
    colorFilter: ColorFilter.matrix([
      1.16, 0.04, 0.06, 0, 14,
      0.02, 1.06, 0.03, 0, 8,
      0.04, 0.04, 1.10, 0, 12,
      0, 0, 0, 1, 0,
    ]),
  );

  static const bugBeard = VideoFilter(
    id: 'bug_beard',
    name: 'Râu kiến hài',
    subtitle: 'Hiệu ứng vui nhộn',
    creator: 'funny_ar',
    category: 'Vui nhộn',
    thumbnailUrl:
        'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=240&q=80',
    overlayType: 'bug_antenna',
    badgeText: '🐜🧔',
    previewColors: [Color(0xFF606C88), Color(0xFF3F4C6B)],
    colorFilter: ColorFilter.matrix([
      1.05, 0.02, 0.0, 0, 6,
      0.02, 1.04, 0.0, 0, 4,
      0.0, 0.02, 0.98, 0, 2,
      0, 0, 0, 1, 0,
    ]),
  );

  static const bwMoto = VideoFilter(
    id: 'bw_moto',
    name: 'Cool B&W',
    subtitle: 'Đen trắng ngầu',
    creator: 'street_vibe',
    category: 'Điện ảnh',
    thumbnailUrl:
        'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=240&q=80',
    overlayType: 'film_vignette',
    previewColors: [Color(0xFF434343), Color(0xFF000000)],
    colorFilter: ColorFilter.matrix([
      0.38, 0.62, 0.12, 0, -8,
      0.38, 0.62, 0.12, 0, -8,
      0.38, 0.62, 0.12, 0, -8,
      0, 0, 0, 1, 0,
    ]),
  );

  static const findCockroach = VideoFilter(
    id: 'find_cockroach',
    name: 'Find Cockroach',
    subtitle: 'Game tinh mắt',
    creator: 'arcade_play',
    category: 'Game',
    overlayType: 'cockroach_game',
    badgeText: 'Find\nCockroach 🪳',
    previewColors: [Color(0xFF00C6FF), Color(0xFFFFB75E)],
    colorFilter: ColorFilter.matrix([
      1.12, 0, 0, 0, 5,
      0, 1.12, 0, 0, 5,
      0, 0, 1.12, 0, 5,
      0, 0, 0, 1, 0,
    ]),
  );

  static const catSanta = VideoFilter(
    id: 'cat_santa',
    name: 'Mèo đội mũ',
    subtitle: 'Tai mèo đáng yêu',
    creator: 'meow_creator',
    category: 'Vui nhộn',
    thumbnailUrl:
        'https://images.unsplash.com/photo-1514888286974-6c03e2ca1dba?w=240&q=80',
    overlayType: 'cat_ears',
    badgeText: '🐱🎅',
    previewColors: [Color(0xFFFF512F), Color(0xFFDD2476)],
    colorFilter: ColorFilter.matrix([
      1.14, 0.04, 0.02, 0, 10,
      0.02, 1.08, 0.02, 0, 8,
      0.0, 0.02, 1.04, 0, 6,
      0, 0, 0, 1, 0,
    ]),
  );

  static const butterflyDream = VideoFilter(
    id: 'butterfly_dream',
    name: 'Bươm bướm',
    subtitle: 'Lấp lánh mộng mơ',
    creator: 'dreamy_fx',
    category: 'Chân dung',
    thumbnailUrl:
        'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=240&q=80',
    overlayType: 'butterfly_dream',
    badgeText: '🦋✨',
    previewColors: [Color(0xFFA18CD1), Color(0xFFFBC2EB)],
    colorFilter: ColorFilter.matrix([
      1.14, 0.04, 0.06, 0, 12,
      0.02, 1.08, 0.06, 0, 10,
      0.06, 0.04, 1.18, 0, 16,
      0, 0, 0, 1, 0,
    ]),
  );

  static const fortune2026 = VideoFilter(
    id: 'fortune_2026',
    name: 'Tiên tri 2026',
    subtitle: 'Dự đoán vận may',
    creator: 'tarot_vn',
    category: 'Game',
    overlayType: 'fortune_game',
    badgeText: 'Tiên tri\n2026 🔮',
    previewColors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
    colorFilter: ColorFilter.matrix([
      1.10, 0.02, 0.06, 0, 8,
      0.02, 1.06, 0.04, 0, 6,
      0.04, 0.02, 1.14, 0, 12,
      0, 0, 0, 1, 0,
    ]),
  );

  // ── 2. Các bộ lọc màu kinh điển (Chân dung, Vintage, Điện ảnh) ─────────────
  static const peach = VideoFilter(
    id: 'peach',
    name: 'Hồng đào',
    subtitle: 'Chân dung ngọt ngào',
    creator: 'shareco_beauty',
    category: 'Chân dung',
    thumbnailUrl:
        'https://images.unsplash.com/photo-1531746020798-e6953c6e8e04?w=240&q=80',
    overlayType: 'soft_bloom',
    previewColors: [Color(0xFFFF9A9E), Color(0xFFFECFEF)],
    colorFilter: ColorFilter.matrix([
      1.15, 0.05, 0.05, 0, 14,
      0.02, 1.05, 0.02, 0, 8,
      0.02, 0.05, 1.02, 0, 10,
      0, 0, 0, 1, 0,
    ]),
  );

  static const vivid = VideoFilter(
    id: 'vivid',
    name: 'Sống động',
    subtitle: 'Tươi tắn rực rỡ',
    creator: 'shareco_color',
    category: 'Chân dung',
    thumbnailUrl:
        'https://images.unsplash.com/photo-1488426862026-3ee34a7d66df?w=240&q=80',
    previewColors: [Color(0xFFFF416C), Color(0xFFFF4B2B)],
    colorFilter: ColorFilter.matrix([
      1.25, -0.08, -0.08, 0, 5,
      -0.05, 1.22, -0.05, 0, 5,
      -0.05, -0.08, 1.28, 0, 5,
      0, 0, 0, 1, 0,
    ]),
  );

  static const vintage = VideoFilter(
    id: 'vintage',
    name: 'Kodak 1998',
    subtitle: 'Phim màu Retro',
    creator: 'film_analog',
    category: 'Vintage',
    thumbnailUrl:
        'https://images.unsplash.com/photo-1502823403499-6ccfcf4fb453?w=240&q=80',
    overlayType: 'vhs_retro',
    previewColors: [Color(0xFFD1913C), Color(0xFFFFD194)],
    colorFilter: ColorFilter.matrix([
      0.96, 0.15, 0.10, 0, 12,
      0.08, 0.88, 0.08, 0, 6,
      0.05, 0.08, 0.68, 0, -2,
      0, 0, 0, 1, 0,
    ]),
  );

  static const cool = VideoFilter(
    id: 'cool',
    name: 'Lạnh băng',
    subtitle: 'Tone xanh Bắc Âu',
    creator: 'nordic_tone',
    category: 'Điện ảnh',
    thumbnailUrl:
        'https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?w=240&q=80',
    previewColors: [Color(0xFF00C6FF), Color(0xFF0072FF)],
    colorFilter: ColorFilter.matrix([
      0.84, 0, 0, 0, 0,
      0, 0.96, 0.05, 0, 4,
      0, 0.08, 1.24, 0, 12,
      0, 0, 0, 1, 0,
    ]),
  );

  static const warm = VideoFilter(
    id: 'warm',
    name: 'Hoàng hôn',
    subtitle: 'Nắng chiều ấm áp',
    creator: 'golden_hour',
    category: 'Vintage',
    thumbnailUrl:
        'https://images.unsplash.com/photo-1524250502761-1ac6f2e30d43?w=240&q=80',
    overlayType: '1994_glow',
    previewColors: [Color(0xFFF7971E), Color(0xFFFFD200)],
    colorFilter: ColorFilter.matrix([
      1.20, 0.05, 0, 0, 10,
      0, 1.02, 0, 0, 4,
      0, 0, 0.78, 0, -5,
      0, 0, 0, 1, 0,
    ]),
  );

  static const dramatic = VideoFilter(
    id: 'dramatic',
    name: 'Điện ảnh',
    subtitle: 'Tương phản sâu',
    creator: 'cinema_lut',
    category: 'Điện ảnh',
    thumbnailUrl:
        'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=240&q=80',
    overlayType: 'film_vignette',
    previewColors: [Color(0xFF141E30), Color(0xFF243B55)],
    colorFilter: ColorFilter.matrix([
      1.35, -0.10, -0.10, 0, -10,
      -0.10, 1.30, -0.05, 0, -8,
      -0.05, -0.05, 1.38, 0, 4,
      0, 0, 0, 1, 0,
    ]),
  );

  static const neon = VideoFilter(
    id: 'neon',
    name: 'Cyberpunk',
    subtitle: 'Ánh tím Neon',
    creator: 'neon_city',
    category: 'Điện ảnh',
    thumbnailUrl:
        'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=240&q=80',
    overlayType: 'neon_glow',
    previewColors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
    colorFilter: ColorFilter.matrix([
      1.08, 0, 0.22, 0, 8,
      0, 0.95, 0.35, 0, 0,
      0.28, 0, 1.28, 0, 16,
      0, 0, 0, 1, 0,
    ]),
  );

  static const fade = VideoFilter(
    id: 'fade',
    name: 'Phim xưa',
    subtitle: 'Mờ sương Fuji',
    creator: 'fuji_film',
    category: 'Vintage',
    thumbnailUrl:
        'https://images.unsplash.com/photo-1517365830460-955ce3ccd263?w=240&q=80',
    previewColors: [Color(0xFF757F9A), Color(0xFFD7DDE8)],
    colorFilter: ColorFilter.matrix([
      0.85, 0.04, 0.04, 0, 26,
      0.04, 0.85, 0.04, 0, 26,
      0.04, 0.04, 0.88, 0, 30,
      0, 0, 0, 1, 0,
    ]),
  );

  static const bw = VideoFilter(
    id: 'bw',
    name: 'Trắng đen',
    subtitle: 'Monochrome',
    creator: 'mono_art',
    category: 'Điện ảnh',
    thumbnailUrl:
        'https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?w=240&q=80',
    previewColors: [Color(0xFF8E9EAB), Color(0xFF232526)],
    colorFilter: ColorFilter.matrix([
      0.33, 0.59, 0.11, 0, 0,
      0.33, 0.59, 0.11, 0, 0,
      0.33, 0.59, 0.11, 0, 0,
      0, 0, 0, 1, 0,
    ]),
  );

  static const List<VideoFilter> all = [
    none,
    f1994,
    moustacheBeret,
    cryTear,
    ulzzangGlow,
    f1Driver,
    pinkCap,
    bugBeard,
    bwMoto,
    findCockroach,
    catSanta,
    butterflyDream,
    fortune2026,
    peach,
    vivid,
    vintage,
    cool,
    warm,
    dramatic,
    neon,
    fade,
    bw,
  ];

  static List<VideoFilter> byCategory(String category) {
    final visible = all.where((f) => f.id != 'none').toList();
    if (category == 'Thịnh hành') {
      return visible;
    }
    if (category == 'Đã lưu') {
      return visible.where((f) => savedIds.contains(f.id)).toList();
    }
    return visible.where((f) => f.category == category).toList();
  }

  static VideoFilter byId(String? id) {
    if (id == null || id.isEmpty) return none;
    for (final f in all) {
      if (f.id == id) return f;
    }
    return none;
  }
}

/// Bộ xử lý hiển thị Bộ lọc màu + Hiệu ứng ánh sáng (Light Leak 1994, Soft Bloom, VHS)
/// + Hiệu ứng AR / Mini Game trực tiếp trên khung hình Camera, Edit Video và Feed.
class VideoFilterEffectRenderer extends StatefulWidget {
  final VideoFilter filter;
  final Widget child;
  final bool showInteractiveOverlays;

  const VideoFilterEffectRenderer({
    super.key,
    required this.filter,
    required this.child,
    this.showInteractiveOverlays = true,
  });

  @override
  State<VideoFilterEffectRenderer> createState() =>
      _VideoFilterEffectRendererState();
}

class _VideoFilterEffectRendererState extends State<VideoFilterEffectRenderer>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  int _gameSelectionIndex = 0;

  static const _f1Drivers = [
    '🏎️ Charles Leclerc · Ferrari #16',
    '🏆 Max Verstappen · Red Bull #1',
    '🔥 Lewis Hamilton · Ferrari #44',
    '⚡ Lando Norris · McLaren #4',
    '🌟 Carlos Sainz · Williams #55',
  ];

  static const _fortunes2026 = [
    '💰 Tiền vào như nước, Đại cát đại lợi!',
    '❤️ Tình duyên nở rộ, Thoát ế thành công!',
    '🚀 Sự nghiệp thăng hoa, Điểm cao chót vót!',
    '✈️ Đi du lịch khắp nơi, Trải nghiệm rực rỡ!',
    '💎 Mua nhà tậu xe, Vạn sự như ý!',
  ];

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.filter;
    if (f.id == 'none') return widget.child;

    Widget content = widget.child;
    if (f.colorFilter != null) {
      content = ColorFiltered(colorFilter: f.colorFilter!, child: content);
    }

    final overlay = f.overlayType;
    if (overlay == null || !widget.showInteractiveOverlays) {
      return content;
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        content,
        ..._buildOverlayLayers(overlay),
      ],
    );
  }

  List<Widget> _buildOverlayLayers(String overlay) {
    switch (overlay) {
      case '1994_glow':
        // Hiệu ứng ánh nắng vàng kem cổ điển 1994 (Light leak + Warm bloom ở nửa trên như ảnh mẫu)
        return [
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.35, -0.55),
                  radius: 1.15,
                  colors: [
                    const Color(0xFFFFFACD).withValues(alpha: 0.42),
                    const Color(0xFFFFE4B5).withValues(alpha: 0.22),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.48, 1.0],
                ),
              ),
            ),
          ),
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFFFFF8DC).withValues(alpha: 0.28),
                    Colors.transparent,
                    const Color(0xFF3E2723).withValues(alpha: 0.16),
                  ],
                ),
              ),
            ),
          ),
        ];

      case 'soft_bloom':
        return [
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.0, -0.2),
                  radius: 0.9,
                  colors: [
                    const Color(0xFFFFF0F5).withValues(alpha: 0.22),
                    const Color(0xFFFFB6C1).withValues(alpha: 0.10),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ];

      case 'neon_glow':
        return [
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFFFF007F).withValues(alpha: 0.20),
                    Colors.transparent,
                    const Color(0xFF00F0FF).withValues(alpha: 0.22),
                  ],
                ),
              ),
            ),
          ),
        ];

      case 'film_vignette':
        return [
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 0.85,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.45),
                  ],
                  stops: const [0.55, 1.0],
                ),
              ),
            ),
          ),
        ];

      case 'vhs_retro':
        return [
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFFFF9900).withValues(alpha: 0.16),
                    Colors.transparent,
                    const Color(0xFF331100).withValues(alpha: 0.25),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 150,
            right: 24,
            child: IgnorePointer(
              child: Text(
                'PLAY ▶  1998.11.11',
                style: TextStyle(
                  color: const Color(0xFFFFCC66).withValues(alpha: 0.85),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.0,
                  shadows: const [
                    Shadow(color: Colors.black87, blurRadius: 4),
                  ],
                ),
              ),
            ),
          ),
        ];

      case 'cry_tears':
        return [
          IgnorePointer(
            child: AnimatedBuilder(
              animation: _animCtrl,
              builder: (_, _) {
                final dy = _animCtrl.value * 8;
                return Stack(
                  children: [
                    Align(
                      alignment: const Alignment(0.0, -0.18),
                      child: Transform.translate(
                        offset: Offset(0, dy),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildTearStream(isLeft: true),
                                const SizedBox(width: 56),
                                _buildTearStream(isLeft: false),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ];

      case 'moustache_beret':
        return [
          IgnorePointer(
            child: Align(
              alignment: const Alignment(0.0, -0.22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 26,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6D4C41).withValues(alpha: 0.85),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(30),
                        bottom: Radius.circular(8),
                      ),
                      border: Border.all(color: Colors.black54, width: 2),
                    ),
                    child: const Text(
                      '🎩 VINTAGE 90s',
                      style: TextStyle(
                        color: Color(0xFFFFECB3),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 68),
                  const Text(
                    '〰️🥸〰️',
                    style: TextStyle(
                      fontSize: 44,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ];

      case 'pink_cap':
        return [
          IgnorePointer(
            child: Align(
              alignment: const Alignment(0.0, -0.26),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF758C), Color(0xFFFF7EB3)],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 8),
                      ],
                    ),
                    child: const Text(
                      '🐷 CUTE GIRL 💕',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(height: 54),
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('🌸', style: TextStyle(fontSize: 24)),
                      SizedBox(width: 82),
                      Text('🌸', style: TextStyle(fontSize: 24)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ];

      case 'bug_antenna':
        return [
          IgnorePointer(
            child: Align(
              alignment: const Alignment(0.0, -0.25),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Text(
                    '🌱   🌱',
                    style: TextStyle(
                      fontSize: 38,
                      shadows: [Shadow(color: Colors.black45, blurRadius: 6)],
                    ),
                  ),
                  SizedBox(height: 44),
                  Text(
                    '👀',
                    style: TextStyle(fontSize: 36),
                  ),
                ],
              ),
            ),
          ),
        ];

      case 'cat_ears':
        return [
          IgnorePointer(
            child: Align(
              alignment: const Alignment(0.0, -0.28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('🐾', style: TextStyle(fontSize: 32)),
                      SizedBox(width: 24),
                      Text('🎅', style: TextStyle(fontSize: 38)),
                      SizedBox(width: 24),
                      Text('🐾', style: TextStyle(fontSize: 32)),
                    ],
                  ),
                  SizedBox(height: 52),
                  Text(
                    '≡  🐱  ≡',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ];

      case 'butterfly_dream':
        return [
          IgnorePointer(
            child: AnimatedBuilder(
              animation: _animCtrl,
              builder: (_, _) {
                final offset = (_animCtrl.value - 0.5) * 12;
                return Align(
                  alignment: const Alignment(0.0, -0.25),
                  child: Transform.translate(
                    offset: Offset(0, offset),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('🦋', style: TextStyle(fontSize: 30)),
                        SizedBox(width: 30),
                        Text('✨', style: TextStyle(fontSize: 24)),
                        SizedBox(width: 30),
                        Text('🦋', style: TextStyle(fontSize: 30)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ];

      case 'f1_game':
        return [
          Align(
            alignment: const Alignment(0.0, -0.42),
            child: GestureDetector(
              onTap: () => setState(() {
                _gameSelectionIndex =
                    (_gameSelectionIndex + 1) % _f1Drivers.length;
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE50914), Color(0xFFB81D24)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black45,
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'FAVORITE F1 DRIVER (Chạm để đổi)',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _f1Drivers[_gameSelectionIndex % _f1Drivers.length],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ];

      case 'fortune_game':
        return [
          Align(
            alignment: const Alignment(0.0, -0.42),
            child: GestureDetector(
              onTap: () => setState(() {
                _gameSelectionIndex =
                    (_gameSelectionIndex + 1) % _fortunes2026.length;
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.amberAccent, width: 2),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black45,
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '🔮 TIÊN TRI 2026 CỦA BẠN (Chạm để gieo quẻ)',
                      style: TextStyle(
                        color: Colors.amberAccent,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _fortunes2026[_gameSelectionIndex % _fortunes2026.length],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ];

      case 'cockroach_game':
        return [
          IgnorePointer(
            child: AnimatedBuilder(
              animation: _animCtrl,
              builder: (_, _) {
                final dx = (_animCtrl.value - 0.5) * 140;
                final dy = (0.5 - _animCtrl.value) * 90;
                return Align(
                  alignment: const Alignment(0.0, -0.15),
                  child: Transform.translate(
                    offset: Offset(dx, dy),
                    child: const Text(
                      '🪳💨',
                      style: TextStyle(fontSize: 34),
                    ),
                  ),
                );
              },
            ),
          ),
        ];

      default:
        return const [];
    }
  }

  Widget _buildTearStream({required bool isLeft}) {
    return Container(
      width: 34,
      height: 14,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF80DEEA), Color(0xFF26C6DA)],
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(isLeft ? 12 : 4),
          bottomLeft: Radius.circular(isLeft ? 12 : 4),
          topRight: Radius.circular(isLeft ? 4 : 12),
          bottomRight: Radius.circular(isLeft ? 4 : 12),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00BCD4).withValues(alpha: 0.5),
            blurRadius: 6,
          ),
        ],
      ),
    );
  }
}

/// Widget hiển thị ảnh đại diện vuông bo góc của Filter (dùng cho cả lưới chọn Filter và badge góc trên trái)
class FilterThumbnailBox extends StatelessWidget {
  final VideoFilter filter;
  final double size;
  final bool selected;
  final double borderRadius;

  const FilterThumbnailBox({
    super.key,
    required this.filter,
    this.size = 68,
    this.selected = false,
    this.borderRadius = 14,
  });

  @override
  Widget build(BuildContext context) {
    Widget inner;
    if (filter.thumbnailUrl != null && filter.thumbnailUrl!.isNotEmpty) {
      inner = CachedNetworkImage(
        imageUrl: filter.thumbnailUrl!,
        fit: BoxFit.cover,
        errorWidget: (_, _, _) => _buildGradientFallback(),
      );
      if (filter.colorFilter != null) {
        inner = ColorFiltered(colorFilter: filter.colorFilter!, child: inner);
      }
    } else {
      inner = _buildGradientFallback();
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: selected ? Colors.white : Colors.white.withValues(alpha: 0.14),
          width: selected ? 2.5 : 1.0,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.25),
                  blurRadius: 8,
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius - 2),
        child: Stack(
          fit: StackFit.expand,
          children: [
            inner,
            if (filter.overlayType == '1994_glow')
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFFFFFACD).withValues(alpha: 0.45),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            if (filter.badgeText != null && filter.thumbnailUrl != null)
              Align(
                alignment: Alignment.bottomRight,
                child: Container(
                  margin: const EdgeInsets.all(4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    filter.badgeText!,
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGradientFallback() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: filter.previewColors,
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Text(
            filter.badgeText ?? filter.name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 11,
              height: 1.15,
              shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Speed ────────────────────────────────────────────────────────────────────

class RecordSpeed {
  final String label;
  final double value;
  const RecordSpeed({required this.label, required this.value});
}

abstract class AppSpeeds {
  static const speeds = [
    RecordSpeed(label: '0.5x', value: 0.5),
    RecordSpeed(label: '0.75x', value: 0.75),
    RecordSpeed(label: '1x', value: 1.0),
    RecordSpeed(label: '1.5x', value: 1.5),
    RecordSpeed(label: '2x', value: 2.0),
  ];
  static int get defaultIndex => 2;
}

// ─── Beauty (Immutable & Real Visual Pipeline) ────────────────────────────────

class BeautyEffect extends Equatable {
  final String id;
  final String name;
  final IconData icon;
  final double value;

  const BeautyEffect({
    required this.id,
    required this.name,
    required this.icon,
    this.value = 0.0,
  });

  BeautyEffect copyWith({double? value}) => BeautyEffect(
    id: id,
    name: name,
    icon: icon,
    value: (value ?? this.value).clamp(0.0, 1.0),
  );

  @override
  List<Object?> get props => [id, name, value];
}

abstract class AppBeautyEffects {
  static List<BeautyEffect> defaults() => const [
    BeautyEffect(
      id: 'smooth',
      name: 'Mịn da',
      icon: Icons.face_retouching_natural,
      value: 0.5,
    ),
    BeautyEffect(
      id: 'whiten',
      name: 'Sáng da',
      icon: Icons.wb_sunny_outlined,
      value: 0.45,
    ),
    BeautyEffect(
      id: 'slim',
      name: 'Thon gọn',
      icon: Icons.auto_awesome_outlined,
      value: 0.35,
    ),
    BeautyEffect(
      id: 'eyes',
      name: 'Mắt to',
      icon: Icons.remove_red_eye_outlined,
      value: 0.3,
    ),
  ];

  static List<BeautyEffect> zero() => const [
    BeautyEffect(
      id: 'smooth',
      name: 'Mịn da',
      icon: Icons.face_retouching_natural,
      value: 0.0,
    ),
    BeautyEffect(
      id: 'whiten',
      name: 'Sáng da',
      icon: Icons.wb_sunny_outlined,
      value: 0.0,
    ),
    BeautyEffect(
      id: 'slim',
      name: 'Thon gọn',
      icon: Icons.auto_awesome_outlined,
      value: 0.0,
    ),
    BeautyEffect(
      id: 'eyes',
      name: 'Mắt to',
      icon: Icons.remove_red_eye_outlined,
      value: 0.0,
    ),
  ];
}

/// Widget xử lý hình ảnh thời gian thực cho tính năng Làm Đẹp:
/// - `whiten` (Sáng da): Nâng tone trắng hồng tự nhiên + tăng sáng vùng tối gương mặt
/// - `smooth` (Mịn da): Lớp khuếch tán mềm da (Soft-Focus Skin Diffusion) + giảm gắt tương phản lỗ chân lông
/// - `slim` (Thon gọn): Biến đổi hình học thu gọn chiều ngang gương mặt & kéo thanh thoát khung hình
/// - `eyes` (Mắt to): Phóng đại nhẹ vùng trung tâm gương mặt + tăng độ trong sáng cho mắt
class BeautyEffectProcessor extends StatelessWidget {
  final Widget child;
  final bool enabled;
  final double smooth;
  final double whiten;
  final double slim;
  final double eyes;

  const BeautyEffectProcessor({
    super.key,
    required this.child,
    this.enabled = true,
    this.smooth = 0.0,
    this.whiten = 0.0,
    this.slim = 0.0,
    this.eyes = 0.0,
  });

  factory BeautyEffectProcessor.fromEffects({
    Key? key,
    required Widget child,
    required bool enabled,
    required List<BeautyEffect> effects,
  }) {
    double getVal(String id) {
      for (final e in effects) {
        if (e.id == id) return e.value;
      }
      return 0.0;
    }

    return BeautyEffectProcessor(
      key: key,
      enabled: enabled,
      smooth: getVal('smooth'),
      whiten: getVal('whiten'),
      slim: getVal('slim'),
      eyes: getVal('eyes'),
      child: child,
    );
  }

  bool get _hasActiveBeauty =>
      enabled && (smooth > 0.01 || whiten > 0.01 || slim > 0.01 || eyes > 0.01);

  ColorFilter _buildSkinColorMatrix() {
    final w = whiten.clamp(0.0, 1.0);
    final s = smooth.clamp(0.0, 1.0);
    final e = eyes.clamp(0.0, 1.0);

    final scaleR = 1.0 + (w * 0.14) - (s * 0.04) + (e * 0.04);
    final scaleG = 1.0 + (w * 0.11) - (s * 0.03) + (e * 0.03);
    final scaleB = 1.0 + (w * 0.13) - (s * 0.03) + (e * 0.04);

    final offsetR = (w * 28.0) + (s * 10.0);
    final offsetG = (w * 22.0) + (s * 8.0);
    final offsetB = (w * 24.0) + (s * 9.0);

    final mix = s * 0.06;

    return ColorFilter.matrix([
      scaleR - mix, mix * 0.6, mix * 0.4, 0, offsetR,
      mix * 0.5, scaleG - mix, mix * 0.5, 0, offsetG,
      mix * 0.4, mix * 0.6, scaleB - mix, 0, offsetB,
      0, 0, 0, 1, 0,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasActiveBeauty) return child;

    final slimFactor = slim.clamp(0.0, 1.0);
    final eyesFactor = eyes.clamp(0.0, 1.0);

    final zoomBase = 1.0 + (slimFactor * 0.09) + (eyesFactor * 0.06);
    final scaleX = zoomBase * (1.0 - slimFactor * 0.11);
    final scaleY = zoomBase * (1.0 + slimFactor * 0.03);

    Widget result = Transform(
      alignment: Alignment.center,
      transform: Matrix4.diagonal3Values(scaleX, scaleY, 1.0),
      child: child,
    );

    if (whiten > 0.01 || smooth > 0.01 || eyes > 0.01) {
      result = ColorFiltered(
        colorFilter: _buildSkinColorMatrix(),
        child: result,
      );
    }

    if (smooth > 0.02 || eyes > 0.02) {
      final blurSigma = (smooth * 5.5).clamp(0.0, 6.0);
      final smoothOpacity = (smooth * 0.34).clamp(0.0, 0.38);

      result = Stack(
        fit: StackFit.expand,
        children: [
          result,
          if (smooth > 0.02)
            IgnorePointer(
              child: Opacity(
                opacity: smoothOpacity,
                child: ImageFiltered(
                  imageFilter: ui.ImageFilter.blur(
                    sigmaX: blurSigma,
                    sigmaY: blurSigma,
                    tileMode: TileMode.decal,
                  ),
                  child: result,
                ),
              ),
            ),
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.0, -0.22),
                  radius: 0.65 - (eyesFactor * 0.12),
                  colors: [
                    const Color(0xFFFFF5F7).withValues(
                      alpha: (whiten * 0.08 + eyesFactor * 0.10).clamp(
                        0.0,
                        0.18,
                      ),
                    ),
                    const Color(0xFFFFE4E9).withValues(
                      alpha: (smooth * 0.06).clamp(0.0, 0.08),
                    ),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ),
        ],
      );
    }

    return ClipRect(child: result);
  }
}

// ─── Sticker ──────────────────────────────────────────────────────────────────

class StickerItem {
  final String id;
  final String emoji;
  final String label;
  Offset position;
  double scale;
  double rotation;

  StickerItem({
    required this.id,
    required this.emoji,
    required this.label,
    this.position = Offset.zero,
    this.scale = 1.0,
    this.rotation = 0.0,
  });

  StickerItem copyWith({Offset? position, double? scale, double? rotation}) =>
      StickerItem(
        id: id,
        emoji: emoji,
        label: label,
        position: position ?? this.position,
        scale: scale ?? this.scale,
        rotation: rotation ?? this.rotation,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'e': emoji,
    'x': position.dx.round(),
    'y': position.dy.round(),
    's': scale,
    'r': rotation,
  };

  factory StickerItem.fromJson(Map<String, dynamic> json) => StickerItem(
    id: (json['id'] ?? '').toString(),
    emoji: (json['e'] ?? '✨').toString(),
    label: (json['e'] ?? '✨').toString(),
    position: Offset(
      (json['x'] as num?)?.toDouble() ?? 100,
      (json['y'] as num?)?.toDouble() ?? 160,
    ),
    scale: (json['s'] as num?)?.toDouble() ?? 1.0,
    rotation: (json['r'] as num?)?.toDouble() ?? 0.0,
  );
}

// ─── Text overlay ─────────────────────────────────────────────────────────────

class TextOverlay {
  final String id;
  String text;
  Color color;
  double fontSize;
  Offset position;
  double rotation;
  TextAlign align;

  TextOverlay({
    required this.id,
    required this.text,
    this.color = Colors.white,
    this.fontSize = 22,
    this.position = const Offset(60, 140),
    this.rotation = 0,
    this.align = TextAlign.center,
  });

  TextOverlay copyWith({
    String? text,
    Color? color,
    double? fontSize,
    Offset? position,
  }) => TextOverlay(
    id: id,
    text: text ?? this.text,
    color: color ?? this.color,
    fontSize: fontSize ?? this.fontSize,
    position: position ?? this.position,
    rotation: rotation,
    align: align,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    't': text,
    'c': color.toARGB32(),
    'fs': fontSize.round(),
    'x': position.dx.round(),
    'y': position.dy.round(),
  };

  factory TextOverlay.fromJson(Map<String, dynamic> json) => TextOverlay(
    id: (json['id'] ?? '').toString(),
    text: (json['t'] ?? '').toString(),
    color: Color((json['c'] as num?)?.toInt() ?? 0xFFFFFFFF),
    fontSize: (json['fs'] as num?)?.toDouble() ?? 22,
    position: Offset(
      (json['x'] as num?)?.toDouble() ?? 60,
      (json['y'] as num?)?.toDouble() ?? 140,
    ),
  );
}

// ─── Music ────────────────────────────────────────────────────────────────────

class MusicTrack {
  final String id;
  final String title;
  final String artist;
  final String category;
  final String? previewUrl;
  final String? artworkUrl;
  final Duration duration;
  final List<Color> coverColors;

  const MusicTrack({
    required this.id,
    required this.title,
    required this.artist,
    this.category = 'Thịnh hành',
    this.previewUrl,
    this.artworkUrl,
    this.duration = const Duration(seconds: 30),
    this.coverColors = const [Color(0xFFFF2D55), Color(0xFFFF6B00)],
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'artist': artist,
    'cat': category,
    if (previewUrl != null) 'url': previewUrl,
    if (artworkUrl != null) 'art': artworkUrl,
  };

  factory MusicTrack.fromJson(Map<String, dynamic> json) => MusicTrack(
    id: (json['id'] ?? '').toString(),
    title: (json['title'] ?? 'Âm thanh').toString(),
    artist: (json['artist'] ?? 'ShareCo').toString(),
    category: (json['cat'] ?? 'Thịnh hành').toString(),
    previewUrl: json['url']?.toString(),
    artworkUrl: json['art']?.toString(),
  );
}

abstract class AppMusicTracks {
  static final Map<String, MusicTrack> _dynamicRegistry = {};

  static void registerDynamicTracks(List<MusicTrack> tracks) {
    for (final t in tracks) {
      _dynamicRegistry[t.id] = t;
    }
  }

  static const List<MusicTrack> trending = [
    MusicTrack(
      id: 'vn_1',
      title: 'Không Thể Say',
      artist: 'HIEUTHUHAI',
      category: 'Nhạc Việt',
      previewUrl:
          'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
      duration: Duration(seconds: 30),
      coverColors: [Color(0xFFFF2D55), Color(0xFFFF6B00)],
    ),
    MusicTrack(
      id: 'vn_2',
      title: 'Đừng Làm Trái Tim Anh Đau',
      artist: 'Sơn Tùng M-TP',
      category: 'Nhạc Việt',
      previewUrl:
          'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3',
      duration: Duration(seconds: 30),
      coverColors: [Color(0xFFF857A6), Color(0xFFFF5858)],
    ),
    MusicTrack(
      id: 'uk_1',
      title: 'APT.',
      artist: 'ROSÉ & Bruno Mars',
      category: 'Nhạc Anh',
      previewUrl:
          'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-4.mp3',
      duration: Duration(seconds: 30),
      coverColors: [Color(0xFFFF0844), Color(0xFFFFB199)],
    ),
    MusicTrack(
      id: 'kr_1',
      title: 'Super Shy',
      artist: 'NewJeans',
      category: 'Nhạc Hàn',
      previewUrl:
          'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-7.mp3',
      duration: Duration(seconds: 30),
      coverColors: [Color(0xFFFF758C), Color(0xFFFF7EB3)],
    ),
  ];

  static List<MusicTrack> byCategory(String category) {
    if (category == 'Tất cả' || category == 'Thịnh hành') return trending;
    return trending.where((t) => t.category == category).toList();
  }

  static MusicTrack? byId(String? id) {
    if (id == null || id.isEmpty) return null;
    if (_dynamicRegistry.containsKey(id)) {
      return _dynamicRegistry[id];
    }
    for (final m in trending) {
      if (m.id == id) return m;
    }
    return null;
  }
}

// ─── Video Export & Effect Metadata ──────────────────────────────────────────

class VideoEffectMeta {
  final String filterId;
  final String? musicId;
  final MusicTrack? customMusic;
  final double originalVolume;
  final double musicVolume;
  final double playbackSpeed;
  final bool beautyEnabled;
  final double beautySmooth;
  final double beautyWhiten;
  final double beautySlim;
  final double beautyEyes;
  final List<TextOverlay> textOverlays;
  final List<StickerItem> stickers;

  const VideoEffectMeta({
    this.filterId = 'none',
    this.musicId,
    this.customMusic,
    this.originalVolume = 1.0,
    this.musicVolume = 0.85,
    this.playbackSpeed = 1.0,
    this.beautyEnabled = false,
    this.beautySmooth = 0.0,
    this.beautyWhiten = 0.0,
    this.beautySlim = 0.0,
    this.beautyEyes = 0.0,
    this.textOverlays = const [],
    this.stickers = const [],
  });

  VideoFilter get filter => AppFilters.byId(filterId);
  MusicTrack? get music => customMusic ?? AppMusicTracks.byId(musicId);

  bool get hasBeautyEffect =>
      beautyEnabled &&
      (beautySmooth > 0.01 ||
          beautyWhiten > 0.01 ||
          beautySlim > 0.01 ||
          beautyEyes > 0.01);

  bool get hasAnyEffect =>
      filterId != 'none' ||
      music != null ||
      (playbackSpeed - 1.0).abs() > 0.01 ||
      hasBeautyEffect ||
      textOverlays.isNotEmpty ||
      stickers.isNotEmpty;

  VideoEffectMeta copyWith({
    String? filterId,
    String? musicId,
    MusicTrack? customMusic,
    bool clearMusic = false,
    double? originalVolume,
    double? musicVolume,
    double? playbackSpeed,
    bool? beautyEnabled,
    double? beautySmooth,
    double? beautyWhiten,
    double? beautySlim,
    double? beautyEyes,
    List<TextOverlay>? textOverlays,
    List<StickerItem>? stickers,
  }) => VideoEffectMeta(
    filterId: filterId ?? this.filterId,
    musicId: clearMusic ? null : (musicId ?? this.musicId),
    customMusic: clearMusic ? null : (customMusic ?? this.customMusic),
    originalVolume: originalVolume ?? this.originalVolume,
    musicVolume: musicVolume ?? this.musicVolume,
    playbackSpeed: playbackSpeed ?? this.playbackSpeed,
    beautyEnabled: beautyEnabled ?? this.beautyEnabled,
    beautySmooth: beautySmooth ?? this.beautySmooth,
    beautyWhiten: beautyWhiten ?? this.beautyWhiten,
    beautySlim: beautySlim ?? this.beautySlim,
    beautyEyes: beautyEyes ?? this.beautyEyes,
    textOverlays: textOverlays ?? this.textOverlays,
    stickers: stickers ?? this.stickers,
  );

  Map<String, dynamic> toJson() {
    final resolvedMusic = music;
    return {
      'f': filterId,
      if (resolvedMusic != null) 'm_obj': resolvedMusic.toJson(),
      if (musicId != null) 'm': musicId,
      'ov': double.parse(originalVolume.toStringAsFixed(2)),
      'mv': double.parse(musicVolume.toStringAsFixed(2)),
      'sp': double.parse(playbackSpeed.toStringAsFixed(2)),
      if (hasBeautyEffect)
        'b': {
          'sm': double.parse(beautySmooth.toStringAsFixed(2)),
          'wh': double.parse(beautyWhiten.toStringAsFixed(2)),
          'sl': double.parse(beautySlim.toStringAsFixed(2)),
          'ey': double.parse(beautyEyes.toStringAsFixed(2)),
        },
      if (textOverlays.isNotEmpty)
        'txt': textOverlays.map((e) => e.toJson()).toList(),
      if (stickers.isNotEmpty) 'stk': stickers.map((e) => e.toJson()).toList(),
    };
  }

  factory VideoEffectMeta.fromJson(Map<String, dynamic> json) {
    final txtList =
        (json['txt'] as List?)
            ?.whereType<Map>()
            .map((e) => TextOverlay.fromJson(Map<String, dynamic>.from(e)))
            .toList() ??
        const <TextOverlay>[];
    final stkList =
        (json['stk'] as List?)
            ?.whereType<Map>()
            .map((e) => StickerItem.fromJson(Map<String, dynamic>.from(e)))
            .toList() ??
        const <StickerItem>[];

    MusicTrack? parsedMusic;
    if (json['m_obj'] is Map) {
      parsedMusic = MusicTrack.fromJson(
        Map<String, dynamic>.from(json['m_obj'] as Map),
      );
      AppMusicTracks.registerDynamicTracks([parsedMusic]);
    }

    final bMap = json['b'] is Map
        ? Map<String, dynamic>.from(json['b'] as Map)
        : null;

    return VideoEffectMeta(
      filterId: (json['f'] ?? 'none').toString(),
      musicId: json['m']?.toString() ?? parsedMusic?.id,
      customMusic: parsedMusic,
      originalVolume: (json['ov'] as num?)?.toDouble() ?? 1.0,
      musicVolume: (json['mv'] as num?)?.toDouble() ?? 0.85,
      playbackSpeed: (json['sp'] as num?)?.toDouble() ?? 1.0,
      beautyEnabled: bMap != null,
      beautySmooth: (bMap?['sm'] as num?)?.toDouble() ?? 0.0,
      beautyWhiten: (bMap?['wh'] as num?)?.toDouble() ?? 0.0,
      beautySlim: (bMap?['sl'] as num?)?.toDouble() ?? 0.0,
      beautyEyes: (bMap?['ey'] as num?)?.toDouble() ?? 0.0,
      textOverlays: txtList,
      stickers: stkList,
    );
  }

  String attachToVideoUrl(String rawUrl) {
    final cleanUrl = rawUrl.split('#').first.trim();
    if (!hasAnyEffect && (originalVolume - 1.0).abs() < 0.01) {
      return cleanUrl;
    }
    final encoded = base64Url.encode(utf8.encode(jsonEncode(toJson())));
    return '$cleanUrl#sc_fx=$encoded';
  }

  static VideoEffectMeta fromVideoPath(String? videoPath) {
    if (videoPath == null || !videoPath.contains('#sc_fx=')) {
      return const VideoEffectMeta();
    }
    try {
      final fragment = videoPath.split('#sc_fx=').last.trim();
      if (fragment.isEmpty) return const VideoEffectMeta();
      final decoded = utf8.decode(
        base64Url.decode(base64Url.normalize(fragment)),
      );
      final map = jsonDecode(decoded) as Map<String, dynamic>;
      return VideoEffectMeta.fromJson(map);
    } catch (_) {
      return const VideoEffectMeta();
    }
  }
}

// ─── Duration limit ───────────────────────────────────────────────────────────

class DurationLimit {
  final String label;
  final Duration max;
  const DurationLimit({required this.label, required this.max});
}

abstract class AppDurationLimits {
  static const limits = [
    DurationLimit(label: '15s', max: Duration(seconds: 15)),
    DurationLimit(label: '60s', max: Duration(seconds: 60)),
    DurationLimit(label: '3p', max: Duration(minutes: 3)),
    DurationLimit(label: '10p', max: Duration(minutes: 10)),
  ];
  static int get defaultIndex => 1;
}

// ─── Enums ────────────────────────────────────────────────────────────────────

enum RecordMode { camera, upload, live }

enum CameraFacing { front, back }

enum FlashMode { off, on, auto }
