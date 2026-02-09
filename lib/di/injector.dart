import 'package:get_it/get_it.dart';
import 'package:shareco/core/services/supabase/index.dart';
import 'package:shareco/features/auth/data/datasources/auth_remote_datasources.dart';
import 'package:shareco/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:shareco/features/auth/domain/repositories/auth_repository.dart';
import 'package:shareco/features/auth/domain/usecases/login_usecase.dart';
import 'package:shareco/features/auth/presentation/bloc/login/login_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final sl = GetIt.instance;

Future<void> initInjector() async {
  sl.registerLazySingleton<SupabaseClient>(() => SupabaseService.client);
  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(sl()),
  );
  sl.registerLazySingleton<AuthRepository>(
      () => AuthRepositoryImpl(sl())
  );
  sl.registerLazySingleton<LoginUseCase>(
      () => LoginUseCase(sl())
  );
  sl.registerFactory<LoginBloc>(
      () => LoginBloc(sl())
  );
}
