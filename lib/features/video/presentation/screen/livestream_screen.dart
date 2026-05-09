// features/video/presentation/screen/livestream_screen.dart

import 'dart:async';
import 'dart:math';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shareco/features/video/presentation/bloc/camera_event.dart';
import 'package:shareco/features/video/presentation/bloc/camera_state.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/supabase/index.dart';
import '../bloc/camera_bloc.dart';

class LiveStreamScreen extends StatelessWidget {
  const LiveStreamScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => CameraBloc()..add(const CameraInitRequested()),
      child: const _LiveView(),
    );
  }
}

class _LiveView extends StatefulWidget {
  const _LiveView();
  @override State<_LiveView> createState() => _LiveViewState();
}

class _LiveViewState extends State<_LiveView> {
  bool _isLive = false;
  int _viewerCount = 0;
  int _likeCount = 0;
  final List<_LiveComment> _comments = [];
  final List<_FloatingGift> _floating = [];
  final _commentCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  Timer? _viewerTimer;
  Timer? _giftTimer;
  int _nextId = 0;

  @override
  void dispose() {
    _commentCtrl.dispose();
    _scrollCtrl.dispose();
    _viewerTimer?.cancel();
    _giftTimer?.cancel();
    context.read<CameraBloc>().add(const CameraDisposed());
    super.dispose();
  }

  void _startLive() {
    setState(() { _isLive = true; _viewerCount = 1; });

    _viewerTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted) return;
      final msgs = ['Hello! 👋','Amazing!','❤️❤️❤️','So cool!','Love this!','🔥🔥','Keep going!','omg wow'];
      final names = ['user_${_rnd(9999)}','fan_${_rnd(999)}','viewer_${_rnd(99)}'];
      setState(() {
        _viewerCount += _rnd(4) + 1;
        _comments.add(_LiveComment(
          id: '${_nextId++}',
          username: names[_rnd(names.length)],
          message: msgs[_rnd(msgs.length)],
          color: _rndColor(),
        ));
        if (_comments.length > 30) _comments.removeAt(0);
      });
      _scrollToBottom();
    });

    _giftTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      _spawnGift(_gifts[_rnd(_gifts.length)]);
    });
  }

  void _stopLive() {
    _viewerTimer?.cancel();
    _giftTimer?.cancel();
    setState(() => _isLive = false);
  }

  void _spawnGift(_GiftItem gift) {
    final id = '${_nextId++}';
    setState(() {
      _likeCount += gift.value;
      _floating.add(_FloatingGift(id: id, gift: gift, x: _rnd(200).toDouble() + 50));
    });
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _floating.removeWhere((g) => g.id == id));
    });
  }

  void _sendComment() {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _comments.add(_LiveComment(
          id: '${_nextId++}', username: 'me', message: text,
          color: AppColors.primary, isMe: true));
      if (_comments.length > 30) _comments.removeAt(0);
      _commentCtrl.clear();
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  int _rnd(int max) => Random().nextInt(max == 0 ? 1 : max);
  Color _rndColor() {
    final c = [Colors.cyan, Colors.greenAccent, Colors.yellow, Colors.pinkAccent, Colors.orange];
    return c[_rnd(c.length)];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      body: BlocBuilder<CameraBloc, CameraState>(
        builder: (ctx, cam) => Stack(children: [
          // Camera preview
          if (cam.isInitialized && cam.controller != null)
            Positioned.fill(child: CameraPreview(cam.controller!))
          else
            Container(color: const Color(0xFF0D0D1A)),

          // Dark gradient
          Positioned.fill(child: DecoratedBox(
            decoration: BoxDecoration(gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Colors.black.withOpacity(0.45), Colors.transparent,
                Colors.transparent, Colors.black.withOpacity(0.75)],
              stops: const [0, 0.2, 0.6, 1],
            )),
          )),

          // Floating gifts
          ..._floating.map((g) => _FloatingGiftWidget(key: ValueKey(g.id), gift: g)),

          // Top bar
          _buildTopBar(ctx, cam),

          // Right gift panel
          Positioned(right: 12, bottom: 160, child: _buildGiftPanel()),

          // Comments
          Positioned(left: 12, right: 80, bottom: 82, height: 200, child: _buildComments()),

          // Bottom bar
          Positioned(bottom: 0, left: 0, right: 0, child: _buildBottomBar(ctx)),

          // Go Live splash
          if (!_isLive) _buildSplash(ctx),
        ]),
      ),
    );
  }

  // ── Top bar ─────────────────────────────────────────────────────────────────

  Widget _buildTopBar(BuildContext ctx, CameraState cam) {
    return Positioned(
      top: 0, left: 0, right: 0,
      child: SafeArea(child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(children: [
          _Chip(onTap: _isLive ? null : () => Navigator.pop(context),
              child: const Icon(Icons.close, color: Colors.white, size: 20)),
          const SizedBox(width: 8),
          if (_isLive) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)),
              child: const Text('LIVE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
            ),
            const SizedBox(width: 8),
            _Chip(child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.visibility_outlined, color: Colors.white, size: 14),
              const SizedBox(width: 4),
              Text(_fmt(_viewerCount), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
            ])),
          ],
          const Spacer(),
          if (_isLive) Row(children: [
            const Icon(Icons.favorite, color: AppColors.like, size: 16),
            const SizedBox(width: 4),
            Text(_fmt(_likeCount), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(width: 12),
          ]),
          _Chip(onTap: () => ctx.read<CameraBloc>().add(const CameraFlipRequested()),
              child: const Icon(Icons.flip_camera_ios_outlined, color: Colors.white, size: 20)),
        ]),
      )),
    );
  }

  // ── Comments ────────────────────────────────────────────────────────────────

  Widget _buildComments() => ListView.builder(
    controller: _scrollCtrl,
    itemCount: _comments.length,
    itemBuilder: (_, i) {
      final c = _comments[i];
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 22, height: 22,
            decoration: BoxDecoration(color: c.color.withOpacity(0.25), shape: BoxShape.circle),
            child: Center(child: Text(c.username[0].toUpperCase(),
                style: TextStyle(color: c.color, fontSize: 10, fontWeight: FontWeight.w800))),
          ),
          const SizedBox(width: 6),
          Expanded(child: RichText(text: TextSpan(children: [
            TextSpan(text: '${c.username}  ',
                style: TextStyle(color: c.color, fontWeight: FontWeight.w700, fontSize: 12,
                    shadows: const [Shadow(color: Colors.black, blurRadius: 4)])),
            TextSpan(text: c.message,
                style: const TextStyle(color: Colors.white, fontSize: 13,
                    shadows: [Shadow(color: Colors.black54, blurRadius: 4)])),
          ]))),
        ]),
      );
    },
  );

  // ── Gift panel ──────────────────────────────────────────────────────────────

  Widget _buildGiftPanel() => Column(mainAxisSize: MainAxisSize.min,
      children: _gifts.take(5).map((g) => GestureDetector(
        onTap: () => _spawnGift(g),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          width: 50, height: 50,
          decoration: BoxDecoration(
            color: Colors.black45, shape: BoxShape.circle,
            border: Border.all(color: g.color.withOpacity(0.5)),
          ),
          child: Center(child: Text(g.emoji, style: const TextStyle(fontSize: 24))),
        ),
      )).toList());

  // ── Bottom bar ──────────────────────────────────────────────────────────────

  Widget _buildBottomBar(BuildContext ctx) {
    return SafeArea(
      child: Container(
        padding: EdgeInsets.only(
            left: 12, right: 12, top: 8,
            bottom: 8 + MediaQuery.of(context).viewInsets.bottom),
        color: Colors.black54,
        child: Row(children: [
          Expanded(child: TextField(
            controller: _commentCtrl,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            onSubmitted: (_) => _sendComment(),
            decoration: InputDecoration(
              hintText: _isLive ? 'Comment...' : 'Say something...',
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true, fillColor: Colors.white12,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
            ),
          )),
          const SizedBox(width: 8),
          _Chip(onTap: _sendComment,
              color: AppColors.primary,
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 18)),
          const SizedBox(width: 8),
          _Chip(onTap: () => setState(() => _likeCount++),
              child: const Icon(Icons.favorite, color: AppColors.like, size: 22)),
          if (_isLive) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  backgroundColor: AppColors.bgCard,
                  title: const Text('End Livestream?', style: TextStyle(color: Colors.white)),
                  content: Text('${_fmt(_viewerCount)} viewers · ${_fmt(_likeCount)} likes',
                      style: const TextStyle(color: Colors.white54)),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop('' as BuildContext),
                        child: const Text('Cancel', style: TextStyle(color: Colors.white38))),
                    ElevatedButton(
                      onPressed: () { Navigator.pop('' as BuildContext); _stopLive(); Navigator.pop(context); },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      child: const Text('End', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: Colors.red.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(20)),
                child: const Text('End', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ]),
      ),
    );
  }

  // ── Go Live splash ──────────────────────────────────────────────────────────

  Widget _buildSplash(BuildContext ctx) {
    final uid = SupabaseService.currentUserId;
    return Positioned.fill(
      child: Container(
        color: Colors.black54,
        child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 90, height: 90,
              decoration: BoxDecoration(shape: BoxShape.circle,
                  gradient: const LinearGradient(
                      colors: [AppColors.primary, Colors.deepOrangeAccent],
                      begin: Alignment.topLeft, end: Alignment.bottomRight),
                  boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.4), blurRadius: 24, spreadRadius: 4)]),
              child: const Icon(Icons.live_tv_rounded, color: Colors.white, size: 42)),
          const SizedBox(height: 20),
          const Text('GO LIVE', style: TextStyle(color: Colors.white, fontSize: 30,
              fontWeight: FontWeight.w900, letterSpacing: 3)),
          const SizedBox(height: 8),
          const Text('Share your moment with the world',
              style: TextStyle(color: Colors.white54, fontSize: 14)),
          const SizedBox(height: 6),
          Text(uid == null ? 'Log in to go live' : '1,000+ followers required',
              style: TextStyle(
                  color: uid == null ? AppColors.error : Colors.white38, fontSize: 12)),
          const SizedBox(height: 32),
          GestureDetector(
            onTap: uid != null ? _startLive : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 52, vertical: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: uid != null
                    ? [AppColors.primary, Colors.deepOrangeAccent]
                    : [Colors.grey.shade700, Colors.grey.shade600]),
                borderRadius: BorderRadius.circular(32),
                boxShadow: uid != null ? [BoxShadow(
                    color: AppColors.primary.withOpacity(0.4), blurRadius: 20)] : [],
              ),
              child: const Text('Start Live',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 20),
          TextButton(onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54, fontSize: 14))),
        ])),
      ),
    );
  }

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }
}

// ─── Floating gift animation ───────────────────────────────────────────────────

class _FloatingGiftWidget extends StatefulWidget {
  final _FloatingGift gift;
  const _FloatingGiftWidget({super.key, required this.gift});
  @override State<_FloatingGiftWidget> createState() => _FloatingGiftWidgetState();
}

class _FloatingGiftWidgetState extends State<_FloatingGiftWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _y, _opacity, _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2800));
    _y = Tween(begin: 0.0, end: -180.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _opacity = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 25),
    ]).animate(_ctrl);
    _scale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.3), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 70),
    ]).animate(_ctrl);
    _ctrl.forward();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Positioned(
    left: widget.gift.x, bottom: 110,
    child: AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Transform.translate(
        offset: Offset(0, _y.value),
        child: Opacity(
          opacity: _opacity.value.clamp(0.0, 1.0),
          child: Transform.scale(scale: _scale.value,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                  color: Colors.black54, borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: widget.gift.gift.color.withOpacity(0.5))),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(widget.gift.gift.emoji, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 6),
                Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text('user_${Random().nextInt(999)}',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
                  Text('sent ${widget.gift.gift.name}',
                      style: TextStyle(color: widget.gift.gift.color, fontSize: 9)),
                ]),
              ]),
            ),
          ),
        ),
      ),
    ),
  );
}

// ─── Helper widget ────────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color color;
  const _Chip({required this.child, this.onTap, this.color = Colors.black38});

  @override
  Widget build(BuildContext context) => GestureDetector(
      onTap: onTap,
      child: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Center(child: child)));
}

// ─── Data classes ──────────────────────────────────────────────────────────────

class _LiveComment {
  final String id, username, message;
  final Color color;
  final bool isMe;
  const _LiveComment({required this.id, required this.username,
    required this.message, required this.color, this.isMe = false});
}

class _GiftItem {
  final String id, emoji, name;
  final int value;
  final Color color;
  const _GiftItem({required this.id, required this.emoji, required this.name,
    required this.value, required this.color});
}

class _FloatingGift {
  final String id;
  final _GiftItem gift;
  final double x;
  const _FloatingGift({required this.id, required this.gift, required this.x});
}

const _gifts = [
  _GiftItem(id: 'g1', emoji: '🌹', name: 'Rose',     value: 1,   color: Colors.pink),
  _GiftItem(id: 'g2', emoji: '💎', name: 'Diamond',  value: 500, color: Colors.cyan),
  _GiftItem(id: 'g3', emoji: '🦁', name: 'Lion',     value: 100, color: Colors.amber),
  _GiftItem(id: 'g4', emoji: '🚀', name: 'Rocket',   value: 50,  color: Colors.orange),
  _GiftItem(id: 'g5', emoji: '👑', name: 'Crown',    value: 200, color: Colors.yellow),
];