// features/chat/domain/usecases/upload_media_usecase.dart
import 'dart:io';
import 'package:dartz/dartz.dart';
import '../../../../core/errors/failure.dart';
import '../repositories/chat_repository.dart';

class UploadMediaUseCase {
  final ChatRepository repo;
  UploadMediaUseCase(this.repo);

  /// [folder]: 'images' | 'audio'
  Future<Either<Failure, String>> call(
      File file, {
        String folder = 'images',
        void Function(double progress)? onProgress,
      }) =>
      repo.uploadMedia(file, folder: folder, onProgress: onProgress);
}