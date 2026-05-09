import 'package:video_thumbnail/video_thumbnail.dart';

class VideoProcessingService {
  static Future<String?> generateThumbnail(String videoPath) async {
    final thumbnail = await VideoThumbnail.thumbnailFile(
      video: videoPath,
      imageFormat: ImageFormat.JPEG,
      maxWidth: 512,
      quality: 75,
    );

    return thumbnail;
  }
}