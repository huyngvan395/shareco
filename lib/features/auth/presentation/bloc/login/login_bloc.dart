import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shareco/features/auth/domain/usecases/login_usecase.dart';
import 'package:shareco/features/auth/presentation/bloc/login/login_event.dart';
import 'package:shareco/features/auth/presentation/bloc/login/login_state.dart';

class LoginBloc extends Bloc<LoginEvent, LoginState>{
  final LoginUseCase loginUseCase;

  LoginBloc(this.loginUseCase): super(LoginInitial()){
    on<LoginSubmitted>((event, emit) async{
        emit(LoginLoading());
        try{
          await loginUseCase.call(event.email, event.password, 'password');
          emit(LoginSuccess());
        }catch (e){
          emit(LoginFailure(e.toString()));
        }
    });
  }
}