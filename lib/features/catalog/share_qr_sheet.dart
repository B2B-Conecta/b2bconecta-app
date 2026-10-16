import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import 'package:motolink_pro_app/app/theme/app_theme.dart';

/// Pieza gráfica del enlace público: QR, nombre de B2B Conecta y el URL.
Future<void> showShareQrSheet(
  BuildContext context, {
  required String title,
  required String url,
  String? subtitle,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => _ShareQrCard(
      title: title,
      url: url,
      subtitle: subtitle,
    ),
  );
}

class _ShareQrCard extends StatefulWidget {
  const _ShareQrCard({
    required this.title,
    required this.url,
    this.subtitle,
  });

  final String title;
  final String url;
  final String? subtitle;

  @override
  State<_ShareQrCard> createState() => _ShareQrCardState();
}

class _ShareQrCardState extends State<_ShareQrCard> {
  final _boundaryKey = GlobalKey();
  bool _sharingImage = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.url));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Enlace copiado.')),
    );
  }

  Future<void> _shareLink() async {
    final origin = _origin(context);
    try {
      await Share.share(
        '${widget.title}\n${widget.url}\nÁbrelo en B2B Conecta.',
        subject: widget.title,
        sharePositionOrigin: origin,
      );
    } catch (_) {
      await _copy();
    }
  }

  Future<void> _shareImage() async {
    if (_sharingImage) return;
    final origin = _origin(context);
    setState(() => _sharingImage = true);
    try {
      final boundary = _boundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        throw StateError('qr');
      }
      final image = await boundary.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw StateError('png');
      await Share.shareXFiles(
        [
          XFile.fromData(
            data.buffer.asUint8List(),
            mimeType: 'image/png',
            name: 'b2b-conecta-qr.png',
          ),
        ],
        text: widget.url,
        sharePositionOrigin: origin,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo compartir la imagen. El enlace sigue disponible para copiarlo.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sharingImage = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = widget.subtitle?.trim();
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.borderSubtle,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              'Compartir QR',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            if (subtitle != null && subtitle.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
            const SizedBox(height: 16),
            RepaintBoundary(
              key: _boundaryKey,
              child: ColoredBox(
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      QrImageView(
                        data: widget.url,
                        version: QrVersions.auto,
                        size: 220,
                        backgroundColor: Colors.white,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: AppColors.brandBlue,
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: AppColors.brandBlue,
                        ),
                        embeddedImage: const AssetImage(
                          'assets/isotipo-b2b-conecta-blue.png',
                        ),
                        embeddedImageStyle: const QrEmbeddedImageStyle(
                          size: Size(44, 44),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'B2B Conecta',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.brandBlue,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SelectableText(
              widget.url,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _copy,
                  icon: const Icon(Icons.link, size: 18),
                  label: const Text('Copiar enlace'),
                ),
                OutlinedButton.icon(
                  onPressed: _shareLink,
                  icon: const Icon(Icons.ios_share_rounded, size: 18),
                  label: const Text('Compartir enlace'),
                ),
                FilledButton.icon(
                  onPressed: _sharingImage ? null : _shareImage,
                  icon: const Icon(Icons.qr_code_2, size: 18),
                  label: const Text('Compartir imagen'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Rect? _origin(BuildContext context) {
  final box = context.findRenderObject() as RenderBox?;
  if (box == null || !box.hasSize) return null;
  return box.localToGlobal(Offset.zero) & box.size;
}
