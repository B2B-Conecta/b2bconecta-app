import 'dart:async';

import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';

/// Conteo fijo de tiendas activas. No es el aviso del día: ese se cierra con
/// «Entendido». Se mantiene al pie del menú de escritorio del importador.
class ImporterStoreCountCard extends StatefulWidget {
  const ImporterStoreCountCard({
    super.key,
    required this.extended,
    this.inline = false,
  });

  /// Rail expandido. En el rail colapsado solo se ve el número.
  final bool extended;

  /// Tarjeta de contenido, sin el margen del rail.
  final bool inline;

  @override
  State<ImporterStoreCountCard> createState() => _ImporterStoreCountCardState();
}

class _ImporterStoreCountCardState extends State<ImporterStoreCountCard> {
  int? _count;
  bool _ready = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    _timer = Timer.periodic(const Duration(minutes: 5), (_) {
      unawaited(_load());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final notice = await SupabaseService.fetchImporterDailyStoreNotice();
    if (!mounted) return;
    setState(() {
      _ready = true;
      _count = notice.panelCount;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final count = _count;
    if (!_ready || count == null) return const SizedBox.shrink();
    final label = count == 1 ? 'tienda activa' : 'tiendas activas';
    final tooltip = 'Hay $count $label: tiendas minoristas con '
        'verificación aprobada, cuenta activa y RIF distinto.';

    if (!widget.extended && !widget.inline) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        child: Tooltip(
          message: tooltip,
          child: Material(
            color: theme.surfaceSubtle,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: theme.borderSubtle),
            ),
            child: SizedBox(
              width: 48,
              height: 48,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _StoreCountIcon(size: 18, color: theme.successFg),
                  const SizedBox(height: 2),
                  Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: theme.textPrimary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: widget.inline
          ? EdgeInsets.zero
          : const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: theme.surfaceSubtle,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: theme.borderSubtle),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                _StoreCountIcon(color: theme.successFg),
                const SizedBox(width: 8),
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: theme.textPrimary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: theme.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StoreCountIcon extends StatelessWidget {
  const _StoreCountIcon({this.size = 28, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: LucideIcon(
        LucideGlyph.store,
        size: size * 0.57,
        color: color,
      ),
    );
  }
}
