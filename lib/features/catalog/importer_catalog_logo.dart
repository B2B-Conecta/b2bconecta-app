import 'package:flutter/material.dart';

import 'package:motolink_pro_app/core/data/supabase_service.dart';

/// Logo del importador en tarjetas de catálogo (solo si tiene foto registrada).
class ImporterCatalogLogo extends StatefulWidget {
  const ImporterCatalogLogo({
    super.key,
    required this.storagePath,
    this.size = 18,
  });

  final String? storagePath;
  final double size;

  static final Map<String, String> _urlCache = {};

  @override
  State<ImporterCatalogLogo> createState() => _ImporterCatalogLogoState();
}

class _ImporterCatalogLogoState extends State<ImporterCatalogLogo> {
  String? _url;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant ImporterCatalogLogo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.storagePath != widget.storagePath) {
      _resolve();
    }
  }

  Future<void> _resolve() async {
    final path = widget.storagePath?.trim();
    if (path == null || path.isEmpty) {
      if (mounted) setState(() => _url = null);
      return;
    }

    final cached = ImporterCatalogLogo._urlCache[path];
    if (cached != null) {
      if (mounted) setState(() => _url = cached);
      return;
    }

    try {
      final url = await SupabaseService.createSignedUrlForProfileLogo(path);
      ImporterCatalogLogo._urlCache[path] = url;
      if (mounted) setState(() => _url = url);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final path = widget.storagePath?.trim();
    if (path == null || path.isEmpty || _failed) {
      return const SizedBox.shrink();
    }

    final url = _url;
    if (url == null) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: const Center(
          child: SizedBox(
            width: 10,
            height: 10,
            child: CircularProgressIndicator(strokeWidth: 1.5),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.size * 0.22),
      child: Image.network(
        url,
        width: widget.size,
        height: widget.size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      ),
    );
  }
}
