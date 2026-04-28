// features/auth/presentation/screen/gate_screen.dart
//
// GateScreen chỉ dùng trong AuthBottomSheet (mode sheet).
// KHÔNG có standalone mode — auth flow không đi qua GoRouter.

import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/button.dart';
import '../../../../core/widgets/text_logo.dart';

class GateScreen extends StatelessWidget {
  final VoidCallback? onBack;
  final VoidCallback? onNavigateToLogin;
  final VoidCallback? onNavigateToRegister;
  final VoidCallback? onDismiss;

  const GateScreen({
    super.key,
    this.onBack,
    this.onNavigateToLogin,
    this.onNavigateToRegister,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.xxl,
        AppSizes.sm,
        AppSizes.xxl,
        AppSizes.xxl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.close, color: Colors.white, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const TextLogo(),
          const SizedBox(height: AppSizes.md),
          const Text(
            'Đăng nhập để tiếp tục',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: AppSizes.fontXxl,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSizes.sm),
          const Text(
            'Bạn cần có tài khoản để truy cập tính năng này.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: AppSizes.fontMd,
              height: 1.5,
            ),
          ),
          const SizedBox(height: AppSizes.xxxl),

          const _BenefitRow(
            icon: Icons.videocam_outlined,
            text: 'Đăng video và ảnh lên feed',
          ),
          const SizedBox(height: AppSizes.md),
          const _BenefitRow(
            icon: Icons.chat_bubble_outline_rounded,
            text: 'Nhắn tin với bạn bè',
          ),
          const SizedBox(height: AppSizes.md),
          const _BenefitRow(
            icon: Icons.favorite_border_rounded,
            text: 'Lưu nội dung yêu thích',
          ),
          const SizedBox(height: AppSizes.xxxl),

          AppButton(label: AppStrings.signIn, onPressed: onNavigateToLogin),
          const SizedBox(height: AppSizes.md),
          AppButton(
            label: AppStrings.signUp,
            isOutlined: true,
            onPressed: onNavigateToRegister,
          ),
          const SizedBox(height: AppSizes.xl),
          GestureDetector(
            onTap: onDismiss,
            child: const Text(
              'Tiếp tục không đăng nhập',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: AppSizes.fontMd,
                decoration: TextDecoration.underline,
                decorationColor: AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _BenefitRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: AppSizes.md),
        Text(
          text,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: AppSizes.fontLg,
          ),
        ),
      ],
    );
  }
}
