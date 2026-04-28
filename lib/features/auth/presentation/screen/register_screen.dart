// features/auth/presentation/screen/register_screen.dart
//
// RegisterScreen chỉ dùng trong AuthBottomSheet.
// Điều hướng đi qua callbacks — KHÔNG dùng GoRouter / context.go().

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/validators/validators.dart';
import '../../../../core/widgets/button.dart';
import '../../../../core/widgets/text_field.dart';
import '../../../../core/widgets/text_logo.dart';
import '../bloc/register/register_bloc.dart';
import '../bloc/register/register_event.dart';
import '../bloc/register/register_state.dart';

class RegisterScreen extends StatefulWidget {
  final VoidCallback? onBack;
  final VoidCallback? onNavigateToLogin;
  final VoidCallback? onSuccess;

  const RegisterScreen({
    super.key,
    this.onBack,
    this.onNavigateToLogin,
    this.onSuccess,
  });

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  String? _validateConfirm(String? v) {
    if (v != _passwordCtrl.text) return 'Passwords do not match';
    return null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    context.read<RegisterBloc>().add(RegisterSubmitted(
      email: _emailCtrl.text.trim(),
      password: _passwordCtrl.text,
      username: _usernameCtrl.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<RegisterBloc, RegisterState>(
      listener: (context, state) {
        debugPrint('🔄 RegisterState: $state');
        if (state is RegisterSuccess) {
          widget.onSuccess?.call();
        } else if (state is RegisterFailure) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(state.message),
            backgroundColor: AppColors.error,
          ));
        }
      },
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: AppSizes.xxl,
          right: AppSizes.xxl,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSizes.xxl,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(children: [
                IconButton(
                  onPressed: widget.onBack,
                  icon: const Icon(Icons.close,
                      color: Colors.white, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: AppSizes.md),
                const Text(
                  AppStrings.signUp,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: AppSizes.fontXxl,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ]),
              const SizedBox(height: AppSizes.xxxl),

              AppTextField(
                hint: 'Đặt username',
                label: AppStrings.username,
                controller: _usernameCtrl,
                validator: AppValidators.username,
                prefixIcon: const Icon(Icons.alternate_email,
                    color: AppColors.textMuted),
              ),
              const SizedBox(height: AppSizes.lg),

              AppTextField(
                hint: 'Nhập email',
                label: AppStrings.email,
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                validator: AppValidators.email,
                prefixIcon: const Icon(Icons.email_outlined,
                    color: AppColors.textMuted),
              ),
              const SizedBox(height: AppSizes.lg),

              AppTextField(
                hint: 'Tạo mật khẩu',
                label: AppStrings.password,
                controller: _passwordCtrl,
                isPassword: true,
                validator: AppValidators.password,
                prefixIcon:
                const Icon(Icons.lock_outline, color: AppColors.textMuted),
              ),
              const SizedBox(height: AppSizes.lg),

              AppTextField(
                hint: 'Xác nhận mật khẩu',
                label: 'Xác nhận mật khẩu',
                controller: _confirmCtrl,
                isPassword: true,
                validator: _validateConfirm,
                prefixIcon:
                const Icon(Icons.lock_outline, color: AppColors.textMuted),
              ),
              const SizedBox(height: AppSizes.xxl),

              RichText(
                textAlign: TextAlign.center,
                text: const TextSpan(
                  style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: AppSizes.fontSm + 1),
                  children: [
                    TextSpan(text: 'Bằng cách đăng ký, bạn đồng ý với các điều khoản của chúng tôi. '),
                    TextSpan(
                        text: 'Điều khoản dịch vụ',
                        style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600)),
                    TextSpan(text: ' và '),
                    TextSpan(
                        text: 'Chính sách bảo mật',
                        style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const SizedBox(height: AppSizes.xxl),

              BlocBuilder<RegisterBloc, RegisterState>(
                builder: (context, state) => AppButton(
                  label: AppStrings.signUp,
                  isLoading: state is RegisterLoading,
                  onPressed: _submit,
                ),
              ),
              const SizedBox(height: AppSizes.xxl),

              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(AppStrings.hasAccount,
                        style: TextStyle(color: AppColors.textMuted)),
                    GestureDetector(
                      onTap: widget.onNavigateToLogin,
                      child: const Text(AppStrings.signIn,
                          style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}