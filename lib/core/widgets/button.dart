// import 'package:flutter/material.dart';
// import 'package:shareco/core/constants/app_colors.dart';
// // ─── Button Types ────────────────────────────────────────────
// enum SharecoButtonType {
//   primary,    // gradient + glow + shimmer
//   secondary,  // muted glass
//   outline,    // gradient border
//   icon,       // square icon button
//   social,     // white bordered (Google, Facebook...)
//   danger,     // red gradient
//   text,       // underline on hover
// }
//
// // ─── Button Sizes ────────────────────────────────────────────
// enum SharecoButtonSize { small, medium, large }
//
// // ─── Main Widget ─────────────────────────────────────────────
// class SharecoButton extends StatefulWidget {
//   final String? label;
//   final Widget? icon;
//   final VoidCallback? onPressed;
//   final SharecoButtonType type;
//   final SharecoButtonSize size;
//   final bool disabled;
//   final bool loading;
//   final bool fullWidth;
//   final bool pill;
//   final List<Color>? gradientColors;
//
//   const SharecoButton({
//     super.key,
//     this.label,
//     this.icon,
//     required this.type,
//     this.onPressed,
//     this.size = SharecoButtonSize.medium,
//     this.disabled = false,
//     this.loading = false,
//     this.fullWidth = false,
//     this.pill = false,
//     this.gradientColors,
//   });
//
//   @override
//   State<SharecoButton> createState() => _SharecoButtonState();
// }
//
// class _SharecoButtonState extends State<SharecoButton>
//     with SingleTickerProviderStateMixin {
//   late AnimationController _shimmerController;
//   bool _pressed = false;
//
//   @override
//   void initState() {
//     super.initState();
//     _shimmerController = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 1800),
//     );
//     if (widget.type == SharecoButtonType.primary && !widget.disabled) {
//       Future.delayed(const Duration(milliseconds: 800), () {
//         if (mounted) _shimmerController.repeat(min: 0, max: 1);
//       });
//     }
//   }
//
//   @override
//   void dispose() {
//     _shimmerController.dispose();
//     super.dispose();
//   }
//
//   // ── Size config ──────────────────────────────────────────
//   _SizeConfig get _sizeConfig {
//     switch (widget.size) {
//       case SharecoButtonSize.small:
//         return const _SizeConfig(
//           fontSize: 12,
//           hPad: 14,
//           vPad: 8,
//           radius: 9,
//           iconSize: 15,
//         );
//       case SharecoButtonSize.large:
//         return const _SizeConfig(
//           fontSize: 16,
//           hPad: 28,
//           vPad: 15,
//           radius: 14,
//           iconSize: 20,
//         );
//       default:
//         return const _SizeConfig(
//           fontSize: 14,
//           hPad: 20,
//           vPad: 12,
//           radius: 12,
//           iconSize: 18,
//         );
//     }
//   }
//
//   double get _borderRadius =>
//       widget.pill ? 999 : _sizeConfig.radius;
//
//   // ── Press handling ───────────────────────────────────────
//   bool get _isEnabled => !widget.disabled && !widget.loading;
//
//   void _onTapDown(_) => setState(() => _pressed = true);
//   void _onTapUp(_) => setState(() => _pressed = false);
//   void _onTapCancel() => setState(() => _pressed = false);
//
//   // ── Build ────────────────────────────────────────────────
//   @override
//   Widget build(BuildContext context) {
//     final isDark = Theme.of(context).brightness == Brightness.dark;
//     final sc = _sizeConfig;
//
//     Widget content = _buildContent(sc, isDark);
//
//     if (widget.fullWidth) {
//       content = SizedBox(width: double.infinity, child: content);
//     }
//
//     return AnimatedOpacity(
//       opacity: widget.disabled ? 0.45 : 1.0,
//       duration: const Duration(milliseconds: 200),
//       child: AnimatedScale(
//         scale: _pressed ? 0.97 : 1.0,
//         duration: const Duration(milliseconds: 120),
//         curve: Curves.easeOut,
//         child: GestureDetector(
//           onTapDown: _isEnabled ? _onTapDown : null,
//           onTapUp: _isEnabled ? _onTapUp : null,
//           onTapCancel: _isEnabled ? _onTapCancel : null,
//           onTap: _isEnabled ? widget.onPressed : null,
//           child: content,
//         ),
//       ),
//     );
//   }
//
//   Widget _buildContent(_SizeConfig sc, bool isDark) {
//     switch (widget.type) {
//       case SharecoButtonType.primary:
//         return _PrimaryButton(
//           label: widget.label,
//           icon: widget.icon,
//           loading: widget.loading,
//           shimmer: _shimmerController,
//           gradient: widget.gradientColors ?? brandGradient,
//           disabled: widget.disabled,
//           radius: _borderRadius,
//           sc: sc,
//         );
//
//       case SharecoButtonType.secondary:
//         return _SimpleButton(
//           label: widget.label,
//           icon: widget.icon,
//           loading: widget.loading,
//           bg: isDark
//               ? Colors.white.withAlpha(20)
//               : secondaryGray.withAlpha(25),
//           fg: isDark ? Colors.white : const Color(0xFF333333),
//           border: isDark
//               ? Colors.white.withAlpha(30)
//               : secondaryGray.withAlpha(46),
//           radius: _borderRadius,
//           sc: sc,
//         );
//
//       case SharecoButtonType.outline:
//         return _OutlineGradientButton(
//           label: widget.label,
//           icon: widget.icon,
//           loading: widget.loading,
//           gradient: widget.gradientColors ?? brandGradient,
//           radius: _borderRadius,
//           sc: sc,
//           isDark: isDark,
//         );
//
//       case SharecoButtonType.icon:
//         return _IconButtonCustom(
//           icon: widget.icon!,
//           size: sc.iconSize + 10,
//           disabled: widget.disabled,
//           radius: _borderRadius,
//         );
//
//       case SharecoButtonType.social:
//         return _SimpleButton(
//           label: widget.label,
//           icon: widget.icon,
//           loading: widget.loading,
//           bg: isDark ? const Color(0xFF1E1E2E) : Colors.white,
//           fg: isDark ? const Color(0xFFDDDDDD) : const Color(0xFF333333),
//           border: isDark ? const Color(0xFF2E2E40) : const Color(0xFFE0E0E0),
//           radius: _borderRadius,
//           sc: sc,
//           shadowColor: Colors.black.withAlpha(20),
//         );
//
//       case SharecoButtonType.danger:
//         return _SimpleButton(
//           label: widget.label,
//           icon: widget.icon,
//           loading: widget.loading,
//           bg: null,
//           gradient: const [Color(0xFFFF4E4E), Color(0xFFFF2D55)],
//           fg: Colors.white,
//           radius: _borderRadius,
//           sc: sc,
//           shadowColor: const Color(0xFFFF2D55).withAlpha(77),
//         );
//
//       case SharecoButtonType.text:
//         return _TextButtonCustom(
//           label: widget.label!,
//           sc: sc,
//           pressed: _pressed,
//         );
//     }
//   }
// }
//
// // ─── Primary Button (gradient + shimmer + glow) ──────────────
// class _PrimaryButton extends StatelessWidget {
//   final String? label;
//   final Widget? icon;
//   final bool loading;
//   final bool disabled;
//   final AnimationController shimmer;
//   final List<Color> gradient;
//   final double radius;
//   final _SizeConfig sc;
//
//   const _PrimaryButton({
//     required this.label,
//     required this.icon,
//     required this.loading,
//     required this.disabled,
//     required this.shimmer,
//     required this.gradient,
//     required this.radius,
//     required this.sc,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       decoration: BoxDecoration(
//         gradient: disabled
//             ? LinearGradient(colors: gradient.map((c) => c.withAlpha(180)).toList())
//             : LinearGradient(
//           colors: gradient,
//           begin: Alignment.topLeft,
//           end: Alignment.bottomRight,
//         ),
//         borderRadius: BorderRadius.circular(radius),
//         boxShadow: disabled
//             ? []
//             : [
//           BoxShadow(
//             color: gradient[2].withAlpha(90),
//             blurRadius: 20,
//             offset: const Offset(0, 4),
//           ),
//           BoxShadow(
//             color: gradient[1].withAlpha(64),
//             blurRadius: 8,
//             offset: const Offset(0, 2),
//           ),
//         ],
//       ),
//       child: ClipRRect(
//         borderRadius: BorderRadius.circular(radius),
//         child: Stack(
//           children: [
//             // content
//             Padding(
//               padding: EdgeInsets.symmetric(
//                 horizontal: sc.hPad,
//                 vertical: sc.vPad,
//               ),
//               child: _ButtonInner(
//                 label: label,
//                 icon: icon,
//                 loading: loading,
//                 fg: Colors.white,
//                 fontSize: sc.fontSize,
//                 loadingColor: Colors.white,
//               ),
//             ),
//             // shimmer sweep
//             if (!disabled)
//               AnimatedBuilder(
//                 animation: shimmer,
//                 builder: (_, _) {
//                   return Positioned.fill(
//                     child: FractionalTranslation(
//                       translation: Offset(
//                         Tween<double>(begin: -1.5, end: 2.0)
//                             .evaluate(CurvedAnimation(
//                           parent: shimmer,
//                           curve: const Interval(0, 0.6),
//                         )),
//                         0,
//                       ),
//                       child: Transform.rotate(
//                         angle: -0.35,
//                         child: Container(
//                           width: double.infinity,
//                           decoration: BoxDecoration(
//                             gradient: LinearGradient(
//                               colors: [
//                                 Colors.white.withAlpha(0),
//                                 Colors.white.withAlpha(60),
//                                 Colors.white.withAlpha(0),
//                               ],
//                             ),
//                           ),
//                         ),
//                       ),
//                     ),
//                   );
//                 },
//               ),
//           ],
//         ),
//       ),
//     );
//   }
// }
//
// // ─── Outline Gradient Button ─────────────────────────────────
// class _OutlineGradientButton extends StatelessWidget {
//   final String? label;
//   final Widget? icon;
//   final bool loading;
//   final List<Color> gradient;
//   final double radius;
//   final _SizeConfig sc;
//   final bool isDark;
//
//   const _OutlineGradientButton({
//     required this.label,
//     required this.icon,
//     required this.loading,
//     required this.gradient,
//     required this.radius,
//     required this.sc,
//     required this.isDark,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     final bgColor = isDark ? const Color(0xFF12121A) : const Color(0xFFF4F4F8);
//     return Container(
//       decoration: BoxDecoration(
//         gradient: LinearGradient(
//           colors: gradient,
//           begin: Alignment.topLeft,
//           end: Alignment.bottomRight,
//         ),
//         borderRadius: BorderRadius.circular(radius),
//       ),
//       padding: const EdgeInsets.all(2),
//       child: Container(
//         decoration: BoxDecoration(
//           color: bgColor,
//           borderRadius: BorderRadius.circular(radius - 2),
//         ),
//         padding: EdgeInsets.symmetric(
//           horizontal: sc.hPad,
//           vertical: sc.vPad,
//         ),
//         child: _ButtonInner(
//           label: label,
//           icon: icon,
//           loading: loading,
//           fg: isDark ? const Color(0xFFB594FF) : primaryPurple,
//           fontSize: sc.fontSize,
//           loadingColor: primaryPurple,
//         ),
//       ),
//     );
//   }
// }
//
// // ─── Icon Button ─────────────────────────────────────────────
// class _IconButtonCustom extends StatelessWidget {
//   final Widget icon;
//   final double size;
//   final bool disabled;
//   final double radius;
//
//   const _IconButtonCustom({
//     required this.icon,
//     required this.size,
//     required this.disabled,
//     required this.radius,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       width: size,
//       height: size,
//       decoration: BoxDecoration(
//         color: primaryBlue.withAlpha(26),
//         borderRadius: BorderRadius.circular(radius),
//         border: Border.all(color: primaryBlue.withAlpha(51)),
//       ),
//       child: IconTheme(
//         data: IconThemeData(color: primaryBlue, size: size * 0.42),
//         child: Center(child: icon),
//       ),
//     );
//   }
// }
//
// // ─── Text Button ─────────────────────────────────────────────
// class _TextButtonCustom extends StatelessWidget {
//   final String label;
//   final _SizeConfig sc;
//   final bool pressed;
//
//   const _TextButtonCustom({
//     required this.label,
//     required this.sc,
//     required this.pressed,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     final isDark = Theme.of(context).brightness == Brightness.dark;
//     final color = isDark ? const Color(0xFF7A96FF) : primaryBlue;
//     return Text(
//       label,
//       style: TextStyle(
//         fontSize: sc.fontSize,
//         fontWeight: FontWeight.w500,
//         color: color,
//         decoration: pressed ? TextDecoration.underline : TextDecoration.none,
//         decorationColor: color,
//         decorationThickness: 1.5,
//       ),
//     );
//   }
// }
//
// // ─── Generic Simple Button ───────────────────────────────────
// class _SimpleButton extends StatelessWidget {
//   final String? label;
//   final Widget? icon;
//   final bool loading;
//   final Color? bg;
//   final List<Color>? gradient;
//   final Color fg;
//   final Color? border;
//   final Color? shadowColor;
//   final double radius;
//   final _SizeConfig sc;
//
//   const _SimpleButton({
//     required this.label,
//     required this.icon,
//     required this.loading,
//     required this.bg,
//     this.gradient,
//     required this.fg,
//     this.border,
//     this.shadowColor,
//     required this.radius,
//     required this.sc,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       decoration: BoxDecoration(
//         color: gradient == null ? bg : null,
//         gradient: gradient != null
//             ? LinearGradient(
//           colors: gradient!,
//           begin: Alignment.topLeft,
//           end: Alignment.bottomRight,
//         )
//             : null,
//         borderRadius: BorderRadius.circular(radius),
//         border: border != null ? Border.all(color: border!, width: 1.5) : null,
//         boxShadow: shadowColor != null
//             ? [
//           BoxShadow(
//             color: shadowColor!,
//             blurRadius: 16,
//             offset: const Offset(0, 4),
//           ),
//         ]
//             : null,
//       ),
//       padding: EdgeInsets.symmetric(horizontal: sc.hPad, vertical: sc.vPad),
//       child: _ButtonInner(
//         label: label,
//         icon: icon,
//         loading: loading,
//         fg: fg,
//         fontSize: sc.fontSize,
//         loadingColor: fg,
//       ),
//     );
//   }
// }
//
// // ─── Inner content (icon + label + spinner) ──────────────────
// class _ButtonInner extends StatelessWidget {
//   final String? label;
//   final Widget? icon;
//   final bool loading;
//   final Color fg;
//   final double fontSize;
//   final Color loadingColor;
//
//   const _ButtonInner({
//     required this.label,
//     required this.icon,
//     required this.loading,
//     required this.fg,
//     required this.fontSize,
//     required this.loadingColor,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return Row(
//       mainAxisSize: MainAxisSize.min,
//       mainAxisAlignment: MainAxisAlignment.center,
//       children: [
//         if (loading) ...[
//           SizedBox(
//             width: fontSize,
//             height: fontSize,
//             child: CircularProgressIndicator(
//               strokeWidth: 2,
//               color: loadingColor,
//             ),
//           ),
//           if (label != null) const SizedBox(width: 8),
//         ] else if (icon != null) ...[
//           IconTheme(
//             data: IconThemeData(color: fg, size: fontSize + 2),
//             child: icon!,
//           ),
//           if (label != null) const SizedBox(width: 8),
//         ],
//         if (label != null)
//           Text(
//             label!,
//             style: TextStyle(
//               fontSize: fontSize,
//               fontWeight: FontWeight.w500,
//               color: fg,
//             ),
//           ),
//       ],
//     );
//   }
// }
//
// // ─── Size Config ─────────────────────────────────────────────
// class _SizeConfig {
//   final double fontSize;
//   final double hPad;
//   final double vPad;
//   final double radius;
//   final double iconSize;
//
//   const _SizeConfig({
//     required this.fontSize,
//     required this.hPad,
//     required this.vPad,
//     required this.radius,
//     required this.iconSize,
//   });
// }
//
// // ─── Demo App ────────────────────────────────────────────────
// void main() {
//   runApp(const SharecoApp());
// }
//
// class SharecoApp extends StatelessWidget {
//   const SharecoApp({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Shareco Buttons',
//       debugShowCheckedModeBanner: false,
//       theme: ThemeData(
//         brightness: Brightness.light,
//         fontFamily: 'SF Pro Display',
//         scaffoldBackgroundColor: const Color(0xFFF4F4F8),
//       ),
//       darkTheme: ThemeData(
//         brightness: Brightness.dark,
//         fontFamily: 'SF Pro Display',
//         scaffoldBackgroundColor: const Color(0xFF12121A),
//       ),
//       home: const ButtonDemoScreen(),
//     );
//   }
// }
//
// class ButtonDemoScreen extends StatelessWidget {
//   const ButtonDemoScreen({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text('Shareco Button System')),
//       body: SingleChildScrollView(
//         padding: const EdgeInsets.all(20),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             // ── Primary
//             _Section(title: 'Primary — gradient + shimmer', children: [
//               Row(children: [
//                 SharecoButton(
//                   type: SharecoButtonType.primary,
//                   label: 'Small',
//                   size: SharecoButtonSize.small,
//                   onPressed: () {},
//                 ),
//                 const SizedBox(width: 12),
//                 SharecoButton(
//                   type: SharecoButtonType.primary,
//                   label: 'Đăng nhập',
//                   onPressed: () {},
//                 ),
//                 const SizedBox(width: 12),
//                 SharecoButton(
//                   type: SharecoButtonType.primary,
//                   label: 'Khám phá ✦',
//                   pill: true,
//                   onPressed: () {},
//                 ),
//               ]),
//               const SizedBox(height: 12),
//               Row(children: [
//                 SharecoButton(
//                   type: SharecoButtonType.primary,
//                   label: 'Large',
//                   size: SharecoButtonSize.large,
//                   onPressed: () {},
//                 ),
//                 const SizedBox(width: 12),
//                 SharecoButton(
//                   type: SharecoButtonType.primary,
//                   label: 'Đang tải',
//                   loading: true,
//                   onPressed: () {},
//                 ),
//                 const SizedBox(width: 12),
//                 SharecoButton(
//                   type: SharecoButtonType.primary,
//                   label: 'Disabled',
//                   disabled: true,
//                   onPressed: () {},
//                 ),
//               ]),
//               const SizedBox(height: 12),
//               SharecoButton(
//                 type: SharecoButtonType.primary,
//                 label: 'Đăng nhập ngay',
//                 size: SharecoButtonSize.large,
//                 fullWidth: true,
//                 icon: const Icon(Icons.login_rounded),
//                 onPressed: () {},
//               ),
//             ]),
//
//             // ── Secondary
//             _Section(title: 'Secondary', children: [
//               Row(children: [
//                 SharecoButton(
//                   type: SharecoButtonType.secondary,
//                   label: 'Hủy',
//                   onPressed: () {},
//                 ),
//                 const SizedBox(width: 12),
//                 SharecoButton(
//                   type: SharecoButtonType.secondary,
//                   label: 'Xem thêm →',
//                   pill: true,
//                   onPressed: () {},
//                 ),
//                 const SizedBox(width: 12),
//                 SharecoButton(
//                   type: SharecoButtonType.secondary,
//                   label: 'Disabled',
//                   disabled: true,
//                   onPressed: () {},
//                 ),
//               ]),
//             ]),
//
//             // ── Outline Gradient
//             _Section(title: 'Outline gradient', children: [
//               Row(children: [
//                 SharecoButton(
//                   type: SharecoButtonType.outline,
//                   label: 'Tìm hiểu thêm',
//                   onPressed: () {},
//                 ),
//                 const SizedBox(width: 12),
//                 SharecoButton(
//                   type: SharecoButtonType.outline,
//                   label: 'Chia sẻ',
//                   pill: true,
//                   icon: const Icon(Icons.share_rounded),
//                   onPressed: () {},
//                 ),
//               ]),
//             ]),
//
//             // ── Icon
//             _Section(title: 'Icon', children: [
//               Row(children: [
//                 SharecoButton(
//                   type: SharecoButtonType.icon,
//                   icon: const Icon(Icons.favorite_rounded),
//                   onPressed: () {},
//                 ),
//                 const SizedBox(width: 12),
//                 SharecoButton(
//                   type: SharecoButtonType.icon,
//                   icon: const Icon(Icons.share_rounded),
//                   onPressed: () {},
//                 ),
//                 const SizedBox(width: 12),
//                 SharecoButton(
//                   type: SharecoButtonType.icon,
//                   icon: const Icon(Icons.bookmark_rounded),
//                   onPressed: () {},
//                 ),
//                 const SizedBox(width: 12),
//                 SharecoButton(
//                   type: SharecoButtonType.icon,
//                   icon: const Icon(Icons.star_rounded),
//                   disabled: true,
//                   onPressed: () {},
//                 ),
//               ]),
//             ]),
//
//             // ── Social
//             _Section(title: 'Social', children: [
//               SharecoButton(
//                 type: SharecoButtonType.social,
//                 label: 'Tiếp tục với Google',
//                 icon: const Icon(Icons.g_mobiledata_rounded, color: Color(0xFF4285F4), size: 22),
//                 fullWidth: true,
//                 onPressed: () {},
//               ),
//               const SizedBox(height: 10),
//               SharecoButton(
//                 type: SharecoButtonType.social,
//                 label: 'Tiếp tục với Facebook',
//                 icon: const Icon(Icons.facebook_rounded, color: Color(0xFF1877F2)),
//                 fullWidth: true,
//                 onPressed: () {},
//               ),
//             ]),
//
//             // ── Danger
//             _Section(title: 'Danger', children: [
//               Row(children: [
//                 SharecoButton(
//                   type: SharecoButtonType.danger,
//                   label: 'Xóa tài khoản',
//                   icon: const Icon(Icons.delete_outline_rounded),
//                   onPressed: () {},
//                 ),
//                 const SizedBox(width: 12),
//                 SharecoButton(
//                   type: SharecoButtonType.danger,
//                   label: 'Xóa',
//                   size: SharecoButtonSize.small,
//                   onPressed: () {},
//                 ),
//                 const SizedBox(width: 12),
//                 SharecoButton(
//                   type: SharecoButtonType.danger,
//                   label: 'Disabled',
//                   disabled: true,
//                   onPressed: () {},
//                 ),
//               ]),
//             ]),
//
//             // ── Text
//             _Section(title: 'Text', children: [
//               Row(children: [
//                 SharecoButton(
//                   type: SharecoButtonType.text,
//                   label: 'Quên mật khẩu?',
//                   onPressed: () {},
//                 ),
//                 const SizedBox(width: 20),
//                 SharecoButton(
//                   type: SharecoButtonType.text,
//                   label: 'Xem tất cả →',
//                   onPressed: () {},
//                 ),
//               ]),
//             ]),
//           ],
//         ),
//       ),
//     );
//   }
// }
//
// class _Section extends StatelessWidget {
//   final String title;
//   final List<Widget> children;
//
//   const _Section({required this.title, required this.children});
//
//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: const EdgeInsets.only(bottom: 28),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(
//             title.toUpperCase(),
//             style: const TextStyle(
//               fontSize: 11,
//               fontWeight: FontWeight.w600,
//               color: secondaryGray,
//               letterSpacing: 0.8,
//             ),
//           ),
//           const SizedBox(height: 4),
//           const Divider(height: 12, thickness: 0.5),
//           const SizedBox(height: 12),
//           ...children,
//         ],
//       ),
//     );
//   }
// }

// core/widgets/button.dart

import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isOutlined;
  final double? width;
  final Color? backgroundColor;
  final Color? textColor;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.isOutlined = false,
    this.width,
    this.backgroundColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? AppColors.primary;
    final fg = textColor ?? Colors.white;

    return SizedBox(
      width: width ?? double.infinity,
      height: 52,
      child: isOutlined
          ? OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: bg, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusLg),
          ),
        ),
        child: _child(bg),
      )
          : ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusLg),
          ),
        ),
        child: _child(fg),
      ),
    );
  }

  Widget _child(Color color) {
    if (isLoading) {
      return SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
          color: color,
          strokeWidth: 2,
        ),
      );
    }
    return Text(
      label,
      style: TextStyle(
        color: color,
        fontSize: AppSizes.fontXl,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
      ),
    );
  }
}