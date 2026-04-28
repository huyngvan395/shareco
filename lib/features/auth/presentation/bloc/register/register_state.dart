// features/auth/presentation/bloc/register/register_state.dart

import 'package:equatable/equatable.dart';
import '../../../domain/entities/auth_session.dart';

abstract class RegisterState extends Equatable {
  const RegisterState();
  @override
  List<Object?> get props => [];
}

class RegisterInitial extends RegisterState {
  const RegisterInitial();
}

class RegisterLoading extends RegisterState {
  const RegisterLoading();
}

class RegisterSuccess extends RegisterState {
  final AuthSession session;
  const RegisterSuccess(this.session);
  @override
  List<Object?> get props => [session];
}

class RegisterFailure extends RegisterState {
  final String message;
  const RegisterFailure(this.message);
  @override
  List<Object?> get props => [message];
}