import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Archivo elegido por cámara, galería o selector de documentos.
class PickedDocumentBytes {
  const PickedDocumentBytes({
    required this.bytes,
    required this.fileName,
  });

  final Uint8List bytes;
  final String fileName;
}

enum DocumentPickChannel { camera, gallery, file }

Future<PickedDocumentBytes?> pickKycDocument({
  DocumentPickChannel channel = DocumentPickChannel.file,
}) {
  switch (channel) {
    case DocumentPickChannel.camera:
      return pickKycDocumentFromCamera();
    case DocumentPickChannel.gallery:
      return pickKycDocumentFromGallery();
    case DocumentPickChannel.file:
      return pickKycDocumentFromFile();
  }
}

Future<PickedDocumentBytes?> pickKycDocumentFromCamera() => _pickFromCamera();

Future<PickedDocumentBytes?> pickKycDocumentFromGallery() => _pickFromGallery();

Future<PickedDocumentBytes?> pickKycDocumentFromFile() => _pickFromFiles();

/// Muestra cámara / galería / archivo y devuelve bytes listos para subir.
Future<PickedDocumentBytes?> pickKycDocumentBytes(BuildContext context) async {
  final source = await showModalBottomSheet<DocumentPickChannel>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              'Agregar documento',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
          ),
          if (!kIsWeb)
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Tomar foto'),
              subtitle: const Text('Usar la cámara del dispositivo'),
              onTap: () => Navigator.of(ctx).pop(DocumentPickChannel.camera),
            ),
          if (!kIsWeb)
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Elegir de galería'),
              subtitle: const Text('Imagen JPG o PNG'),
              onTap: () => Navigator.of(ctx).pop(DocumentPickChannel.gallery),
            ),
          ListTile(
            leading: const Icon(Icons.upload_file_outlined),
            title: const Text('Subir archivo'),
            subtitle: const Text('PDF, JPG, PNG o WEBP'),
            onTap: () => Navigator.of(ctx).pop(DocumentPickChannel.file),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );

  if (source == null) return null;

  switch (source) {
    case DocumentPickChannel.camera:
      return _pickFromCamera();
    case DocumentPickChannel.gallery:
      return _pickFromGallery();
    case DocumentPickChannel.file:
      return _pickFromFiles();
  }
}

/// Solo imágenes (logo de perfil): cámara, galería o archivo.
Future<PickedDocumentBytes?> pickProfileImageBytes(BuildContext context) async {
  final source = await showModalBottomSheet<DocumentPickChannel>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              'Agregar imagen',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
          ),
          if (!kIsWeb)
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Tomar foto'),
              onTap: () => Navigator.of(ctx).pop(DocumentPickChannel.camera),
            ),
          if (!kIsWeb)
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Elegir de galería'),
              onTap: () => Navigator.of(ctx).pop(DocumentPickChannel.gallery),
            ),
          ListTile(
            leading: const Icon(Icons.upload_file_outlined),
            title: const Text('Subir archivo'),
            onTap: () => Navigator.of(ctx).pop(DocumentPickChannel.file),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );

  if (source == null) return null;

  switch (source) {
    case DocumentPickChannel.camera:
      return _pickFromCamera();
    case DocumentPickChannel.gallery:
      return _pickFromGallery();
    case DocumentPickChannel.file:
      return _pickImageFromFiles();
  }
}

Future<PickedDocumentBytes?> _pickFromCamera() async {
  try {
    final x = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 2400,
    );
    return _fromXFile(x, fallbackBaseName: 'foto_camara');
  } catch (_) {
    return null;
  }
}

Future<PickedDocumentBytes?> _pickFromGallery() async {
  try {
    final x = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
      maxWidth: 2400,
    );
    return _fromXFile(x, fallbackBaseName: 'foto_galeria');
  } catch (_) {
    return null;
  }
}

Future<PickedDocumentBytes?> _pickFromFiles() async {
  final res = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
    withData: true,
  );
  if (res == null || res.files.isEmpty) return null;
  final f = res.files.first;
  final bytes = f.bytes;
  if (bytes == null || bytes.isEmpty) return null;
  final name = f.name.trim().isEmpty ? 'documento.pdf' : f.name;
  return PickedDocumentBytes(bytes: bytes, fileName: name);
}

Future<PickedDocumentBytes?> _pickImageFromFiles() async {
  final res = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp'],
    withData: true,
  );
  if (res == null || res.files.isEmpty) return null;
  final f = res.files.first;
  final bytes = f.bytes;
  if (bytes == null || bytes.isEmpty) return null;
  final name = f.name.trim().isEmpty ? 'imagen.png' : f.name;
  return PickedDocumentBytes(bytes: bytes, fileName: name);
}

Future<PickedDocumentBytes?> _fromXFile(
  XFile? x, {
  required String fallbackBaseName,
}) async {
  if (x == null) return null;
  final bytes = await x.readAsBytes();
  if (bytes.isEmpty) return null;

  var name = x.name.trim();
  if (name.isEmpty) {
    final ext = _extensionFromPath(x.path) ?? 'jpg';
    name = '${fallbackBaseName}_${DateTime.now().millisecondsSinceEpoch}.$ext';
  }
  return PickedDocumentBytes(bytes: bytes, fileName: name);
}

String? _extensionFromPath(String path) {
  final dot = path.lastIndexOf('.');
  if (dot < 0 || dot >= path.length - 1) return null;
  return path.substring(dot + 1).toLowerCase();
}
