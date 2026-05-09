// features/profile/domain/repositories/profile_repository.dart

import 'package:dartz/dartz.dart';
import '../../../../core/errors/failure.dart';
import '../entities/profile_entity.dart';

abstract class ProfileRepository {
  Future<Either<Failure, ProfileEntity>> getProfile(String userId);
  Future<Either<Failure, ProfileEntity>> getCurrentProfile();
  Future<Either<Failure, ProfileEntity>> updateProfile({
    String? displayName,
    String? bio,
    String? avatarUrl,
    String? gender,
    DateTime? dob,
    String? countryCode,
    String? languageCode,
  });
  Future<Either<Failure, bool>> toggleFollow(String targetUserId);
  Future<Either<Failure, List<ProfileEntity>>> getFollowers(
      {required String userId, int page = 0});
  Future<Either<Failure, List<ProfileEntity>>> getFollowing(
      {required String userId, int page = 0});
  Future<Either<Failure, String>> uploadAvatar(String filePath);
}