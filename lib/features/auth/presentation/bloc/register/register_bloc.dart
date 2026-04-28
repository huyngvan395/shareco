// features/auth/presentation/bloc/register/register_bloc.dart

import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/usecases/register_usecase.dart';
import 'register_event.dart';
import 'register_state.dart';

class RegisterBloc extends Bloc<RegisterEvent, RegisterState> {
  final RegisterUseCase registerUseCase;

  RegisterBloc({required this.registerUseCase})
      : super(const RegisterInitial()) {
    on<RegisterSubmitted>(_onSubmitted);
    on<RegisterReset>(_onReset);
  }

  Future<void> _onSubmitted(
      RegisterSubmitted event,
      Emitter<RegisterState> emit,
      ) async {
    emit(const RegisterLoading());
    final result = await registerUseCase(
      email: event.email,
      password: event.password,
      username: event.username,
    );
    result.fold(
          (failure) => emit(RegisterFailure(failure.message)),
          (session) => emit(RegisterSuccess(session)),
    );
  }

  void _onReset(RegisterReset event, Emitter<RegisterState> emit) {
    emit(const RegisterInitial());
  }
}