import "package:flutter/material.dart";
import "package:shareco/core/constants/app_colors.dart";

enum TextFieldVariant {
  gradient,   // 2px gradient border (signature)
  accent,     // purple focus ring (clean everyday)
  floating,   // floating label + purple accent
}

// ─── TextField State ──────────────────────────────────────────
enum TextFieldState { normal, error, success, disabled }

// ─── GradientIcon (unchanged, kept for convenience) ──────────
class GradientIcon extends StatelessWidget {
  final IconData icon;
  final double size;
  final List<Color> colors;

  const GradientIcon(
      this.icon, {
        super.key,
        this.size = 22,
        this.colors = brandGradient,
      });

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => LinearGradient(
        colors: colors,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(bounds),
      child: Icon(icon, size: size, color: Colors.white),
    );
  }
}

// ─── Main Widget ─────────────────────────────────────────────
class SharecoTextField extends StatefulWidget {
  final String? label;
  final String? placeholder;
  final TextEditingController? controller;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextFieldVariant variant;
  final TextFieldState fieldState;
  final String? helperText;
  final ValueChanged<String>? onChanged;
  final List<Color>? gradientColors;

  const SharecoTextField({
    super.key,
    this.label,
    this.placeholder,
    this.controller,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.variant = TextFieldVariant.accent,
    this.fieldState = TextFieldState.normal,
    this.helperText,
    this.onChanged,
    this.gradientColors,
  });

  @override
  State<SharecoTextField> createState() => _SharecoTextFieldState();
}

class _SharecoTextFieldState extends State<SharecoTextField> {
  final FocusNode _focus = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() => _focused = _focus.hasFocus));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  bool get _isDisabled => widget.fieldState == TextFieldState.disabled;

  // ── Color tokens per state ───────────────────────────────
  Color get _borderColor {
    if (_isDisabled) return secondaryGray.withAlpha(77);
    switch (widget.fieldState) {
      case TextFieldState.error:
        return const Color(0xFFFF4E4E);
      case TextFieldState.success:
        return const Color(0xFF1D9E75);
      default:
        return _focused ? primaryPurple : const Color(0xFFE0E0E8);
    }
  }

  Color get _shadowColor {
    if (!_focused || _isDisabled) return Colors.transparent;
    switch (widget.fieldState) {
      case TextFieldState.error:
        return const Color(0xFFFF4E4E).withAlpha(26);
      case TextFieldState.success:
        return const Color(0xFF1D9E75).withAlpha(26);
      default:
        return primaryPurple.withAlpha(31);
    }
  }

  Color get _labelColor {
    switch (widget.fieldState) {
      case TextFieldState.error:
        return const Color(0xFFFF4E4E);
      case TextFieldState.success:
        return const Color(0xFF0F6E56);
      default:
        return _focused ? primaryPurple : secondaryGray;
    }
  }

  // ── Helper row (error/success message) ──────────────────
  Widget? _buildHelper() {
    if (widget.helperText == null) return null;
    Color dotColor;
    Color textColor;
    switch (widget.fieldState) {
      case TextFieldState.error:
        dotColor = const Color(0xFFFF4E4E);
        textColor = const Color(0xFFFF4E4E);
        break;
      case TextFieldState.success:
        dotColor = const Color(0xFF1D9E75);
        textColor = const Color(0xFF0F6E56);
        break;
      default:
        dotColor = secondaryGray;
        textColor = secondaryGray;
    }
    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 2),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            widget.helperText!,
            style: TextStyle(fontSize: 12, color: textColor),
          ),
        ],
      ),
    );
  }

  // ── Suffix icon override for state ──────────────────────
  Widget? get _effectiveSuffixIcon {
    if (widget.fieldState == TextFieldState.error) {
      return const Icon(Icons.error_outline_rounded,
          color: Color(0xFFFF4E4E), size: 18);
    }
    if (widget.fieldState == TextFieldState.success) {
      return const Icon(Icons.check_circle_outline_rounded,
          color: Color(0xFF1D9E75), size: 18);
    }
    return widget.suffixIcon;
  }

  // ── Input decoration (shared core) ──────────────────────
  InputDecoration _buildDecoration({bool floatingLabel = false}) {
    return InputDecoration(
      labelText: floatingLabel ? widget.label : null,
      hintText: floatingLabel ? null : widget.placeholder,
      labelStyle: TextStyle(color: _labelColor, fontSize: 14),
      hintStyle: const TextStyle(color: secondaryGray, fontSize: 14),
      prefixIcon: widget.prefixIcon != null
          ? Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: widget.prefixIcon,
      )
          : null,
      prefixIconConstraints:
      const BoxConstraints(minWidth: 44, minHeight: 44),
      suffixIcon: _effectiveSuffixIcon != null
          ? Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: _effectiveSuffixIcon,
      )
          : null,
      suffixIconConstraints:
      const BoxConstraints(minWidth: 44, minHeight: 44),
      border: InputBorder.none,
      contentPadding: EdgeInsets.symmetric(
        horizontal: widget.prefixIcon == null ? 16 : 0,
        vertical: floatingLabel ? 18 : 14,
      ),
      filled: _isDisabled,
      fillColor: _isDisabled ? secondaryGray.withAlpha(20) : null,
    );
  }

  // ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    Widget field;

    switch (widget.variant) {
      case TextFieldVariant.gradient:
        field = _buildGradientVariant();
        break;
      case TextFieldVariant.accent:
        field = _buildAccentVariant();
        break;
      case TextFieldVariant.floating:
        field = _buildFloatingVariant();
        break;
    }

    final helper = _buildHelper();

    return Opacity(
      opacity: _isDisabled ? 0.45 : 1.0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          field,
          if (helper != null) helper,
        ],
      ),
    );
  }

  // ── Variant A: Gradient border ───────────────────────────
  Widget _buildGradientVariant() {
    final colors = widget.gradientColors ?? brandGradient;
    final isFocused = _focus.hasFocus;
    return Container(
      decoration: BoxDecoration(
        gradient: isFocused
            ? LinearGradient(
          colors: colors,
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        )
            : null, // ❗ không focus → mất gradient
        borderRadius: BorderRadius.circular(13),
        border: isFocused
            ? null
            : Border.all(
          color: Colors.grey.shade300, // border thường khi không focus
          width: 1.2,
        ),
      ),
      padding: const EdgeInsets.all(2),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(11),
        ),
        child: TextFormField(
          controller: widget.controller,
          focusNode: _focus,
          obscureText: widget.obscureText,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          enabled: !_isDisabled,
          onChanged: widget.onChanged,
          style: const TextStyle(fontSize: 14),
          decoration: _buildDecoration(),
        ),
      ),
    );
  }

  // ── Variant B: Purple accent ─────────────────────────────
  Widget _buildAccentVariant() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: _isDisabled ? secondaryGray.withAlpha(13) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: _shadowColor,
            blurRadius: 0,
            spreadRadius: 3,
          ),
        ],
      ),
      child: TextFormField(
        controller: widget.controller,
        focusNode: _focus,
        obscureText: widget.obscureText,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        enabled: !_isDisabled,
        onChanged: widget.onChanged,
        style: const TextStyle(fontSize: 14),
        decoration: _buildDecoration(),
      ),
    );
  }

  // ── Variant C: Floating label ────────────────────────────
  Widget _buildFloatingVariant() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: _isDisabled ? secondaryGray.withAlpha(13) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: _shadowColor,
            blurRadius: 0,
            spreadRadius: 3,
          ),
        ],
      ),
      child: TextFormField(
        controller: widget.controller,
        focusNode: _focus,
        obscureText: widget.obscureText,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        enabled: !_isDisabled,
        onChanged: widget.onChanged,
        style: const TextStyle(fontSize: 14),
        decoration: _buildDecoration(floatingLabel: true),
      ),
    );
  }
}

// ─── Demo ─────────────────────────────────────────────────────
void main() => runApp(const SharecoApp());

class SharecoApp extends StatelessWidget {
  const SharecoApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Shareco TextFields',
      theme: ThemeData(
        fontFamily: 'SF Pro Display',
        scaffoldBackgroundColor: const Color(0xFFF4F4F8),
        colorScheme: ColorScheme.fromSeed(seedColor: primaryPurple),
      ),
      home: const _DemoScreen(),
    );
  }
}

class _DemoScreen extends StatefulWidget {
  const _DemoScreen();
  @override
  State<_DemoScreen> createState() => _DemoScreenState();
}

class _DemoScreenState extends State<_DemoScreen> {
  bool _showPass = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Shareco TextField System')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Variant A: Gradient
            _label('Variant A — gradient border'),
            SharecoTextField(
              variant: TextFieldVariant.gradient,
              placeholder: 'Họ và tên',
              prefixIcon: const GradientIcon(Icons.person_outline_rounded),
            ),
            const SizedBox(height: 12),
            SharecoTextField(
              variant: TextFieldVariant.gradient,
              placeholder: 'Email của bạn',
              keyboardType: TextInputType.emailAddress,
              prefixIcon: const GradientIcon(Icons.mail_outline_rounded),
            ),
            const SizedBox(height: 28),

            // ── Variant B: Purple accent
            _label('Variant B — purple accent'),
            SharecoTextField(
              variant: TextFieldVariant.accent,
              placeholder: 'Số điện thoại',
              keyboardType: TextInputType.phone,
              prefixIcon: const Icon(Icons.phone_outlined,
                  color: primaryPurple, size: 22),
            ),
            const SizedBox(height: 12),
            SharecoTextField(
              variant: TextFieldVariant.accent,
              placeholder: 'Mật khẩu',
              obscureText: !_showPass,
              prefixIcon: const Icon(Icons.lock_outline_rounded,
                  color: primaryPurple, size: 22),
              suffixIcon: GestureDetector(
                onTap: () => setState(() => _showPass = !_showPass),
                child: Icon(
                  _showPass
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: secondaryGray,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(height: 28),

            // ── Variant C: Floating label
            _label('Variant C — floating label'),
            SharecoTextField(
              variant: TextFieldVariant.floating,
              label: 'Tên người dùng',
            ),
            const SizedBox(height: 12),
            SharecoTextField(
              variant: TextFieldVariant.floating,
              label: 'Địa chỉ email',
              keyboardType: TextInputType.emailAddress,
              prefixIcon: const Icon(Icons.mail_outline_rounded,
                  color: primaryPurple, size: 22),
            ),
            const SizedBox(height: 28),

            // ── States
            _label('States'),
            SharecoTextField(
              variant: TextFieldVariant.accent,
              placeholder: 'Email',
              fieldState: TextFieldState.error,
              helperText: 'Email không hợp lệ',
              prefixIcon: const Icon(Icons.mail_outline_rounded,
                  color: Color(0xFFFF4E4E), size: 22),
            ),
            const SizedBox(height: 12),
            SharecoTextField(
              variant: TextFieldVariant.accent,
              placeholder: 'Họ và tên',
              fieldState: TextFieldState.success,
              helperText: 'Tên hợp lệ',
              prefixIcon: const Icon(Icons.person_outline_rounded,
                  color: primaryPurple, size: 22),
            ),
            const SizedBox(height: 12),
            SharecoTextField(
              variant: TextFieldVariant.accent,
              placeholder: 'Không thể chỉnh sửa',
              fieldState: TextFieldState.disabled,
              prefixIcon: const Icon(Icons.lock_outline_rounded,
                  color: secondaryGray, size: 22),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: secondaryGray,
        letterSpacing: 0.8,
      ),
    ),
  );
}