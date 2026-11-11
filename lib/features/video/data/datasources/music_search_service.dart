import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../domain/entities/filter_entity.dart';

class _SeedQuery {
  final String term;
  final String country;
  final int limit;
  const _SeedQuery(this.term, {this.country = 'VN', this.limit = 4});
}

/// Dịch vụ lấy bài hát thịnh hành và bài hát theo từng quốc gia (Việt, Anh, Hàn, Trung, Remix)
/// trực tiếp từ iTunes Search API công khai (có bản nghe thử AAC/M4A 30s thật và ảnh bìa thật).
class MusicSearchService {
  static final Map<String, List<MusicTrack>> _cache = {};
  static final Map<String, Future<List<MusicTrack>>> _inflight = {};

  /// Danh sách truy vấn hạt giống (chạy song song) cho từng tab quốc gia / thể loại.
  /// Mỗi truy vấn tìm theo đúng tên ca sĩ / bài hát thật để iTunes trả về đúng các bản hit chuẩn.
  static const Map<String, List<_SeedQuery>> _categorySeeds = {
    'Thịnh hành': [
      _SeedQuery('Sơn Tùng M-TP', country: 'VN', limit: 4),
      _SeedQuery('HIEUTHUHAI', country: 'VN', limit: 4),
      _SeedQuery('ROSÉ Bruno Mars APT', country: 'US', limit: 3),
      _SeedQuery('Quang Hùng MasterD', country: 'VN', limit: 4),
      _SeedQuery('Sabrina Carpenter', country: 'US', limit: 3),
      _SeedQuery('SOOBIN', country: 'VN', limit: 3),
      _SeedQuery('Jung Kook', country: 'US', limit: 3),
      _SeedQuery('Wren Evans', country: 'VN', limit: 3),
      _SeedQuery('aespa', country: 'US', limit: 3),
      _SeedQuery('MONO', country: 'VN', limit: 3),
    ],
    'Nhạc Việt': [
      _SeedQuery('Sơn Tùng M-TP', country: 'VN', limit: 4),
      _SeedQuery('HIEUTHUHAI', country: 'VN', limit: 4),
      _SeedQuery('Quang Hùng MasterD', country: 'VN', limit: 4),
      _SeedQuery('SOOBIN', country: 'VN', limit: 4),
      _SeedQuery('MONO', country: 'VN', limit: 3),
      _SeedQuery('Wren Evans', country: 'VN', limit: 3),
      _SeedQuery('tlinh', country: 'VN', limit: 3),
      _SeedQuery('Hoàng Thùy Linh', country: 'VN', limit: 3),
      _SeedQuery('Đen', country: 'VN', limit: 3),
      _SeedQuery('Vũ.', country: 'VN', limit: 3),
      _SeedQuery('Bích Phương', country: 'VN', limit: 3),
      _SeedQuery('Hòa Minzy', country: 'VN', limit: 3),
    ],
    'Nhạc Anh': [
      _SeedQuery('Sabrina Carpenter', country: 'US', limit: 4),
      _SeedQuery('Bruno Mars', country: 'US', limit: 4),
      _SeedQuery('Taylor Swift', country: 'US', limit: 4),
      _SeedQuery('Billie Eilish', country: 'US', limit: 4),
      _SeedQuery('The Weeknd', country: 'US', limit: 4),
      _SeedQuery('Ariana Grande', country: 'US', limit: 3),
      _SeedQuery('Olivia Rodrigo', country: 'US', limit: 3),
      _SeedQuery('Dua Lipa', country: 'US', limit: 3),
      _SeedQuery('Post Malone', country: 'US', limit: 3),
      _SeedQuery('Charlie Puth', country: 'US', limit: 3),
    ],
    'Nhạc Hàn': [
      _SeedQuery('BLACKPINK', country: 'US', limit: 4),
      _SeedQuery('NewJeans', country: 'US', limit: 4),
      _SeedQuery('Jung Kook', country: 'US', limit: 4),
      _SeedQuery('ROSÉ', country: 'US', limit: 3),
      _SeedQuery('aespa', country: 'US', limit: 4),
      _SeedQuery('BABYMONSTER', country: 'US', limit: 3),
      _SeedQuery('ILLIT', country: 'US', limit: 3),
      _SeedQuery('IVE', country: 'US', limit: 3),
      _SeedQuery('LE SSERAFIM', country: 'US', limit: 3),
      _SeedQuery('BTS', country: 'US', limit: 4),
      _SeedQuery('G-DRAGON', country: 'US', limit: 3),
    ],
    'Nhạc Trung': [
      _SeedQuery('Jay Chou', country: 'TW', limit: 4),
      _SeedQuery('G.E.M.', country: 'TW', limit: 4),
      _SeedQuery('Eric Chou', country: 'TW', limit: 4),
      _SeedQuery('Joker Xue', country: 'TW', limit: 4),
      _SeedQuery('JJ Lin', country: 'TW', limit: 4),
      _SeedQuery('Ronghao Li', country: 'TW', limit: 3),
      _SeedQuery('Mao Buyi', country: 'TW', limit: 3),
    ],
    'Remix / EDM': [
      _SeedQuery('Alan Walker', country: 'US', limit: 4),
      _SeedQuery('Calvin Harris', country: 'US', limit: 4),
      _SeedQuery('Martin Garrix', country: 'US', limit: 4),
      _SeedQuery('Avicii', country: 'US', limit: 4),
      _SeedQuery('Marshmello', country: 'US', limit: 4),
      _SeedQuery('The Chainsmokers', country: 'US', limit: 4),
      _SeedQuery('David Guetta', country: 'US', limit: 4),
      _SeedQuery('Zedd', country: 'US', limit: 3),
    ],
  };

  static const List<List<Color>> _palettes = [
    [Color(0xFFFF2D55), Color(0xFFFF6B00)],
    [Color(0xFF667EEA), Color(0xFF764BA2)],
    [Color(0xFF00C6FF), Color(0xFF0072FF)],
    [Color(0xFF11998E), Color(0xFF38EF7D)],
    [Color(0xFFF857A6), Color(0xFFFF5858)],
    [Color(0xFFFC466B), Color(0xFF3F5EFB)],
    [Color(0xFFF6D365), Color(0xFFFDA085)],
  ];

  /// Tải trước (prefetch) tất cả danh mục trong nền để mở tab nào cũng có dữ liệu thật ngay
  static void prefetchAllCategories() {
    for (final cat in _categorySeeds.keys) {
      getTracksByCategory(cat);
    }
  }

  /// Lấy danh sách bài hát thật theo từng tab danh mục
  static Future<List<MusicTrack>> getTracksByCategory(
    String category, {
    bool forceRefresh = false,
  }) async {
    final cacheKey = 'cat_$category';
    if (!forceRefresh &&
        _cache.containsKey(cacheKey) &&
        _cache[cacheKey]!.isNotEmpty) {
      return _cache[cacheKey]!;
    }

    if (_inflight.containsKey(cacheKey)) {
      return _inflight[cacheKey]!;
    }

    final future = _fetchCategoryInternal(category, cacheKey);
    _inflight[cacheKey] = future;
    try {
      return await future;
    } finally {
      _inflight.remove(cacheKey);
    }
  }

  static Future<List<MusicTrack>> _fetchCategoryInternal(
    String category,
    String cacheKey,
  ) async {
    final seeds = _categorySeeds[category];
    if (seeds == null || seeds.isEmpty) {
      return searchTracks(category, categoryLabel: category);
    }

    // Chạy song song tất cả các truy vấn nghệ sĩ trong danh mục
    final List<List<MusicTrack>> buckets = await Future.wait(
      seeds.map(
        (seed) => _fetchSingleQuery(
          seed.term,
          country: seed.country,
          limit: seed.limit,
          categoryLabel: category,
        ),
      ),
    );

    // Trộn xen kẽ (interleave) kết quả từ các nghệ sĩ để danh sách đa dạng, tự nhiên như bảng xếp hạng
    final merged = <MusicTrack>[];
    final seenIds = <String>{};
    final seenTitleArtist = <String>{};

    int maxLen = 0;
    for (final b in buckets) {
      if (b.length > maxLen) maxLen = b.length;
    }

    for (var row = 0; row < maxLen; row++) {
      for (var col = 0; col < buckets.length; col++) {
        final bucket = buckets[col];
        if (row < bucket.length) {
          final track = bucket[row];
          final key =
              '${track.title.toLowerCase().trim()}_${track.artist.toLowerCase().trim()}';
          if (!seenIds.contains(track.id) && !seenTitleArtist.contains(key)) {
            seenIds.add(track.id);
            seenTitleArtist.add(key);
            merged.add(track);
          }
        }
      }
    }

    if (merged.isNotEmpty) {
      AppMusicTracks.registerDynamicTracks(merged);
      _cache[cacheKey] = merged;
      return merged;
    }

    return AppMusicTracks.byCategory(category);
  }

  static bool _isKaraokeOrTribute(String title, String artist) {
    final lowerTitle = title.toLowerCase();
    final lowerArtist = artist.toLowerCase();
    const blocked = [
      'karaoke',
      'lullaby',
      'twinkle twinkle',
      'tribute',
      '8-bit',
      'ringtone',
      'originally performed',
      'instrumental version',
    ];
    for (final word in blocked) {
      if (lowerTitle.contains(word) || lowerArtist.contains(word)) {
        return true;
      }
    }
    return false;
  }

  static Future<List<MusicTrack>> _fetchSingleQuery(
    String term, {
    required String country,
    required int limit,
    required String categoryLabel,
  }) async {
    try {
      final uri = Uri.https('itunes.apple.com', '/search', {
        'term': term,
        'media': 'music',
        'entity': 'song',
        'country': country,
        'limit': '${limit + 4}',
      });

      final response = await http
          .get(uri)
          .timeout(const Duration(seconds: 7));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final results = (data['results'] as List?) ?? const [];
        final tracks = <MusicTrack>[];

        for (var i = 0; i < results.length; i++) {
          final item = results[i] as Map<String, dynamic>;
          final previewUrl = item['previewUrl']?.toString();
          final trackName = item['trackName']?.toString();
          final artistName = item['artistName']?.toString() ?? 'Nghệ sĩ';
          if (previewUrl == null ||
              previewUrl.isEmpty ||
              trackName == null ||
              trackName.isEmpty) {
            continue;
          }
          if (_isKaraokeOrTribute(trackName, artistName)) {
            continue;
          }

          final rawId = item['trackId']?.toString() ??
              '${trackName.hashCode}_${artistName.hashCode}';
          final trackId = 'itunes_$rawId';
          final artworkUrl = item['artworkUrl100']
              ?.toString()
              .replaceAll('100x100bb', '200x200bb');
          final timeMillis = item['trackTimeMillis'];
          final durationSec = timeMillis is int
              ? (timeMillis ~/ 1000).clamp(15, 30)
              : 30;

          tracks.add(
            MusicTrack(
              id: trackId,
              title: trackName,
              artist: artistName,
              category: categoryLabel,
              previewUrl: previewUrl,
              artworkUrl: artworkUrl,
              duration: Duration(seconds: durationSec),
              coverColors: _palettes[(rawId.hashCode.abs()) % _palettes.length],
            ),
          );

          if (tracks.length >= limit) break;
        }
        return tracks;
      }
    } catch (_) {}
    return const [];
  }

  /// Tìm kiếm bài hát trực tuyến theo từ khóa (tên bài hát, ca sĩ Việt / Anh / Hàn / Trung...)
  static Future<List<MusicTrack>> searchTracks(
    String query, {
    String categoryLabel = 'Tìm kiếm',
    String country = 'VN',
  }) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) {
      return getTracksByCategory(
        categoryLabel == 'Tìm kiếm' ? 'Thịnh hành' : categoryLabel,
      );
    }

    try {
      // Tìm song song trên store VN và US để bắt trọn cả nhạc Việt lẫn US-UK / K-Pop
      final resultsLists = await Future.wait([
        _fetchSingleQuery(
          cleanQuery,
          country: 'VN',
          limit: 18,
          categoryLabel: categoryLabel,
        ),
        _fetchSingleQuery(
          cleanQuery,
          country: 'US',
          limit: 12,
          categoryLabel: categoryLabel,
        ),
      ]);

      final combined = <MusicTrack>[];
      final seenIds = <String>{};
      for (final list in resultsLists) {
        for (final t in list) {
          if (seenIds.add(t.id)) {
            combined.add(t);
          }
        }
      }

      if (combined.isNotEmpty) {
        AppMusicTracks.registerDynamicTracks(combined);
        return combined;
      }
    } catch (_) {}

    final q = cleanQuery.toLowerCase();
    return AppMusicTracks.trending
        .where(
          (t) =>
              t.title.toLowerCase().contains(q) ||
              t.artist.toLowerCase().contains(q) ||
              t.category.toLowerCase().contains(q),
        )
        .toList();
  }
}
