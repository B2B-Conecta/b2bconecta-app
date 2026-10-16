import 'dart:typed_data';

/// Qué contenido acepta un punto de subida.
enum UploadKind {
  /// JPG, PNG o WEBP (fotos de producto, logos, campañas).
  image,

  /// JPG, PNG, WEBP o PDF (KYC, comprobantes, facturas).
  imageOrPdf,
}

class UploadRejectedException implements Exception {
  UploadRejectedException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Archivo ya validado, con la extensión alineada al contenido real.
class CheckedUpload {
  const CheckedUpload({
    required this.bytes,
    required this.fileName,
    required this.mime,
    required this.extension,
  });

  final Uint8List bytes;
  final String fileName;
  final String mime;
  final String extension;
}

/// Validación previa a la subida: tamaño y tipo por firma de bytes.
///
/// La extensión del nombre no basta (se puede renombrar cualquier archivo);
/// el tipo se decide por los primeros bytes y el nombre se corrige a ese tipo.
abstract final class UploadFileGuard {
  static const int maxBytes = 8 * 1024 * 1024;

  static const _imageMimes = {'image/jpeg', 'image/png', 'image/webp'};

  /// MIME según la firma del archivo, o null si no es un tipo admitido.
  static String? sniffMime(Uint8List b) {
    if (b.length >= 3 && b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF) {
      return 'image/jpeg';
    }
    if (b.length >= 8 &&
        b[0] == 0x89 &&
        b[1] == 0x50 &&
        b[2] == 0x4E &&
        b[3] == 0x47 &&
        b[4] == 0x0D &&
        b[5] == 0x0A &&
        b[6] == 0x1A &&
        b[7] == 0x0A) {
      return 'image/png';
    }
    if (b.length >= 12 &&
        b[0] == 0x52 && // R
        b[1] == 0x49 && // I
        b[2] == 0x46 && // F
        b[3] == 0x46 && // F
        b[8] == 0x57 && // W
        b[9] == 0x45 && // E
        b[10] == 0x42 && // B
        b[11] == 0x50) {
      // P
      return 'image/webp';
    }
    if (b.length >= 5 &&
        b[0] == 0x25 && // %
        b[1] == 0x50 && // P
        b[2] == 0x44 && // D
        b[3] == 0x46 && // F
        b[4] == 0x2D) {
      // -
      return 'application/pdf';
    }
    return null;
  }

  static String extensionForMime(String mime) => switch (mime) {
        'image/png' => 'png',
        'image/webp' => 'webp',
        'application/pdf' => 'pdf',
        _ => 'jpg',
      };

  /// Lanza [UploadRejectedException] con un mensaje listo para el usuario.
  static CheckedUpload check(
    Uint8List bytes,
    String fileName, {
    required UploadKind kind,
    int maxBytes = UploadFileGuard.maxBytes,
  }) {
    if (bytes.isEmpty) {
      throw UploadRejectedException('El archivo está vacío.');
    }
    if (bytes.length > maxBytes) {
      final mb = (maxBytes / (1024 * 1024)).round();
      throw UploadRejectedException('El archivo supera $mb MB.');
    }
    final mime = sniffMime(bytes);
    final allowed = switch (kind) {
      UploadKind.image => mime != null && _imageMimes.contains(mime),
      UploadKind.imageOrPdf => mime != null,
    };
    if (!allowed) {
      throw UploadRejectedException(
        kind == UploadKind.image
            ? 'Formato no admitido. Use una imagen JPG, PNG o WEBP.'
            : 'Formato no admitido. Use PDF, JPG, PNG o WEBP.',
      );
    }
    final ext = extensionForMime(mime!);
    return CheckedUpload(
      bytes: bytes,
      fileName: _withExtension(fileName, ext),
      mime: mime,
      extension: ext,
    );
  }

  static String _withExtension(String name, String ext) {
    final trimmed = name.trim().isEmpty ? 'archivo' : name.trim();
    final dot = trimmed.lastIndexOf('.');
    final base = dot > 0 ? trimmed.substring(0, dot) : trimmed;
    final current = dot > 0 ? trimmed.substring(dot + 1).toLowerCase() : '';
    final same = current == ext || (ext == 'jpg' && current == 'jpeg');
    return same ? trimmed : '$base.$ext';
  }
}
