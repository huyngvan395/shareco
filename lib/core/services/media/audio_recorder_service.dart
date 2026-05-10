import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class AudioRecorderService {
  AudioRecorder? _recorder;
  String? _currentPath;

  /// Kiểm tra quyền micro (không giữ recorder instance)
  Future<bool> hasPermission() async {
    final recorder = AudioRecorder();
    final result = await recorder.hasPermission();
    await recorder.dispose();
    return result;
  }

  Future<void> startRecording() async {
    await _recorder?.dispose();
    _recorder = AudioRecorder();

    final dir = await getTemporaryDirectory();
    _currentPath = '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';

    // Thêm config rõ ràng hơn
    await _recorder!.start(
      RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,           // thêm cái này
        numChannels: 1,
      ),
      path: _currentPath!,
    );
  }

  /// Dừng và trả về path file âm thanh, hoặc null nếu không có gì.
  Future<String?> stopRecording() async {
    final path = await _recorder?.stop();
    await _recorder?.dispose();
    _recorder = null;
    _currentPath = null;
    return path;
  }

  /// Huỷ ghi âm và xoá file tạm nếu tồn tại.
  Future<void> cancelRecording() async {
    await _recorder?.cancel();
    await _recorder?.dispose();
    _recorder = null;

    if (_currentPath != null) {
      try {
        final f = File(_currentPath!);
        if (await f.exists()) await f.delete();
      } catch (_) {
        // Một số platform đã tự xoá file khi cancel() — bỏ qua lỗi
      }
      _currentPath = null;
    }
  }

  Future<bool> get isRecordingAsync async =>
      await _recorder?.isRecording() ?? false;

  Future<void> dispose() async {
    await _recorder?.dispose();
    _recorder = null;
  }
}