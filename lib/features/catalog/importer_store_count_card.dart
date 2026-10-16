import 'dart:async';

import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';

/// Conteo fijo de tiendas activas. No es el aviso del día: ese se cierra con
/// «Entendido». En escritorio va en el rail; en móvil, dentro de Inventario.
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
    final count = _count;
    if (!_ready || count == null) return const SizedBox.shrink();
    final label = count == 1 ? 'tienda activa' : 'tiendas activas';
    final tooltip = 'Hay $count $label en la app';

    if (!widget.extended && !widget.inline) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        child: Tooltip(
          message: tooltip,
          child: Material(
            color: AppColors.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: AppColors.borderSubtle),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  const _StoreCountIcon(size: 22),
                  const SizedBox(height: 4),
                  Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
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
          color: AppColors.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: AppColors.borderSubtle),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                const _StoreCountIcon(),
                const SizedBox(width: 8),
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
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
                      color: AppColors.textSecondary,
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
  const _StoreCountIcon({this.size = 28});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.successGreen.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.storefront_outlined,
        size: size * 0.57,
        color: AppColors.successGreen,
      ),
    );
  }
}
