import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:video_compress/video_compress.dart';

Future<Uint8List?> compressOrderImageBytes(Uint8List bytes) async {
  try {
    final out = await FlutterImageCompress.compressWithList(
      bytes,
      quality: 80,
      minWidth: 1920,
      minHeight: 1920,
      format: CompressFormat.jpeg,
    );
    if (out.isEmpty || out.length >= bytes.length) return null;
    return out;
  } catch (_) {
    return null;
  }
}

Future<int?> probeOrderVideoDurationMs(String path) async {
  try {
    final info = await VideoCompress.getMediaInfo(path);
    final duration = info.duration;
    if (duration == null) return null;
    return duration.round();
  } catch (_) {
    return null;
  }
}

Future<({Uint8List bytes, int? durationMs})?> compressOrderVideoFile(
  String path,
) async {
  try {
    final info = await VideoCompress.compressVideo(
      path,
      quality: VideoQuality.MediumQuality,
      deleteOrigin: false,
      includeAudio: true,
    );
    final file = info?.file;
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) return null;
    final duration = info?.duration;
    return (bytes: bytes, durationMs: duration?.round());
  } catch (_) {
    return null;
  } finally {
    try {
      await VideoCompress.deleteAllCache();
    } catch (_) {}
  }
}
