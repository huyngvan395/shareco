// features/auth/presentation/bloc/login/login_state.dart

import 'package:equatable/equatable.dart';
import '../../../domain/entities/auth_session.dart';

abstract class LoginState extends Equatable {
  const LoginState();
  @override
  List<Object?> get props => [];
}

class LoginInitial extends LoginState {
  const LoginInitial();
}

class LoginLoading extends LoginState {
  const LoginLoading();
}

class LoginSuccess extends LoginState {
  final AuthSession session;
  const LoginSuccess(this.session);
  @override
  List<Object?> get props => [session];
}

class LoginFailure extends LoginState {
  final String message;
  const LoginFailure(this.message);
  @override
  List<Object?> get props => [message];
}