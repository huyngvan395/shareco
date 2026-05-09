// features/profile/data/datasources/profile_remote_datasource.dart

import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;

import '../../../../core/constants/env.dart';
import '../../../../core/errors/exception.dart';
import '../../../../core/services/supabase/index.dart';
import '../models/profile_model.dart';

abstract class ProfileRemoteDataSource {
  Future<ProfileModel> getProfile(String userId);
  Future<ProfileModel> getCurrentProfile();
  Future<ProfileModel> updateProfile(
      {required String userId, required Map<String, dynamic> data});
  Future<bool> toggleFollow(String targetUserId);
  Future<List<ProfileModel>> getFollowers(
      {required String userId, int page = 0});
  Future<List<ProfileModel>> getFollowing(
      {required String userId, int page = 0});
  Future<String> uploadAvatar(
      {required String userId, required String filePath});
}

class ProfileRemoteDataSourceImpl implements ProfileRemoteDataSource {
  static const _table = 'profiles';
  static const _followsTable = 'user_follows';
  static const _limit = Env.defaultPageSize;

  @override
  Future<ProfileModel> getProfile(String userId) async {
    try {
      final uid = SupabaseService.currentUserId;
      final row = await SupabaseService.from(_table)
          .select()
          .eq('id', userId)
          .single();

      bool isFollowing = false;
      if (uid != null && uid != userId) {
        final f = await SupabaseService.from(_followsTable)
            .select('follower_id')
            .eq('follower_id', uid)
            .eq('following_id', userId)
            .maybeSingle();
        isFollowing = f != null;
      }

      return ProfileModel.fromJson(row as Map<String, dynamic>,
          isFollowing: isFollowing,
          isCurrentUser: uid == userId);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<ProfileModel> getCurrentProfile() async {
    final uid = SupabaseService.currentUserId;
    if (uid == null) throw const AuthException();
    return getProfile(uid);
  }

  @override
  Future<ProfileModel> updateProfile(
      {required String userId, required Map<String, dynamic> data}) async {
    try {
      final row = await SupabaseService.from(_table)
          .update(data)
          .eq('id', userId)
          .select()
          .single();
      return ProfileModel.fromJson(row as Map<String, dynamic>,
          isCurrentUser: true);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<bool> toggleFollow(String targetUserId) async {
    try {
      final uid = SupabaseService.currentUserId;
      if (uid == null) throw const AuthException();

      // Check if already following
      final existing = await SupabaseService.from(_followsTable)
          .select()
          .eq('follower_id', uid)
          .eq('following_id', targetUserId)
          .maybeSingle();

      if (existing != null) {
        await SupabaseService.from(_followsTable)
            .delete()
            .eq('follower_id', uid)
            .eq('following_id', targetUserId);
        return false; // unfollowed
      } else {
        await SupabaseService.from(_followsTable)
            .insert({'follower_id': uid, 'following_id': targetUserId});
        return true; // followed
      }
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<List<ProfileModel>> getFollowers(
      {required String userId, int page = 0}) async {
    try {
      final (from, to) = SupabaseService.pageRange(page, _limit);
      final rows = await SupabaseService.from(_followsTable)
          .select('profiles:follower_id(*)')
          .eq('following_id', userId)
          .range(from, to) as List;
      return [
        for (final r in rows)
          ProfileModel.fromJson(
              (r['profiles'] ?? r) as Map<String, dynamic>)
      ];
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<List<ProfileModel>> getFollowing(
      {required String userId, int page = 0}) async {
    try {
      final (from, to) = SupabaseService.pageRange(page, _limit);
      final rows = await SupabaseService.from(_followsTable)
          .select('profiles:following_id(*)')
          .eq('follower_id', userId)
          .range(from, to) as List;
      return [
        for (final r in rows)
          ProfileModel.fromJson(
              (r['profiles'] ?? r) as Map<String, dynamic>)
      ];
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<String> uploadAvatar(
      {required String userId, required String filePath}) async {
    try {
      final path = Env.avatarPath(userId);
      await SupabaseService.bucket(Env.bucketAvatars)
          .upload(path, filePath as dynamic, fileOptions: const FileOptions(upsert: true));
      return SupabaseService.publicUrl(Env.bucketAvatars, path);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
}