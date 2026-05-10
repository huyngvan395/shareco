import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shareco/features/video/domain/usecases/video_usecases.dart';
import 'package:shareco/features/video/presentation/bloc/create_video_event.dart';
import 'package:shareco/features/video/presentation/bloc/create_video_state.dart';

import '../../../../core/services/video/video_processing_services.dart';

class CreateVideoBloc extends Bloc<CreateVideoEvent, CreateVideoState> {
  final CreateVideoUseCase createVideo;

  CreateVideoBloc({required this.createVideo})
      : super(const CreateVideoInitial()) {
    on<CreateVideoPickRequested>(_onPick);
    on<CreateVideoPickedFromPath>(_onPickedFromPath);
    on<CreateVideoRecordRequested>(_onRecord);
    on<CreateVideoResetRequested>(_onReset);
    on<CreateVideoVisibilityChanged>(_onVisibilityChanged);
    on<CreateVideoSettingChanged>(_onSettingChanged);
    on<CreateVideoThumbnailChanged>(_onThumbnailChanged);
    on<CreateVideoPostRequested>(_onPost);
    on<CreateVideoUploadProgressChanged>(_onUploadProgressChanged);
  }

  Future<void> _onPick(
      CreateVideoPickRequested _, Emitter<CreateVideoState> emit) async {
    emit(const CreateVideoLoading());
    await Future.delayed(const Duration(milliseconds: 200));
    emit(const CreateVideoPickedFile(
      localPath: '/local/video.mp4',
      thumbnailPath: '/local/thumb.jpg',
    ));
  }

  Future<void> _onPickedFromPath(
      CreateVideoPickedFromPath event,
      Emitter<CreateVideoState> emit,
      ) async {
    emit(const CreateVideoLoading());

    String? thumbnail = event.thumbnailPath;

    if (thumbnail == null || thumbnail.isEmpty) {
      thumbnail = await VideoProcessingService.generateThumbnail(event.localPath);
    }

    if (thumbnail == null || thumbnail.isEmpty) {
      emit(const CreateVideoError('Failed to generate thumbnail'));
      return;
    }

    emit(CreateVideoPickedFile(
      localPath: event.localPath,
      thumbnailPath: thumbnail,
    ));
  }

  Future<void> _onRecord(
      CreateVideoRecordRequested _, Emitter<CreateVideoState> emit) async {
    emit(const CreateVideoLoading());
    await Future.delayed(const Duration(milliseconds: 200));
    emit(const CreateVideoPickedFile(
      localPath: '/local/recorded.mp4',
      thumbnailPath: '/local/recorded_thumb.jpg',
    ));
  }

  void _onReset(CreateVideoResetRequested _, Emitter<CreateVideoState> emit) {
    emit(const CreateVideoInitial());
  }

  void _onVisibilityChanged(
      CreateVideoVisibilityChanged event, Emitter<CreateVideoState> emit) {
    final current = state;
    if (current is! CreateVideoPickedFile) return;
    emit(current.copyWith(visibility: event.visibility));
  }

  void _onSettingChanged(
      CreateVideoSettingChanged event, Emitter<CreateVideoState> emit) {
    final current = state;
    if (current is! CreateVideoPickedFile) return;
    emit(current.copyWith(
      allowComment: event.allowComment,
      allowDuet: event.allowDuet,
      allowStitch: event.allowStitch,
    ));
  }

  Future<void> _onPost(
      CreateVideoPostRequested event, Emitter<CreateVideoState> emit) async {
    final current = state;
    if (current is! CreateVideoPickedFile) return;

    emit(const CreateVideoUploading(progress: 0));

    final result = await createVideo(
      videoPath: current.localPath,
      thumbnailPath: current.thumbnailPath,
      caption: event.caption.isEmpty ? null : event.caption,
      visibility: current.visibility,
      onProgress: (p) {
        add(CreateVideoUploadProgressChanged(p));
      },
    );

    result.fold(
          (f) => emit(CreateVideoError(f.message)),
          (_) => emit(const CreateVideoSuccess()),
    );
  }

  void _onThumbnailChanged(
      CreateVideoThumbnailChanged event,
      Emitter<CreateVideoState> emit,
      ) {
    final current = state;
    if (current is! CreateVideoPickedFile) return;
    emit(current.copyWith(thumbnailPath: event.thumbnailPath));
  }

  void _onUploadProgressChanged(
      CreateVideoUploadProgressChanged event,
      Emitter<CreateVideoState> emit,
      ) {
    emit(CreateVideoUploading(progress: event.progress));
  }
}