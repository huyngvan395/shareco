// features/profile/data/repositories/profile_repository_impl.dart

import 'package:dartz/dartz.dart';

import '../../../../core/errors/exception.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/services/supabase/index.dart';
import '../../domain/entities/profile_entity.dart';
import '../../domain/repositories/profile_repository.dart';
import '../datasources/profile_remote_datasource.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  final ProfileRemoteDataSource remote;

  const ProfileRepositoryImpl({required this.remote});

  Either<Failure, T> _handle<T>(dynamic e) {
    if (e is AuthException) return Left(AuthFailure(e.message));
    if (e is ServerException) return Left(ServerFailure(e.message));
    if (e is NetworkException) return Left(NetworkFailure(e.message));
    return Left(UnknownFailure(e.toString()));
  }

  @override
  Future<Either<Failure, ProfileEntity>> getProfile(String userId) async {
    try {
      return Right(await remote.getProfile(userId));
    } catch (e) {
      return _handle(e);
    }
  }

  @override
  Future<Either<Failure, ProfileEntity>> getCurrentProfile() async {
    try {
      return Right(await remote.getCurrentProfile());
    } catch (e) {
      return _handle(e);
    }
  }

  @override
  Future<Either<Failure, ProfileEntity>> updateProfile({
    String? displayName,
    String? bio,
    String? avatarUrl,
    String? gender,
    DateTime? dob,
    String? countryCode,
    String? languageCode,
  }) async {
    try {
      final uid = SupabaseService.currentUserId;
      if (uid == null) return const Left(AuthFailure());

      final data = <String, dynamic>{};
      if (displayName != null) data['display_name'] = displayName;
      if (bio != null) data['bio'] = bio;
      if (avatarUrl != null) data['avatar_url'] = avatarUrl;
      if (gender != null) data['gender'] = gender;
      if (dob != null) data['dob'] = dob.toIso8601String().split('T').first;
      if (countryCode != null) data['country_code'] = countryCode;
      if (languageCode != null) data['language_code'] = languageCode;

      return Right(await remote.updateProfile(userId: uid, data: data));
    } catch (e) {
      return _handle(e);
    }
  }

  @override
  Future<Either<Failure, bool>> toggleFollow(String targetUserId) async {
    try {
      return Right(await remote.toggleFollow(targetUserId));
    } catch (e) {
      return _handle(e);
    }
  }

  @override
  Future<Either<Failure, List<ProfileEntity>>> getFollowers({
    required String userId,
    int page = 0,
  }) async {
    try {
      return Right(await remote.getFollowers(userId: userId, page: page));
    } catch (e) {
      return _handle(e);
    }
  }

  @override
  Future<Either<Failure, List<ProfileEntity>>> getFollowing({
    required String userId,
    int page = 0,
  }) async {
    try {
      return Right(await remote.getFollowing(userId: userId, page: page));
    } catch (e) {
      return _handle(e);
    }
  }

  @override
  Future<Either<Failure, String>> uploadAvatar(String filePath) async {
    try {
      final uid = SupabaseService.currentUserId;
      if (uid == null) return const Left(AuthFailure());
      return Right(await remote.uploadAvatar(userId: uid, filePath: filePath));
    } catch (e) {
      return _handle(e);
    }
  }
}
