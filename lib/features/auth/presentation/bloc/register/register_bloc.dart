import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shareco/features/auth/domain/usecases/register_usecase.dart';
import 'package:shareco/features/auth/presentation/bloc/register/register_event.dart';
import 'package:shareco/features/auth/presentation/bloc/register/register_state.dart';

class RegisterBloc extends Bloc<RegisterEvent, RegisterState> {
  final RegisterUseCase registerUseCase;

  RegisterBloc(this.registerUseCase) : super(RegisterInitial()){
    on<RegisterSubmitted>((event, emit) async{
      emit(RegisterLoading());
      try {
        await registerUseCase.call(event.email, event.password, 'password');
        emit(RegisterSuccess());
      } catch (e) {
        emit(RegisterFailure(e.toString()));
      }
    });
  }

}