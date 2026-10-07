/// Límites de adjuntos del chat de un pedido.
///
/// Fotos: jpg, jpeg, png o webp, hasta 8 MB ya comprimidas, máximo 3 por mensaje.
/// Videos: mp4 (mov solo si no se pudo convertir), hasta 50 MB y 60 segundos, 1 por mensaje.
/// En el teléfono la foto se comprime a JPEG (lado 1920, calidad 80) y el video a MP4 medio.
/// En la web se respeta el tamaño; la duración del video de galería no se mide.
abstract final class OrderMessageLimits {
  static const maxImagesPerMessage = 3;
  static const maxImageBytes = 8 * 1024 * 1024;
  static const maxVideoBytes = 50 * 1024 * 1024;
  static const maxVideoDuration = Duration(seconds: 60);
  static const imageExtensions = {'jpg', 'jpeg', 'png', 'webp'};
  static const videoExtensions = {'mp4', 'mov'};
}

class OrderMessageLimitException implements Exception {
  OrderMessageLimitException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Archivo guardado en el bucket privado `order-message-attachments`.
class OrderMessageAttachment {
  const OrderMessageAttachment({
    required this.path,
    required this.kind,
    required this.mime,
    required this.name,
  });

  final String path;
  final String kind;
  final String mime;
  final String name;

  bool get isImage => kind == 'image';
  bool get isVideo => kind == 'video';

  Map<String, dynamic> toJson() => {
        'path': path,
        'kind': kind,
        'mime': mime,
        'name': name,
      };

  static OrderMessageAttachment? tryParse(dynamic raw) {
    if (raw is! Map) return null;
    final path = raw['path']?.toString().trim() ?? '';
    final kind = raw['kind']?.toString().trim() ?? '';
    if (path.isEmpty || (kind != 'image' && kind != 'video')) return null;
    if (path.contains('..')) return null;
    return OrderMessageAttachment(
      path: path,
      kind: kind,
      mime: raw['mime']?.toString().trim() ?? '',
      name: raw['name']?.toString().trim() ?? '',
    );
  }
}

List<OrderMessageAttachment> parseOrderMessageAttachments(dynamic raw) {
  if (raw is! List) return const [];
  return raw.map(OrderMessageAttachment.tryParse).whereType<OrderMessageAttachment>().toList();
}
