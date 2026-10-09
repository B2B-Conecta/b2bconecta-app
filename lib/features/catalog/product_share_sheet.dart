import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';

import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/utils/stored_file_actions.dart';
import 'package:motolink_pro_app/features/catalog/part_model.dart';
import 'package:motolink_pro_app/features/catalog/product_share_link.dart';

/// Compartir enlace, copiarlo, o enviar y descargar la foto por separado.
///
/// [includeDevLink] solo para el administrador: el proveedor comparte producción.
Future<void> showProductShareSheet(
  BuildContext context,
  PartModel part, {
  bool includeDevLink = false,
}) {
  final url = ProductShareLink.urlFor(part.id);
  final devUrl = ProductShareLink.devUrlFor(part.id);
  final name = part.nombre.trim().isEmpty ? 'Producto' : part.nombre.trim();
  final image = part.coverImageUrl?.trim();
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.borderSubtle,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Text(
                  'Compartir producto',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.ios_share_rounded, color: AppColors.brand),
                title: Text(
                  includeDevLink ? 'Compartir enlace real' : 'Compartir enlace',
                ),
                subtitle: Text(
                  includeDevLink
                      ? 'El de la aplicación publicada. Sirve para WhatsApp u otras aplicaciones.'
                      : 'Para enviarlo por WhatsApp u otra aplicación.',
                ),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await _shareText(context, name: name, url: url);
                },
              ),
              ListTile(
                leading: const Icon(Icons.link, color: AppColors.brand),
                title: Text(
                  includeDevLink ? 'Copiar enlace real' : 'Copiar enlace',
                ),
                subtitle: Text(
                  includeDevLink
                      ? 'Este es el principal. Es el que deben abrir los clientes.'
                      : 'Para pegarlo donde quiera enviarlo.',
                ),
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: url));
                  if (ctx.mounted) Navigator.of(ctx).pop();
                  _toast(
                    context,
                    includeDevLink ? 'Enlace real copiado.' : 'Enlace copiado.',
                  );
                },
              ),
              if (includeDevLink)
                ListTile(
                  leading: const Icon(Icons.science_outlined, color: AppColors.brand),
                  title: const Text('Copiar enlace de prueba'),
                  subtitle: const Text(
                    'Solo para revisar en el sitio de pruebas. No se lo envíe a un cliente.',
                  ),
                  onTap: () async {
                    await Clipboard.setData(ClipboardData(text: devUrl));
                    if (ctx.mounted) Navigator.of(ctx).pop();
                    _toast(context, 'Enlace de prueba copiado.');
                  },
                ),
              if (image != null && image.isNotEmpty) ...[
                ListTile(
                  leading: const Icon(Icons.image_outlined, color: AppColors.brand),
                  title: const Text('Compartir foto'),
                  subtitle: const Text(
                    'Para historias o estados, que no juntan foto y enlace',
                  ),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    await _shareImage(context, url: image, name: name);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.download_outlined, color: AppColors.brand),
                  title: const Text('Descargar foto'),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    await _downloadImage(context, image);
                  },
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}

Future<void> _shareText(
  BuildContext context, {
  required String name,
  required String url,
}) async {
  final text = '$name\n$url\nÁbrelo en B2B Conecta.';
  final origin = _shareOrigin(context);
  try {
    await Share.share(
      text,
      subject: name,
      sharePositionOrigin: origin,
    );
  } catch (_) {
    await Clipboard.setData(ClipboardData(text: url));
    _toast(context, 'No se pudo abrir el menú. El enlace quedó copiado.');
  }
}

Future<void> _shareImage(
  BuildContext context, {
  required String url,
  required String name,
}) async {
  try {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('image');
    }
    final ext = _imageExt(url);
    final origin = _shareOrigin(context);
    await Share.shareXFiles(
      [
        XFile.fromData(
          response.bodyBytes,
          mimeType: ext == 'png' ? 'image/png' : 'image/jpeg',
          name: 'producto.$ext',
        ),
      ],
      text: name,
      sharePositionOrigin: origin,
    );
  } catch (_) {
    _toast(
      context,
      'No se pudo compartir la foto. Puedes descargarla y subirla a la historia.',
    );
  }
}

Future<void> _downloadImage(BuildContext context, String url) async {
  try {
    await downloadStoredFile(url, 'producto.${_imageExt(url)}');
    _toast(context, 'Foto lista para guardar.');
  } catch (_) {
    _toast(context, 'No se pudo descargar la foto.');
  }
}

String _imageExt(String url) {
  final path = Uri.tryParse(url)?.path.toLowerCase() ?? '';
  if (path.endsWith('.png')) return 'png';
  if (path.endsWith('.webp')) return 'webp';
  return 'jpg';
}

Rect? _shareOrigin(BuildContext context) {
  final box = context.findRenderObject();
  if (box is! RenderBox || !box.hasSize) return null;
  return box.localToGlobal(Offset.zero) & box.size;
}

void _toast(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  messenger?.showSnackBar(
    SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
  );
}
