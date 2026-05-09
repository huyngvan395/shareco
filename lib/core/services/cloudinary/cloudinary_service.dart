import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../constants/env.dart';

class CloudinaryService {
  static final _base = 'https://api.cloudinary.com/v1_1/${Env.cloudinaryCloudName}';

  /// Upload video, trả về secure_url
  Future<String> uploadVideo(
      String filePath, {
        void Function(double progress)? onProgress,
      }) async {
    final file = File(filePath);
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    // Tạo signature (dùng cho signed upload – an toàn hơn)
    final paramsToSign = {
      'timestamp': '$timestamp',
      'folder': 'shareco/videos',
    };

    final signature = _sign(paramsToSign);

    final uri = Uri.parse('$_base/video/upload');
    final request = http.MultipartRequest('POST', uri)
      ..fields['api_key']   = Env.cloudinaryApiKey
      ..fields['timestamp'] = '$timestamp'
      ..fields['signature'] = signature
      ..fields['folder']    = 'shareco/videos'
      ..fields['resource_type'] = 'video'
      ..files.add(await http.MultipartFile.fromPath('file', file.path));

    // Stream để track progress
    final streamedResponse = await request.send();
    final totalBytes = file.lengthSync();
    int received = 0;
    final List<int> bytes = [];

    await for (final chunk in streamedResponse.stream) {
      bytes.addAll(chunk);
      received += chunk.length;
      onProgress?.call(received / totalBytes);
    }

    final responseBody = utf8.decode(bytes);

    if (kDebugMode) {
      dev.log('STATUS: ${streamedResponse.statusCode}', name: 'CLOUDINARY');
      dev.log('RESPONSE: $responseBody', name: 'CLOUDINARY');
    }

    if (streamedResponse.statusCode != 200) {
      throw Exception('Cloudinary upload failed: ${streamedResponse.statusCode}');
    }

    final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
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
      ..fields['api_key']   = Env.cloudinaryApiKey
      ..fields['timestamp'] = '$timestamp'
      ..fields['signature'] = signature
      ..fields['folder']    = 'shareco/thumbnails'
      ..files.add(await http.MultipartFile.fromPath('file', filePath));

    final res = await request.send();
    final body = await res.stream.bytesToString();

    if (res.statusCode != 200) throw Exception('Thumbnail upload failed');

    final json = jsonDecode(body) as Map<String, dynamic>;
    return json['secure_url'] as String;
  }

  String _sign(Map<String, String> params) {
    final sorted = params.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    final str = sorted.map((e) => '${e.key}=${e.value}').join('&') + Env.cloudinaryApiSecret;
    return sha1.convert(utf8.encode(str)).toString();
  }
}