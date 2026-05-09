// features/video/domain/entities/filter_entity.dart

import 'package:flutter/material.dart';

// ─── Colour filter ────────────────────────────────────────────────────────────

class VideoFilter {
  final String id;
  final String name;
  final ColorFilter? colorFilter;
  final double intensity;
  const VideoFilter({required this.id, required this.name, this.colorFilter, this.intensity = 1.0});
}

abstract class AppFilters {
  static const none = VideoFilter(id: 'none', name: 'Normal');
  static const vintage = VideoFilter(id: 'vintage', name: 'Vintage',
      colorFilter: ColorFilter.matrix([
        0.9,0.1,0.1,0,0, 0.1,0.8,0.1,0,0, 0.1,0.1,0.7,0,0, 0,0,0,1,0]));
  static const cool = VideoFilter(id: 'cool', name: 'Cool',
      colorFilter: ColorFilter.matrix([
        0.8,0,0,0,0, 0,0.9,0,0,0, 0,0,1.2,0,0, 0,0,0,1,0]));
  static const warm = VideoFilter(id: 'warm', name: 'Warm',
      colorFilter: ColorFilter.matrix([
        1.2,0,0,0,0, 0,0.9,0,0,0, 0,0,0.7,0,0, 0,0,0,1,0]));
  static const dramatic = VideoFilter(id: 'dramatic', name: 'Dramatic',
      colorFilter: ColorFilter.matrix([
        1.4,-0.1,-0.1,0,0, -0.1,1.4,-0.1,0,0, -0.1,-0.1,1.4,0,0, 0,0,0,1,0]));
  static const bw = VideoFilter(id: 'bw', name: 'B&W',
      colorFilter: ColorFilter.matrix([
        0.33,0.59,0.11,0,0, 0.33,0.59,0.11,0,0, 0.33,0.59,0.11,0,0, 0,0,0,1,0]));
  static const fade = VideoFilter(id: 'fade', name: 'Fade',
      colorFilter: ColorFilter.matrix([
        0.85,0,0,0,30, 0,0.85,0,0,30, 0,0,0.85,0,30, 0,0,0,1,0]));
  static const neon = VideoFilter(id: 'neon', name: 'Neon',
      colorFilter: ColorFilter.matrix([
        1.0,0,0.2,0,0, 0,1.0,0.5,0,0, 0.3,0,1.2,0,0, 0,0,0,1,0]));
  static const List<VideoFilter> all = [none, vintage, cool, warm, dramatic, bw, fade, neon];
}

// ─── Speed ────────────────────────────────────────────────────────────────────

class RecordSpeed {
  final String label;
  final double value;
  const RecordSpeed({required this.label, required this.value});
}

abstract class AppSpeeds {
  static const speeds = [
    RecordSpeed(label: '0.3x', value: 0.3),
    RecordSpeed(label: '0.5x', value: 0.5),
    RecordSpeed(label: '1x',   value: 1.0),
    RecordSpeed(label: '2x',   value: 2.0),
    RecordSpeed(label: '3x',   value: 3.0),
  ];
  static int get defaultIndex => 2;
}

// ─── Beauty ───────────────────────────────────────────────────────────────────

class BeautyEffect {
  final String id;
  final String name;
  final IconData icon;
  double value;
  BeautyEffect({required this.id, required this.name, required this.icon, this.value = 0.5});
}

abstract class AppBeautyEffects {
  static List<BeautyEffect> defaults() => [
    BeautyEffect(id: 'smooth', name: 'Smooth', icon: Icons.face_retouching_natural, value: 0.5),
    BeautyEffect(id: 'whiten', name: 'Whiten', icon: Icons.brightness_high, value: 0.4),
    BeautyEffect(id: 'slim',   name: 'Slim',   icon: Icons.crop_portrait, value: 0.3),
    BeautyEffect(id: 'eyes',   name: 'Big Eyes', icon: Icons.remove_red_eye, value: 0.3),
  ];
}

// ─── Sticker ──────────────────────────────────────────────────────────────────

class StickerItem {
  final String id;
  final String emoji;
  final String label;
  Offset position;
  double scale;
  double rotation;

  StickerItem({required this.id, required this.emoji, required this.label,
    this.position = Offset.zero, this.scale = 1.0, this.rotation = 0.0});

  StickerItem copyWith({Offset? position, double? scale, double? rotation}) =>
      StickerItem(id: id, emoji: emoji, label: label,
          position: position ?? this.position,
          scale: scale ?? this.scale,
          rotation: rotation ?? this.rotation);
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

  TextOverlay({required this.id, required this.text, this.color = Colors.white,
    this.fontSize = 24, this.position = const Offset(100, 200),
    this.rotation = 0, this.align = TextAlign.center});
}

// ─── Music ────────────────────────────────────────────────────────────────────

class MusicTrack {
  final String id;
  final String title;
  final String artist;
  final String? previewUrl;
  final Duration duration;
  const MusicTrack({required this.id, required this.title, required this.artist,
    this.previewUrl, this.duration = const Duration(seconds: 30)});
}

abstract class AppMusicTracks {
  static const List<MusicTrack> trending = [
    MusicTrack(id: 'm1', title: 'Chill Vibes', artist: 'Lo-Fi Beats',
        previewUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3'),
    MusicTrack(id: 'm2', title: 'Dance Energy', artist: 'Club Banger'),
    MusicTrack(id: 'm3', title: 'Acoustic Morning', artist: 'Coffee Shop'),
    MusicTrack(id: 'm4', title: 'Hip Hop Fire', artist: 'Street Beats'),
    MusicTrack(id: 'm5', title: 'Romantic Night', artist: 'Jazz Ensemble'),
  ];
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
    DurationLimit(label: '3m',  max: Duration(minutes: 3)),
    DurationLimit(label: '10m', max: Duration(minutes: 10)),
  ];
  static int get defaultIndex => 1;
}

// ─── Enums ────────────────────────────────────────────────────────────────────

enum RecordMode { camera, upload, live }
enum CameraFacing { front, back }
enum FlashMode { off, on, auto }