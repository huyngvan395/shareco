// core/helpers/require_auth.dart
//
// requireAuth — helper dùng global, gọi từ bất kì chỗ nào có BuildContext.
//
// ── Cách dùng ──────────────────────────────────────────────────────────────
//
//  1. Action đơn giản (callback):
//       context.requireAuth(() => doSomething());
//
//  2. Async action:
//       context.requireAuth(() async => await submitPost());
//
//  3. Điều hướng:
//       context.requireAuth(() => context.push('/chat'));
//
//  4. Trong onTap của bất kì widget nào:
//       GestureDetector(
//         onTap: () => context.requireAuth(() => openProfile()),
//       )
//
//  5. Widget guard (hiển thị fallback khi chưa login):
//       AuthGuard(
//         child: LikeButton(),
//         fallback: LoginPromptButton(),
//       )
//
// ── Cơ chế ─────────────────────────────────────────────────────────────────
//
//  - Nếu đã đăng nhập   → thực thi action ngay lập tức
//  - Nếu chưa đăng nhập → hiện AuthBottomSheet, đợi đăng nhập xong
//                          rồi tự động thực thi lại action (pendingAction)

import 'package:flutter/material.dart';
import '../notifier/auth_notifier.dart';
import '../widgets/auth_bottom_sheet.dart';
import '../../di/injector.dart';

// ─── Extension on BuildContext ─────────────────────────────────────────────────

extension RequireAuthExtension on BuildContext {
  /// Thực thi [action] nếu đã đăng nhập.
  /// Nếu chưa → show AuthBottomSheet, sau khi đăng nhập thành công
  /// sẽ tự động gọi lại [action].
  ///
  /// [runAfterLogin] — có thực thi action sau khi login hay không.
  ///   Mặc định true. Set false nếu chỉ muốn mở sheet mà không cần callback.
  void requireAuth(VoidCallback action, {bool runAfterLogin = true}) {
    final auth = sl<AuthNotifier>();
    if (auth.isAuthenticated) {
      action();
    } else {
      AuthBottomSheet.show(this, pendingAction: runAfterLogin ? action : null);
    }
  }

  /// Kiểm tra trạng thái auth hiện tại (không side-effect).
  bool get isAuthenticated => sl<AuthNotifier>().isAuthenticated;
}

// ─── AuthGuard widget ──────────────────────────────────────────────────────────
//
// Dùng khi muốn render widget khác nhau dựa trên trạng thái auth.
// Tự lắng nghe AuthNotifier nên tự rebuild khi auth thay đổi.
//
// Ví dụ:
//   AuthGuard(
//     child: BookmarkButton(isBookmarked: true),
//     fallback: GestureDetector(
//       onTap: () => context.requireAuth(() {}),
//       child: BookmarkButton(isBookmarked: false),
//     ),
//   )

class AuthGuard extends StatelessWidget {
  /// Widget hiển thị khi đã đăng nhập.
  final Widget child;

  /// Widget hiển thị khi chưa đăng nhập.
  /// Nếu null và chưa đăng nhập, widget sẽ ẩn (SizedBox.shrink).
  final Widget? fallback;

  const AuthGuard({super.key, required this.child, this.fallback});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: sl<AuthNotifier>(),
      builder: (context, guardedChild) {
        if (sl<AuthNotifier>().isAuthenticated) {
          return guardedChild ?? child;
        }
        return fallback ?? const SizedBox.shrink();
      },
      child: child,
    );
  }
}
