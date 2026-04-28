// di/injector.dart

import 'package:get_it/get_it.dart';
import '../core/notifier/auth_notifier.dart';
import '../core/theme/theme_provider.dart';
import '../features/auth/data/datasources/auth_remote_datasources.dart';
import '../features/auth/data/repositories/auth_repository_impl.dart';
import '../features/auth/domain/repositories/auth_repository.dart';
import '../features/auth/domain/usecases/login_usecase.dart';
import '../features/auth/domain/usecases/register_usecase.dart';

final sl = GetIt.instance;

Future<void> setupInjector() async {
  // ── Core ────────────────────────────────────────────────────────────────────
  sl.registerLazySingleton(() => ThemeProvider());
  sl.registerLazySingleton(() => AuthNotifier());

  // ── Auth: DataSources ────────────────────────────────────────────────────────
  sl.registerLazySingleton<AuthRemoteDataSource>(
        () => AuthRemoteDataSourceImpl(),
  );

  // ── Auth: Repository ─────────────────────────────────────────────────────────
  sl.registerLazySingleton<AuthRepository>(
        () => AuthRepositoryImpl(remoteDataSource: sl()),
  );

  // ── Auth: UseCases ───────────────────────────────────────────────────────────
  sl.registerLazySingleton(() => LoginUseCase(sl()));
  sl.registerLazySingleton(() => RegisterUseCase(sl()));

  // ── Feed: DataSources ────────────────────────────────────────────────────────
  // sl.registerLazySingleton<FeedRemoteDataSource>(
  //       () => FeedRemoteDataSourceImpl(),
  // );
  //
  // // ── Feed: Repository ─────────────────────────────────────────────────────────
  // sl.registerLazySingleton<FeedRepository>(
  //       () => FeedRepositoryImpl(remoteDataSource: sl()),
  // );
  //
  // // ── Feed: UseCases ───────────────────────────────────────────────────────────
  // sl.registerLazySingleton(() => GetFeedUseCase(sl()));
  // sl.registerLazySingleton(() => ToggleVideoLikeUseCase(sl()));
  // sl.registerLazySingleton(() => TogglePostLikeUseCase(sl()));
  //
  // // ── Feed: BLoC (factory — fresh instance per BlocProvider) ───────────────────
  // sl.registerFactory(
  //       () => FeedBloc(
  //     getFeedUseCase: sl(),
  //     toggleVideoLikeUseCase: sl(),
  //     togglePostLikeUseCase: sl(),
  //   ),
  // );
}