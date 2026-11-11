import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../constants/env.dart';

/// MultipartRequest tùy chỉnh giúp theo dõi chính xác từng byte gửi lên server (Upload Progress thực tế)
class _UploadProgressMultipartRequest extends http.MultipartRequest {
  final void Function(int bytesSent, int totalBytes)? onUploadProgress;

  _UploadProgressMultipartRequest(
    super.method,
    super.url, {
    this.onUploadProgress,
  });

  @override
  http.ByteStream finalize() {
    final byteStream = super.finalize();
    if (onUploadProgress == null) return byteStream;

    final total = contentLength;
    int bytesSent = 0;
    double lastReportedRatio = -1;

    final transformer = StreamTransformer<List<int>, List<int>>.fromHandlers(
      handleData: (data, sink) {
        bytesSent += data.length;
        if (total > 0) {
          final ratio = (bytesSent / total).clamp(0.0, 1.0);
          // Chỉ bắn sự kiện khi tiến độ tăng tối thiểu 0.4% hoặc đạt 100% để tránh nghẽn luồng UI
          if (ratio - lastReportedRatio >= 0.004 || ratio >= 1.0) {
            lastReportedRatio = ratio;
            onUploadProgress?.call(bytesSent, total);
          }
        }
        sink.add(data);
      },
    );

    return http.ByteStream(byteStream.transform(transformer));
  }
}

class CloudinaryService {
  static final _base =
      'https://api.cloudinary.com/v1_1/${Env.cloudinaryCloudName}';

  /// Dung lượng tối đa cho phép khi đăng tải 1 video lên Cloudinary (100 MB)
  static const int maxVideoSizeMB = 100;
  static const int maxVideoSizeBytes = maxVideoSizeMB * 1024 * 1024;

  /// Upload video với tiến độ byte gửi lên thực tế, trả về secure_url
  Future<String> uploadVideo(
    String filePath, {
    void Function(double progress)? onProgress,
  }) async {
    final file = File(filePath);
    if (!file.existsSync()) {
      throw Exception('Không tìm thấy tệp video để tải lên.');
    }

    final fileLength = file.lengthSync();
    if (fileLength > maxVideoSizeBytes) {
      final sizeMb = (fileLength / (1024 * 1024)).toStringAsFixed(1);
      throw Exception(
        'Dung lượng video ($sizeMb MB) vượt quá giới hạn tối đa cho phép là $maxVideoSizeMB MB.',
      );
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    // Tạo signature (dùng cho signed upload – an toàn hơn)
    final paramsToSign = {
      'timestamp': '$timestamp',
      'folder': 'shareco/videos',
    };

    final signature = _sign(paramsToSign);

    final uri = Uri.parse('$_base/video/upload');
    final request = _UploadProgressMultipartRequest(
      'POST',
      uri,
      onUploadProgress: (sent, total) {
        if (total > 0) {
          onProgress?.call((sent / total).clamp(0.0, 1.0));
        }
      },
    )
      ..fields['api_key'] = Env.cloudinaryApiKey
      ..fields['timestamp'] = '$timestamp'
      ..fields['signature'] = signature
      ..fields['folder'] = 'shareco/videos'
      ..fields['resource_type'] = 'video'
      ..files.add(await http.MultipartFile.fromPath('file', file.path));

    onProgress?.call(0.01);

    final streamedResponse = await request.send();
    final List<int> bytes = [];

    await for (final chunk in streamedResponse.stream) {
      bytes.addAll(chunk);
    }

    onProgress?.call(1.0);

    final responseBody = utf8.decode(bytes);

    if (kDebugMode) {
      dev.log('STATUS: ${streamedResponse.statusCode}', name: 'CLOUDINARY');
      dev.log('RESPONSE: $responseBody', name: 'CLOUDINARY');
    }

    if (streamedResponse.statusCode != 200) {
      throw Exception(
        'Tải video lên máy chủ thất bại (Mã lỗi: ${streamedResponse.statusCode})',
      );
    }

    final json = jsonDecode(responseBody) as Map<String, dynamic>;
    return json['secure_url'] as String;
  }

  /// Upload thumbnail (image)
  Future<String> uploadThumbnail(String filePath) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final paramsToSign = {
      'timestamp': '$timestamp',
      'folder': 'shareco/thumbnails',
    };

    final signature = _sign(paramsToSign);

    final uri = Uri.parse('$_base/image/upload');
    final request = http.MultipartRequest('POST', uri)
      ..fields['api_key'] = Env.cloudinaryApiKey
      ..fields['timestamp'] = '$timestamp'
      ..fields['signature'] = signature
      ..fields['folder'] = 'shareco/thumbnails'
      ..files.add(await http.MultipartFile.fromPath('file', filePath));

    final res = await request.send();
    final body = await res.stream.bytesToString();

    if (res.statusCode != 200) throw Exception('Thumbnail upload failed');

    final json = jsonDecode(body) as Map<String, dynamic>;
    return json['secure_url'] as String;
  }

  String _sign(Map<String, String> params) {
    final sorted = params.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final str =
        sorted.map((e) => '${e.key}=${e.value}').join('&') +
        Env.cloudinaryApiSecret;
    return sha1.convert(utf8.encode(str)).toString();
  }

  /// Upload ảnh chat, trả về secure_url
  Future<String> uploadChatImage(
    String filePath, {
    void Function(double progress)? onProgress,
  }) async {
    final file = File(filePath);
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    final paramsToSign = {
      'timestamp': '$timestamp',
      'folder': 'shareco/chat/images',
    };
    final signature = _sign(paramsToSign);

    final uri = Uri.parse('$_base/image/upload');
    final request = http.MultipartRequest('POST', uri)
      ..fields['api_key'] = Env.cloudinaryApiKey
      ..fields['timestamp'] = '$timestamp'
      ..fields['signature'] = signature
      ..fields['folder'] = 'shareco/chat/images'
      ..files.add(await http.MultipartFile.fromPath('file', file.path));

    final streamedResponse = await request.send();
    final totalBytes = file.lengthSync();
    int received = 0;
    final List<int> bytes = [];

    await for (final chunk in streamedResponse.stream) {
      bytes.addAll(chunk);
      received += chunk.length;
      onProgress?.call(received / totalBytes);
    }

    if (streamedResponse.statusCode != 200) {
      throw Exception(
        'Cloudinary image upload failed: ${streamedResponse.statusCode}',
      );
    }

    final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    return json['secure_url'] as String;
  }

  /// Upload audio (voice message), trả về secure_url
  Future<String> uploadAudio(
      String filePath, {
        void Function(double progress)? onProgress,
      }) async {
    final file = File(filePath);

    if (!await file.exists()) {
      throw Exception('File audio không tồn tại');
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    // ❌ KHÔNG thêm resource_type vào đây
    final paramsToSign = {
      'timestamp': '$timestamp',
      'folder': 'shareco/chat/audio',
    };

    final signature = _sign(paramsToSign);

    final uri = Uri.parse('$_base/video/upload');

    final request = http.MultipartRequest('POST', uri)
      ..fields['api_key'] = Env.cloudinaryApiKey
      ..fields['timestamp'] = '$timestamp'
      ..fields['signature'] = signature
      ..fields['folder'] = 'shareco/chat/audio'
      ..files.add(await http.MultipartFile.fromPath('file', file.path));

    final streamedResponse = await request.send();

    final responseBody = await streamedResponse.stream.bytesToString();

    if (streamedResponse.statusCode != 200) {
      debugPrint('❌ Cloudinary error: ${streamedResponse.statusCode} - $responseBody');
      throw Exception('Upload failed');
    }

    final json = jsonDecode(responseBody) as Map<String, dynamic>;

    return json['secure_url'] as String;
  }
}
