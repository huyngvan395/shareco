// features/auth/presentation/bloc/login/login_bloc.dart

import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/usecases/login_usecase.dart';
import 'login_event.dart';
import 'login_state.dart';

class LoginBloc extends Bloc<LoginEvent, LoginState> {
  final LoginUseCase loginUseCase;

  LoginBloc({required this.loginUseCase}) : super(LoginInitial()) {
    on<LoginSubmitted>(_onSubmitted);
    on<LoginReset>(_onReset);
  }

  Future<void> _onSubmitted(
      LoginSubmitted event,
      Emitter<LoginState> emit,
      ) async {
    emit(LoginLoading());
    final result = await loginUseCase(
      email: event.email,
      password: event.password,
    );
    result.fold(
          (failure) => emit(LoginFailure(failure.message)),
          (session) => emit(LoginSuccess(session)),
    );
  }

  void _onReset(LoginReset event, Emitter<LoginState> emit) {
    emit(LoginInitial());
  }
}