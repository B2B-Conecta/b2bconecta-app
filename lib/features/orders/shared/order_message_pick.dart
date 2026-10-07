import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import 'order_message_attachment.dart';
import 'order_message_compress.dart';

class PreparedOrderAttachment {
  const PreparedOrderAttachment({
    required this.bytes,
    required this.fileName,
    required this.mime,
    required this.kind,
  });

  final Uint8List bytes;
  final String fileName;
  final String mime;
  final String kind;
}

Future<PreparedOrderAttachment?> prepareOrderChatImage({
  required bool fromCamera,
}) async {
  final picked = await ImagePicker().pickImage(
    source: fromCamera ? ImageSource.camera : ImageSource.gallery,
    imageQuality: 80,
    maxWidth: 1920,
  );
  if (picked == null) return null;

  var bytes = await picked.readAsBytes();
  if (bytes.isEmpty) {
    throw OrderMessageLimitException('No se pudo leer la foto.');
  }
  var ext = _extensionOf(picked.name);
  final mime = picked.mimeType?.toLowerCase() ?? '';
  if (!OrderMessageLimits.imageExtensions.contains(ext)) {
    ext = switch (mime) {
      'image/png' => 'png',
      'image/webp' => 'webp',
      'image/jpeg' || 'image/jpg' => 'jpeg',
      _ => '',
    };
  }
  if (!OrderMessageLimits.imageExtensions.contains(ext)) {
    throw OrderMessageLimitException('Usa una foto JPG, PNG o WEBP.');
  }

  final compressed = await compressOrderImageBytes(bytes);
  if (compressed != null) {
    bytes = compressed;
    ext = 'jpeg';
  }
  if (bytes.length > OrderMessageLimits.maxImageBytes) {
    throw OrderMessageLimitException(
      'La foto supera 8 MB después de comprimirla.',
    );
  }
  final outMime = switch (ext) {
    'png' => 'image/png',
    'webp' => 'image/webp',
    _ => 'image/jpeg',
  };
  return PreparedOrderAttachment(
    bytes: bytes,
    fileName: 'foto.$ext',
    mime: outMime,
    kind: 'image',
  );
}

Future<PreparedOrderAttachment?> prepareOrderChatVideo({
  required bool fromCamera,
}) async {
  final picked = await ImagePicker().pickVideo(
    source: fromCamera ? ImageSource.camera : ImageSource.gallery,
    maxDuration: OrderMessageLimits.maxVideoDuration,
  );
  if (picked == null) return null;

  final path = picked.path;
  final canUseFile = !kIsWeb &&
      path.isNotEmpty &&
      !path.startsWith('blob:') &&
      !path.startsWith('http');

  Uint8List bytes;
  var mime = 'video/mp4';
  var fileName = 'video.mp4';

  if (canUseFile) {
    final probedMs = await probeOrderVideoDurationMs(path);
    if (probedMs != null &&
        probedMs > OrderMessageLimits.maxVideoDuration.inMilliseconds) {
      throw OrderMessageLimitException(
        'El video no puede durar más de 60 segundos.',
      );
    }
    final compressed = await compressOrderVideoFile(path);
    if (compressed != null) {
      if (compressed.durationMs != null &&
          compressed.durationMs! >
              OrderMessageLimits.maxVideoDuration.inMilliseconds) {
        throw OrderMessageLimitException(
          'El video no puede durar más de 60 segundos.',
        );
      }
      bytes = compressed.bytes;
    } else {
      bytes = await picked.readAsBytes();
      final native = _videoMime(picked);
      mime = native.mime;
      fileName = native.fileName;
    }
  } else {
    bytes = await picked.readAsBytes();
    final native = _videoMime(picked);
    mime = native.mime;
    fileName = native.fileName;
  }

  if (bytes.isEmpty) {
    throw OrderMessageLimitException('No se pudo leer el video.');
  }
  if (bytes.length > OrderMessageLimits.maxVideoBytes) {
    throw OrderMessageLimitException('El video supera 50 MB.');
  }
  return PreparedOrderAttachment(
    bytes: bytes,
    fileName: fileName,
    mime: mime,
    kind: 'video',
  );
}

({String mime, String fileName}) _videoMime(XFile picked) {
  final ext = _extensionOf(picked.name);
  final mime = picked.mimeType?.toLowerCase() ?? '';
  if (ext == 'mov' || mime == 'video/quicktime') {
    return (mime: 'video/quicktime', fileName: 'video.mov');
  }
  if (ext == 'mp4' || mime == 'video/mp4') {
    return (mime: 'video/mp4', fileName: 'video.mp4');
  }
  throw OrderMessageLimitException('Usa un video MP4.');
}

String _extensionOf(String name) {
  final dot = name.lastIndexOf('.');
  if (dot < 0 || dot == name.length - 1) return '';
  var ext = name.substring(dot + 1).toLowerCase();
  if (ext == 'jpg') ext = 'jpeg';
  return ext;
}
