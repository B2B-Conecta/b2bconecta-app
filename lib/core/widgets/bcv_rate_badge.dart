import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'package:motolink_pro_app/core/utils/app_date_format.dart';
import 'package:motolink_pro_app/core/utils/bcv_base_price.dart';
import 'package:motolink_pro_app/core/utils/ves_amount_format.dart';
import 'header_icon_button.dart';

/// Etiqueta relativa de última actualización de la tasa BCV.
String formatBcvRateUpdatedLabel(DateTime updatedAt, {DateTime? now}) {
  final local = updatedAt.toLocal();
  final clock = (now ?? DateTime.now()).toLocal();
  final today = DateTime(clock.year, clock.month, clock.day);
  final day = DateTime(local.year, local.month, local.day);
  final time = _formatTime12h(local);
  if (day == today) return 'Actualizado hoy a las $time';
  if (day == today.subtract(const Duration(days: 1))) {
    return 'Actualizado ayer a las $time';
  }
  return 'Actualizado el ${formatEsShortDate(local)} a las $time';
}

String _formatTime12h(DateTime d) {
  final h24 = d.hour;
  final period = h24 >= 12 ? 'PM' : 'AM';
  final h12 = h24 % 12 == 0 ? 12 : h24 % 12;
  final min = d.minute.toString().padLeft(2, '0');
  return '$h12:$min $period';
}

/// Icono de tasa BCV en la barra superior; al tocarlo muestra el detalle.
class BcvRateBadge extends StatefulWidget {
  const BcvRateBadge(
      {super.key,
      this.iconColor,
      this.icon = Icons.currency_exchange,
      this.iconWidget,
      this.alwaysVisible = false,
      this.size = HeaderIconButton.slot});

  final Color? iconColor;
  final IconData icon;
  final Widget? iconWidget;
  final bool alwaysVisible;
  final Size size;

  @override
  State<BcvRateBadge> createState() => _BcvRateBadgeState();
}

class _BcvRateBadgeState extends State<BcvRateBadge>
    with WidgetsBindingObserver {
  double? _tasa;
  DateTime? _updatedAt;
  String? _effectiveDate;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _load(force: true);
    }
  }

  Future<void> _load({bool force = false}) async {
    try {
      if (force) BcvBasePrice.invalidate();
      final rec = await SupabaseService.fetchGlobalTasaBcvRecord();
      if (rec != null && rec.tasa > 0) {
        await BcvBasePrice.refresh(force: true);
      }
      if (!mounted) return;
      setState(() {
        _tasa = rec?.tasa ?? BcvBasePrice.cachedRate;
        _updatedAt = rec?.updatedAt ?? BcvBasePrice.cachedUpdatedAt;
        _effectiveDate = rec?.effectiveDate ?? BcvBasePrice.cachedEffectiveDate;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _openDetails() async {
    await _load(force: true);
    if (!mounted) return;
    final tasa = _tasa;
    if (tasa == null || tasa <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay tasa BCV vigente.')),
      );
      return;
    }
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 720) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Tasa BCV'),
          content: _BcvRateDetails(
            tasa: tasa,
            updatedAt: _updatedAt,
            effectiveDate: _effectiveDate,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    } else {
      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: _BcvRateDetails(
              tasa: tasa,
              updatedAt: _updatedAt,
              effectiveDate: _effectiveDate,
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tasa = _tasa;
    if (!widget.alwaysVisible && _loading && (tasa == null || tasa <= 0)) {
      return SizedBox.fromSize(size: HeaderIconButton.slot);
    }
    if (!widget.alwaysVisible && (tasa == null || tasa <= 0)) {
      return const SizedBox.shrink();
    }

    final tip = tasa != null && tasa > 0
        ? 'BCV ${formatBsLabel(tasa)} · Ver detalle'
        : 'Consultar tasa BCV';
    return HeaderIconButton(
      tooltip: tip,
      onPressed: _openDetails,
      icon: widget.icon,
      iconWidget: widget.iconWidget,
      iconColor: widget.iconColor,
      size: widget.size,
    );
  }
}

class _BcvRateDetails extends StatelessWidget {
  const _BcvRateDetails({
    required this.tasa,
    this.updatedAt,
    this.effectiveDate,
  });

  final double tasa;
  final DateTime? updatedAt;
  final String? effectiveDate;

  @override
  Widget build(BuildContext context) {
    final updated = updatedAt;
    final vigencia = effectiveDate?.trim();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tasa oficial',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '1 USD / REF = ${formatBsLabel(tasa, fractionDigits: 4)}',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.brand,
          ),
        ),
        if (updated != null) ...[
          const SizedBox(height: 10),
          Text(
            formatBcvRateUpdatedLabel(updated),
            style: TextStyle(
              fontSize: 12.5,
              height: 1.35,
              color: AppColors.textSecondary,
            ),
          ),
        ],
        if (vigencia != null && vigencia.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            'Fecha valor BCV: $vigencia',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
        const SizedBox(height: 8),
        Text(
          'Los pedidos en bolívares usan esta tasa al confirmar. '
          'Los pedidos ya confirmados conservan la tasa congelada.',
          style: TextStyle(
            fontSize: 12,
            height: 1.35,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
