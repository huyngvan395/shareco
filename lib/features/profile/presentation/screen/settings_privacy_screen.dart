import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/notifier/auth_notifier.dart';
import '../../../../core/services/notifications/push_notification_service.dart';
import '../../../../core/services/supabase/index.dart';
import '../../../../core/utils/video_controller_cache.dart';
import '../../../../di/injector.dart';
import '../../../../routes/app_router.dart';

class SettingsPrivacyScreen extends StatefulWidget {
  const SettingsPrivacyScreen({super.key});

  @override
  State<SettingsPrivacyScreen> createState() => _SettingsPrivacyScreenState();
}

class _SettingsPrivacyScreenState extends State<SettingsPrivacyScreen> {
  final PushNotificationService _pushService = sl<PushNotificationService>();

  Future<void> _showChangePasswordDialog() async {
    final passCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    String? errorText;
    bool saving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final inset = MediaQuery.of(ctx).viewInsets.bottom;
            return Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + inset),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.black12,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Đổi mật khẩu tài khoản',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: passCtrl,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Mật khẩu mới (tối thiểu 6 ký tự)',
                      filled: true,
                      fillColor: const Color(0xFFF6F7F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: confirmCtrl,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Xác nhận mật khẩu mới',
                      filled: true,
                      fillColor: const Color(0xFFF6F7F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  if (errorText != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      errorText!,
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      onPressed: saving
                          ? null
                          : () async {
                              final p1 = passCtrl.text.trim();
                              final p2 = confirmCtrl.text.trim();
                              if (p1.length < 6) {
                                setSheetState(
                                  () => errorText =
                                      'Mật khẩu cần ít nhất 6 ký tự',
                                );
                                return;
                              }
                              if (p1 != p2) {
                                setSheetState(
                                  () => errorText =
                                      'Mật khẩu xác nhận không khớp',
                                );
                                return;
                              }
                              setSheetState(() {
                                saving = true;
                                errorText = null;
                              });
                              try {
                                await SupabaseService.auth.updateUser(
                                  UserAttributes(password: p1),
                                );
                                if (!sheetCtx.mounted) return;
                                Navigator.pop(sheetCtx);
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Đã cập nhật mật khẩu thành công!',
                                    ),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              } catch (e) {
                                setSheetState(() {
                                  saving = false;
                                  errorText = e.toString();
                                });
                              }
                            },
                      child: saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Lưu mật khẩu mới',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _clearMediaCache() async {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    await CachedNetworkImage.evictFromCache('');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã dọn sạch bộ nhớ đệm hình ảnh & media'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prefs = _pushService.preferences;
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Cài đặt và quyền riêng tư',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: Colors.black87,
          ),
        ),
      ),
      body: ListenableBuilder(
        listenable: prefs,
        builder: (context, _) {
          final master = prefs.masterEnabled;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SectionCard(
                title: 'THÔNG BÁO ĐẨY (PUSH NOTIFICATIONS)',
                children: [
                  SwitchListTile(
                    value: master,
                    onChanged: (v) async {
                      if (v) {
                        await _pushService.requestPermissionExplicitly();
                      }
                      await prefs.setMasterEnabled(v);
                    },
                    secondary: const Icon(
                      Icons.notifications_active_rounded,
                      color: AppColors.primary,
                    ),
                    title: const Text(
                      'Cho phép thông báo đẩy',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                      ),
                    ),
                    subtitle: const Text(
                      'Hiển thị trên thanh trạng thái điện thoại & banner trong ứng dụng',
                      style: TextStyle(fontSize: 12.2, color: Colors.black54),
                    ),
                  ),
                  const Divider(height: 1),
                  _SubToggle(
                    enabled: master,
                    icon: Icons.chat_bubble_outline_rounded,
                    title: 'Bình luận & Phản hồi video',
                    subtitle: 'Khi có người bình luận video hoặc trả lời bạn',
                    value: prefs.commentsEnabled,
                    onChanged: prefs.setCommentsEnabled,
                  ),
                  _SubToggle(
                    enabled: master,
                    icon: Icons.favorite_border_rounded,
                    title: 'Lượt thích video & Thả tim bình luận',
                    subtitle: 'Khi người khác thích video hoặc bình luận của bạn',
                    value: prefs.likesEnabled,
                    onChanged: prefs.setLikesEnabled,
                  ),
                  _SubToggle(
                    enabled: master,
                    icon: Icons.alternate_email_rounded,
                    title: 'Lượt nhắc đến & Gắn thẻ (@username)',
                    subtitle: 'Khi bạn được tag trong video hoặc bình luận',
                    value: prefs.mentionsEnabled,
                    onChanged: prefs.setMentionsEnabled,
                  ),
                  _SubToggle(
                    enabled: master,
                    icon: Icons.play_circle_outline_rounded,
                    title: 'Video mới từ người đã theo dõi',
                    subtitle: 'Khi tài khoản bạn follow đăng video mới',
                    value: prefs.newVideosEnabled,
                    onChanged: prefs.setNewVideosEnabled,
                  ),
                  _SubToggle(
                    enabled: master,
                    icon: Icons.sensors_rounded,
                    title: 'Thông báo Livestream & Quà tặng',
                    subtitle: 'Khi người bạn follow phát Live hoặc tặng quà xu',
                    value: prefs.livestreamsEnabled,
                    onChanged: prefs.setLivestreamsEnabled,
                  ),
                  _SubToggle(
                    enabled: master,
                    icon: Icons.person_add_alt_1_outlined,
                    title: 'Người theo dõi mới',
                    subtitle: 'Khi có người bắt đầu theo dõi bạn',
                    value: prefs.followsEnabled,
                    onChanged: prefs.setFollowsEnabled,
                  ),
                  _SubToggle(
                    enabled: master,
                    icon: Icons.mail_outline_rounded,
                    title: 'Tin nhắn trực tiếp',
                    subtitle: 'Khi nhận tin nhắn mới trong Hộp thư',
                    value: prefs.messagesEnabled,
                    onChanged: prefs.setMessagesEnabled,
                  ),
                  _SubToggle(
                    enabled: master,
                    icon: Icons.local_shipping_outlined,
                    title: 'Đơn hàng & Biến động Ví Xu',
                    subtitle: 'Trạng thái giao hàng, đơn mới và duyệt rút tiền',
                    value: prefs.ordersWalletEnabled,
                    onChanged: prefs.setOrdersWalletEnabled,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await _pushService.sendTestPushNotification();
                      },
                      icon: const Icon(
                        Icons.send_to_mobile_rounded,
                        size: 18,
                      ),
                      label: const Text('Gửi thử thông báo đẩy ngay'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _SectionCard(
                title: 'TÀI KHOẢN & BẢO MẬT',
                children: [
                  ListTile(
                    leading: const Icon(Icons.lock_outline_rounded),
                    title: const Text(
                      'Đổi mật khẩu',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: _showChangePasswordDialog,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.location_on_outlined),
                    title: const Text(
                      'Sổ địa chỉ nhận hàng',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push(Routes.addresses),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.cleaning_services_outlined),
                    title: const Text(
                      'Giải phóng bộ nhớ đệm',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: const Text(
                      'Xóa ảnh thu nhỏ tạm thời để ứng dụng mượt hơn',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                    onTap: _clearMediaCache,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (SupabaseService.currentUserId != null)
                _SectionCard(
                  title: 'PHIÊN ĐĂNG NHẬP',
                  children: [
                    ListTile(
                      leading: const Icon(
                        Icons.logout_rounded,
                        color: AppColors.error,
                      ),
                      title: const Text(
                        'Đăng xuất tài khoản',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.error,
                        ),
                      ),
                      onTap: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (dialogCtx) => AlertDialog(
                            backgroundColor: Colors.white,
                            surfaceTintColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            title: const Text(
                              'Đăng xuất tài khoản?',
                              style: TextStyle(
                                color: Colors.black87,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            content: const Text(
                              'Bạn có chắc chắn muốn đăng xuất khỏi tài khoản hiện tại không?',
                              style: TextStyle(
                                color: Colors.black54,
                                fontSize: 14,
                                height: 1.4,
                              ),
                            ),
                            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(dialogCtx).pop(false),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.black54,
                                ),
                                child: const Text(
                                  'Hủy',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.of(dialogCtx).pop(true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 10,
                                  ),
                                ),
                                child: const Text(
                                  'Đăng xuất',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ),
                        );

                        if (confirmed != true) return;
                        if (!context.mounted) return;

                        VideoControllerCache.pauseAllGlobal();
                        await sl<AuthNotifier>().signOut();

                        if (!context.mounted) return;
                        Navigator.of(context, rootNavigator: true).popUntil(
                          (route) => route.isFirst,
                        );
                        context.go(Routes.feed);
                      },
                    ),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 6, bottom: 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: Colors.black45,
              letterSpacing: 0.6,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _SubToggle extends StatelessWidget {
  final bool enabled;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SubToggle({
    required this.enabled,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      value: enabled && value,
      onChanged: enabled ? onChanged : null,
      secondary: Icon(
        icon,
        size: 21,
        color: enabled ? Colors.black87 : Colors.black26,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 13.8,
          fontWeight: FontWeight.w600,
          color: enabled ? Colors.black87 : Colors.black38,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: enabled ? Colors.black54 : Colors.black26,
        ),
      ),
    );
  }
}
