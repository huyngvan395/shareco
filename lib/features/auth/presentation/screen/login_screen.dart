// features/auth/presentation/screen/login_screen.dart
//
// LoginScreen chỉ dùng trong AuthBottomSheet.
// Điều hướng đi qua callbacks — KHÔNG dùng GoRouter / context.go().

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/validators/validators.dart';
import '../../../../core/widgets/button.dart';
import '../../../../core/widgets/text_field.dart';
import '../bloc/login/login_bloc.dart';
import '../bloc/login/login_event.dart';
import '../bloc/login/login_state.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback? onBack;
  final VoidCallback? onNavigateToRegister;
  final VoidCallback? onSuccess;

  const LoginScreen({
    super.key,
    this.onBack,
    this.onNavigateToRegister,
    this.onSuccess,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    context.read<LoginBloc>().add(LoginSubmitted(email: _emailCtrl.text.trim(),password: _passwordCtrl.text.trim() ));
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<LoginBloc, LoginState>(
      listener: (context, state) {
        debugPrint('🔄 LoginState: $state');
        if (state is LoginSuccess) {
          widget.onSuccess?.call();
        } else if (state is LoginFailure) {
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
                  AppStrings.signIn,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: AppSizes.fontXxl,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ]),
              const SizedBox(height: AppSizes.xxxl),

              AppTextField(
                hint: 'Enter your email',
                label: AppStrings.email,
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                validator: AppValidators.email,
                prefixIcon: const Icon(Icons.email_outlined,
                    color: AppColors.textMuted),
              ),
              const SizedBox(height: AppSizes.lg),

              AppTextField(
                hint: 'Enter your password',
                label: AppStrings.password,
                controller: _passwordCtrl,
                isPassword: true,
                validator: AppValidators.password,
                prefixIcon:
                const Icon(Icons.lock_outline, color: AppColors.textMuted),
              ),
              const SizedBox(height: AppSizes.sm),

              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {},
                  child: const Text(AppStrings.forgotPassword,
                      style: TextStyle(
                          color: AppColors.primary,
                          fontSize: AppSizes.fontMd)),
                ),
              ),
              const SizedBox(height: AppSizes.xxl),

              BlocBuilder<LoginBloc, LoginState>(
                builder: (context, state) => AppButton(
                  label: AppStrings.signIn,
                  isLoading: state is LoginLoading,
                  onPressed: _submit,
                ),
              ),
              const SizedBox(height: AppSizes.xxl),

              const _OrDivider(),
              const SizedBox(height: AppSizes.xxl),
              const _SocialRow(),
              const SizedBox(height: AppSizes.xxxl),

              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(AppStrings.noAccount,
                        style: TextStyle(color: AppColors.textMuted)),
                    GestureDetector(
                      onTap: widget.onNavigateToRegister,
                      child: const Text(AppStrings.signUp,
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

class _OrDivider extends StatelessWidget {
  const _OrDivider();
  @override
  Widget build(BuildContext context) => Row(children: [
    const Expanded(child: Divider(color: AppColors.divider)),
    const Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSizes.md),
      child: Text('OR',
          style: TextStyle(
              color: AppColors.textMuted, fontSize: AppSizes.fontSm)),
    ),
    const Expanded(child: Divider(color: AppColors.divider)),
  ]);
}

class _SocialRow extends StatelessWidget {
  const _SocialRow();
  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      _SocialBtn(
          icon: Icons.g_mobiledata_rounded,
          label: 'Google',
          onTap: () {}),
      const SizedBox(width: AppSizes.lg),
      _SocialBtn(icon: Icons.facebook, label: 'Facebook', onTap: () {}),
    ],
  );
}

class _SocialBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SocialBtn(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.xl, vertical: AppSizes.md),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        Icon(icon, color: AppColors.textSecondary, size: AppSizes.iconLg),
        const SizedBox(width: AppSizes.sm),
        Text(label,
            style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600)),
      ]),
    ),
  );
}