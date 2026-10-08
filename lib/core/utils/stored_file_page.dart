import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/app_theme.dart';

import 'stored_file_actions.dart';
import 'stored_file_frame.dart';
import 'stored_file_name.dart';

/// Abre factura o comprobante dentro de la app.
///
/// En el navegador del teléfono, abrir el enlace justo después de firmarlo
/// queda bloqueado. Esta pantalla espera el enlace y deja ver o descargar
/// en un toque nuevo.
Future<void> openStoredFile(
  BuildContext context, {
  required Future<String> Function() signedUrl,
  String? fileName,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => StoredFilePage(
        loadUrl: signedUrl,
        fileName: fileName,
      ),
    ),
  );
}

class StoredFilePage extends StatefulWidget {
  const StoredFilePage({
    super.key,
    required this.loadUrl,
    this.fileName,
  });

  final Future<String> Function() loadUrl;
  final String? fileName;

  @override
  State<StoredFilePage> createState() => _StoredFilePageState();
}

class _StoredFilePageState extends State<StoredFilePage> {
  String? _url;
  Object? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final url = await widget.loadUrl();
      if (!mounted) return;
      setState(() => _url = url);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  String get _title {
    final url = _url;
    final given = widget.fileName?.trim();
    if (url == null) {
      return (given != null && given.isNotEmpty) ? given : 'Archivo';
    }
    return storedFileDisplayName(widget.fileName, url);
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (!mounted) return;
      final text = e.toString().contains('cancelada')
          ? 'Descarga cancelada.'
          : 'No se pudo completar: $e';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = _url;
    final isImage = url != null && storedFileIsImage(_title, url);
    final frame = url == null || isImage ? null : buildStoredFileFrame(url);

    return Scaffold(
      backgroundColor: isImage ? Colors.black : AppColors.background,
      appBar: AppBar(
        title: Text(
          _title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Column(
        children: [
          Expanded(child: _body(url, isImage, frame)),
          if (url != null)
            Material(
              color: AppColors.card,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!isImage) ...[
                        FilledButton.icon(
                          onPressed: _busy
                              ? null
                              : () => _run(() => openStoredFileExternally(url)),
                          icon: const Icon(Icons.open_in_new),
                          label: const Text('Ver archivo'),
                        ),
                        const SizedBox(height: 8),
                      ],
                      isImage
                          ? FilledButton.icon(
                              onPressed: _busy
                                  ? null
                                  : () => _run(
                                        () => downloadStoredFile(url, _title),
                                      ),
                              icon: const Icon(Icons.download_outlined),
                              label: const Text('Descargar'),
                            )
                          : OutlinedButton.icon(
                              onPressed: _busy
                                  ? null
                                  : () => _run(
                                        () => downloadStoredFile(url, _title),
                                      ),
                              icon: const Icon(Icons.download_outlined),
                              label: const Text('Descargar'),
                            ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _body(String? url, bool isImage, Widget? frame) {
    if (_error != null) {
      return _message(
        icon: Icons.error_outline,
        text: 'No se pudo preparar el archivo.',
      );
    }
    if (url == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (isImage) {
      return InteractiveViewer(
        minScale: 1,
        maxScale: 4,
        child: Center(
          child: Image.network(
            url,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return const Center(
                child: CircularProgressIndicator(color: Colors.white),
              );
            },
            errorBuilder: (context, error, stack) => _message(
              icon: Icons.broken_image_outlined,
              text: 'No se pudo mostrar la imagen. Use Descargar.',
              onDark: true,
            ),
          ),
        ),
      );
    }
    if (frame != null) {
      return frame;
    }
    return _message(
      icon: Icons.description_outlined,
      text: 'Use Ver archivo para abrirlo. Desde ahí también puede guardarlo.',
    );
  }

  Widget _message({
    required IconData icon,
    required String text,
    bool onDark = false,
  }) {
    final color = onDark ? Colors.white70 : AppColors.textSecondary;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(color: color, height: 1.35),
            ),
          ],
        ),
      ),
    );
  }
}
