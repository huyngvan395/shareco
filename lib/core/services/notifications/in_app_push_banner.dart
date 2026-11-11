import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../utils/storage_image.dart';
import 'push_notification_service.dart';

class InAppPushBannerOverlay extends StatefulWidget {
  final PushNotificationService service;
  final Widget child;

  const InAppPushBannerOverlay({
    super.key,
    required this.service,
    required this.child,
  });

  @override
  State<InAppPushBannerOverlay> createState() => _InAppPushBannerOverlayState();
}

class _InAppPushBannerOverlayState extends State<InAppPushBannerOverlay>
    with SingleTickerProviderStateMixin {
  StreamSubscription<PushBannerPayload>? _sub;
  PushBannerPayload? _current;
  Timer? _dismissTimer;

  late final AnimationController _animController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );
  late final Animation<Offset> _slideAnim = Tween<Offset>(
    begin: const Offset(0, -1.25),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));

  @override
  void initState() {
    super.initState();
    _sub = widget.service.bannerStream.listen(_showBanner);
  }

  void _showBanner(PushBannerPayload payload) {
    if (!mounted) return;
    _dismissTimer?.cancel();
    setState(() => _current = payload);
    _animController.forward(from: 0);
    _dismissTimer = Timer(const Duration(seconds: 4), _hideBanner);
  }

  Future<void> _hideBanner() async {
    _dismissTimer?.cancel();
    if (!mounted || _current == null) return;
    await _animController.reverse();
    if (mounted) {
      setState(() => _current = null);
    }
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _sub?.cancel();
    _animController.dispose();
    super.dispose();
  }

  (IconData, Color) _styleForType(String type) {
    switch (type) {
      case 'video_like':
      case 'like':
      case 'comment_like':
        return (Icons.favorite_rounded, AppColors.primary);
      case 'comment':
      case 'comment_reply':
        return (Icons.chat_bubble_rounded, AppColors.secondary);
      case 'mention':
        return (Icons.alternate_email_rounded, const Color(0xFF8B5CF6));
      case 'new_video':
        return (Icons.play_circle_fill_rounded, AppColors.secondary);
      case 'livestream':
        return (Icons.sensors_rounded, AppColors.primary);
      case 'gift':
      case 'wallet':
        return (Icons.monetization_on_rounded, AppColors.gold);
      case 'follow':
        return (Icons.person_add_alt_1_rounded, const Color(0xFF10B981));
      case 'order':
      case 'new_order':
      case 'order_status':
        return (Icons.local_shipping_rounded, const Color(0xFFF97316));
      case 'message':
        return (Icons.send_rounded, AppColors.primary);
      default:
        return (Icons.notifications_active_rounded, AppColors.primary);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_current != null)
          Positioned(
            top: 0,
            left: 12,
            right: 12,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: SlideTransition(
                  position: _slideAnim,
                  child: Dismissible(
                    key: ValueKey(_current!.id),
                    direction: DismissDirection.up,
                    onDismissed: (_) {
                      _dismissTimer?.cancel();
                      setState(() => _current = null);
                    },
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () {
                          final data = _current!.data;
                          _hideBanner();
                          widget.service.navigateFromPayload(data);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xF2161823),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.12),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.35),
                                blurRadius: 18,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Builder(
                            builder: (context) {
                              final (icon, accent) = _styleForType(
                                _current!.type,
                              );
                              final resolvedAvatar = StorageImage.avatar(
                                _current!.avatarUrl,
                              );
                              return Row(
                                children: [
                                  Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Container(
                                        width: 42,
                                        height: 42,
                                        decoration: BoxDecoration(
                                          color: accent.withValues(alpha: 0.18),
                                          shape: BoxShape.circle,
                                        ),
                                        child: resolvedAvatar != null
                                            ? ClipOval(
                                                child: CachedNetworkImage(
                                                  imageUrl: resolvedAvatar,
                                                  fit: BoxFit.cover,
                                                  errorWidget: (_, _, _) =>
                                                      Icon(
                                                        icon,
                                                        color: accent,
                                                        size: 20,
                                                      ),
                                                ),
                                              )
                                            : Icon(
                                                icon,
                                                color: accent,
                                                size: 21,
                                              ),
                                      ),
                                      if (resolvedAvatar != null)
                                        Positioned(
                                          right: -2,
                                          bottom: -2,
                                          child: Container(
                                            width: 18,
                                            height: 18,
                                            decoration: BoxDecoration(
                                              color: accent,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: const Color(0xFF161823),
                                                width: 1.5,
                                              ),
                                            ),
                                            child: Icon(
                                              icon,
                                              color: Colors.white,
                                              size: 10,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          _current!.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _current!.body,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: Colors.white.withValues(
                                              alpha: 0.82,
                                            ),
                                            fontSize: 12.5,
                                            height: 1.3,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: const Text(
                                      'Xem',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
