// features/auth/presentation/screen/login_screen.dart
//
// LoginScreen chỉ dùng trong AuthBottomSheet.
// Điều hướng đi qua callbacks — KHÔNG dùng GoRouter / context.go().

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/services/supabase/index.dart';
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
  String? _errorMessage;

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

  Future<void> _showForgotPasswordDialog(BuildContext context) async {
    final resetEmailCtrl = TextEditingController(text: _emailCtrl.text.trim());
    bool sending = false;
    String? feedback;
    bool isSuccess = false;

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surfaceElevated,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text(
            'Khôi phục mật khẩu',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Nhập email đã đăng ký tài khoản để nhận liên kết đặt lại mật khẩu:',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: resetEmailCtrl,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'example@email.com',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: AppColors.surfaceCard,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              if (feedback != null) ...[
                const SizedBox(height: 10),
                Text(
                  feedback!,
                  style: TextStyle(
                    color: isSuccess ? AppColors.success : AppColors.error,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text(
                'Đóng',
                style: TextStyle(color: Colors.white70),
              ),
            ),
            ElevatedButton(
              onPressed: sending
                  ? null
                  : () async {
                      final email = resetEmailCtrl.text.trim();
                      final err = AppValidators.email(email);
                      if (err != null) {
                        setDialogState(() {
                          feedback = err;
                          isSuccess = false;
                        });
                        return;
                      }
                      setDialogState(() {
                        sending = true;
                        feedback = null;
                      });
                      try {
                        await SupabaseService.auth.resetPasswordForEmail(
                          email,
                          redirectTo: 'shareco://login-callback',
                        );
                        setDialogState(() {
                          sending = false;
                          isSuccess = true;
                          feedback =
                              'Đã gửi email khôi phục! Vui lòng kiểm tra hộp thư của bạn.';
                        });
                      } catch (e) {
                        setDialogState(() {
                          sending = false;
                          isSuccess = false;
                          feedback = 'Không thể gửi yêu cầu: $e';
                        });
                      }
                    },
              child: sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Gửi liên kết'),
            ),
          ],
        ),
      ),
    );
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
          setState(() => _errorMessage = state.message);
        } else {
          setState(() => _errorMessage = null);
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
                hint: 'Nhập email của bạn',
                label: AppStrings.email,
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                validator: AppValidators.email,
                prefixIcon: const Icon(Icons.email_outlined,
                    color: AppColors.textMuted),
              ),
              const SizedBox(height: AppSizes.lg),

              AppTextField(
                hint: 'Nhập mật khẩu',
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
                  onPressed: () => _showForgotPasswordDialog(context),
                  child: const Text(AppStrings.forgotPassword,
                      style: TextStyle(
                          color: AppColors.primary,
                          fontSize: AppSizes.fontMd)),
                ),
              ),
              const SizedBox(height: AppSizes.xxl),

              if (_errorMessage != null) ...[
                const SizedBox(height: AppSizes.sm),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.lg,
                    vertical: AppSizes.md,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.error.withAlpha(25),
                    borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                    border: Border.all(color: AppColors.error.withAlpha(80)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          color: AppColors.error, size: 18),
                      const SizedBox(width: AppSizes.sm),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: AppColors.error,
                            fontSize: AppSizes.fontMd,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSizes.sm)
              ],

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

  Future<void> _signInOAuth(
    BuildContext context,
    OAuthProvider provider,
  ) async {
    try {
      await SupabaseService.auth.signInWithOAuth(
        provider,
        redirectTo: 'shareco://login-callback',
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đăng nhập mạng xã hội chưa khả dụng: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      _SocialBtn(
        icon: Icons.g_mobiledata_rounded,
        label: 'Google',
        onTap: () => _signInOAuth(context, OAuthProvider.google),
      ),
      const SizedBox(width: AppSizes.lg),
      _SocialBtn(
        icon: Icons.facebook,
        label: 'Facebook',
        onTap: () => _signInOAuth(context, OAuthProvider.facebook),
      ),
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
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderSubtle),
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