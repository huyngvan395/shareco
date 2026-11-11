import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/services/cloudinary/cloudinary_service.dart';
import '../../../ecommerce/product/domain/entities/product.dart';
import '../../domain/usecases/video_usecases.dart';
import 'create_video_event.dart';
import 'create_video_state.dart';

class CreateVideoBloc extends Bloc<CreateVideoEvent, CreateVideoState> {
  final CreateVideoUseCase _createVideo;

  CreateVideoBloc({required CreateVideoUseCase createVideo})
    : _createVideo = createVideo,
      super(const CreateVideoInitial()) {
    on<CreateVideoPickedFromPath>(_onPickedFromPath);
    on<CreateVideoVisibilityChanged>(_onVisibility);
    on<CreateVideoSettingChanged>(_onSetting);
    on<CreateVideoEffectUpdated>(_onEffectUpdated);
    on<CreateVideoPostRequested>(_onPost);
    on<CreateVideoThumbnailChanged>(_onThumbnailChanged);
    on<CreateVideoUploadProgressChanged>(_onProgressChanged);
    on<CreateVideoProductTagToggled>(_onProductTagToggled);
    on<CreateVideoProductsUpdated>(_onProductsUpdated);
  }

  void _onPickedFromPath(
    CreateVideoPickedFromPath e,
    Emitter<CreateVideoState> emit,
  ) {
    int sizeBytes = 0;
    try {
      final f = File(e.localPath);
      if (f.existsSync()) {
        sizeBytes = f.lengthSync();
      }
    } catch (_) {}

    emit(
      CreateVideoPickedFile(
        localPath: e.localPath,
        thumbnailPath: e.thumbnailPath ?? '',
        effectMeta: e.initialEffects ?? const CreateVideoPickedFile(localPath: '', thumbnailPath: '').effectMeta,
        fileSizeBytes: sizeBytes,
      ),
    );
  }

  void _onVisibility(
    CreateVideoVisibilityChanged e,
    Emitter<CreateVideoState> emit,
  ) {
    if (state is CreateVideoPickedFile) {
      emit((state as CreateVideoPickedFile).copyWith(visibility: e.visibility));
    }
  }

  void _onSetting(CreateVideoSettingChanged e, Emitter<CreateVideoState> emit) {
    if (state is CreateVideoPickedFile) {
      final s = state as CreateVideoPickedFile;
      emit(
        s.copyWith(
          allowComment: e.allowComment,
          allowDuet: e.allowDuet,
          allowStitch: e.allowStitch,
        ),
      );
    }
  }

  void _onEffectUpdated(
    CreateVideoEffectUpdated e,
    Emitter<CreateVideoState> emit,
  ) {
    if (state is CreateVideoPickedFile) {
      final s = state as CreateVideoPickedFile;
      emit(s.copyWith(effectMeta: e.effectMeta));
    }
  }

  void _onThumbnailChanged(
    CreateVideoThumbnailChanged e,
    Emitter<CreateVideoState> emit,
  ) {
    if (state is CreateVideoPickedFile) {
      final current = state as CreateVideoPickedFile;
      emit(current.copyWith(thumbnailPath: e.thumbnailPath));
    }
  }

  void _onProductTagToggled(
    CreateVideoProductTagToggled e,
    Emitter<CreateVideoState> emit,
  ) {
    if (state is CreateVideoPickedFile) {
      final current = state as CreateVideoPickedFile;
      final existing = List<Product>.from(current.taggedProducts);
      final idx = existing.indexWhere((p) => p.id == e.product.id);
      if (idx >= 0) {
        existing.removeAt(idx);
      } else {
        existing.add(e.product);
      }
      emit(current.copyWith(taggedProducts: existing));
    }
  }

  void _onProductsUpdated(
    CreateVideoProductsUpdated e,
    Emitter<CreateVideoState> emit,
  ) {
    if (state is CreateVideoPickedFile) {
      final current = state as CreateVideoPickedFile;
      emit(current.copyWith(taggedProducts: List<Product>.from(e.products)));
    }
  }

  Future<void> _onPost(
    CreateVideoPostRequested e,
    Emitter<CreateVideoState> emit,
  ) async {
    final s = state;
    if (s is! CreateVideoPickedFile) return;

    // Kiểm tra giới hạn dung lượng 100 MB trước khi tải lên
    if (s.fileSizeBytes > CloudinaryService.maxVideoSizeBytes) {
      final mb = s.fileSizeMB.toStringAsFixed(1);
      emit(
        CreateVideoError(
          'Dung lượng video ($mb MB) vượt quá giới hạn tối đa ${CloudinaryService.maxVideoSizeMB} MB. Vui lòng chọn hoặc quay video ngắn hơn.',
        ),
      );
      emit(s);
      return;
    }

    emit(
      CreateVideoUploading(
        progress: 0.01,
        totalBytes: s.fileSizeBytes,
        effectMeta: s.effectMeta,
      ),
    );

    // Đính kèm cấu hình hiệu ứng (filter, nhạc nền, tốc độ, chữ, sticker) vào đường dẫn xử lý
    final videoPathWithEffects = s.effectMeta.attachToVideoUrl(s.localPath);

    // Nếu người dùng có chọn nhạc nền mà chưa ghi trong caption thì có thể giữ nguyên caption,
    // thông tin nhạc đã nằm trong metadata #sc_fx=...
    final result = await _createVideo(
      videoPath: videoPathWithEffects,
      thumbnailPath: s.thumbnailPath,
      caption: e.caption.trim(),
      visibility: s.visibility,
      taggedProductIds: s.taggedProducts.map((p) => p.id).toList(),
      onProgress: (p) {
        add(CreateVideoUploadProgressChanged(p));
      },
    );

    result.fold(
      (failure) {
        emit(CreateVideoError(failure.message));
        emit(s);
      },
      (_) => emit(const CreateVideoSuccess()),
    );
  }

  void _onProgressChanged(
    CreateVideoUploadProgressChanged event,
    Emitter<CreateVideoState> emit,
  ) {
    final current = state;
    if (current is CreateVideoUploading) {
      emit(
        CreateVideoUploading(
          progress: event.progress.clamp(0.0, 1.0),
          totalBytes: current.totalBytes,
          effectMeta: current.effectMeta,
        ),
      );
    }
  }
}
