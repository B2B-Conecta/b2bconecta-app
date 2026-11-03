import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'package:motolink_pro_app/core/utils/ves_amount_format.dart';
import 'package:motolink_pro_app/features/orders/shared/orders_service.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_model.dart';

/// Botón admin: una sola vez, reaplica la tasa BCV vigente al Bs congelado.
class AdminRecalcTasaBcvButton extends StatefulWidget {
  const AdminRecalcTasaBcvButton({
    super.key,
    required this.lines,
    this.onDone,
  });

  final List<TransactionRequestModel> lines;
  final VoidCallback? onDone;

  @override
  State<AdminRecalcTasaBcvButton> createState() =>
      _AdminRecalcTasaBcvButtonState();
}

class _AdminRecalcTasaBcvButtonState extends State<AdminRecalcTasaBcvButton> {
  double? _liveTasa;
  bool _loadingRate = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadLiveRate();
  }

  @override
  void didUpdateWidget(covariant AdminRecalcTasaBcvButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lines.map((e) => e.id).join() !=
        widget.lines.map((e) => e.id).join()) {
      _loadLiveRate();
    }
  }

  Future<void> _loadLiveRate() async {
    setState(() => _loadingRate = true);
    final rate = await SupabaseService.fetchGlobalTasaBcv();
    if (!mounted) return;
    setState(() {
      _liveTasa = rate;
      _loadingRate = false;
    });
  }

  bool get _alreadyUsed =>
      widget.lines.any((l) => !l.tasaBcvRecalcDisponible);

  bool get _stale =>
      widget.lines.any((l) => l.tasaBcvDesactualizadaRespecto(_liveTasa));

  bool get _hasFrozenBs =>
      widget.lines.any((l) => l.totalBs != null || l.tasaBcvAplicada != null);

  double get _oldBs => widget.lines.fold<double>(
        0,
        (sum, l) => sum + (l.precioTotalBsUi ?? 0),
      );

  double? get _newBs {
    final tasa = _liveTasa;
    if (tasa == null || tasa <= 0) return null;
    return widget.lines.fold<double>(0, (sum, l) {
      final ref = l.totalRef ?? l.precioTotal;
      return sum + ref * tasa;
    });
  }

  double? get _frozenTasa {
    for (final l in widget.lines) {
      if (l.tasaBcvAplicada != null && l.tasaBcvAplicada! > 0) {
        return l.tasaBcvAplicada;
      }
    }
    return null;
  }

  Future<void> _confirmAndRun() async {
    final live = _liveTasa;
    final oldTasa = _frozenTasa;
    final projected = _newBs;
    if (live == null || projected == null || widget.lines.isEmpty) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Actualizar bolívares del pedido'),
        content: Text(
          'Se reaplicará la tasa BCV vigente una sola vez.\n\n'
          'Tasa congelada: ${oldTasa == null ? '—' : formatVesAmount(oldTasa, fractionDigits: 4)}\n'
          'Tasa vigente: ${formatVesAmount(live, fractionDigits: 4)}\n\n'
          'Bs actuales: ${formatBsLabel(_oldBs)}\n'
          'Bs nuevos: ${formatBsLabel(projected)}\n\n'
          'Esta acción no se puede repetir en este pedido.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Actualizar una vez'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await OrdersService.adminRecalcPedidoTasaBcv(
        transactionRequestId: widget.lines.first.id,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Bolívares actualizados a ${formatBsLabel(projected)}.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      widget.onDone?.call();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasFrozenBs) return const SizedBox.shrink();
    if (_loadingRate) return const SizedBox.shrink();

    if (_alreadyUsed) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          'La tasa BCV de este pedido ya fue actualizada una vez por administración.',
          style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
        ),
      );
    }

    if (!_stale || _liveTasa == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppColors.brandBlueContainer.withOpacity(0.55),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'La tasa congelada difiere de la vigente. '
                'Puede actualizar los bolívares de este pedido una sola vez.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.tonalIcon(
                  onPressed: _busy ? null : _confirmAndRun,
                  icon: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.currency_exchange, size: 18),
                  label: Text(
                    _busy ? 'Actualizando…' : 'Actualizar Bs con tasa vigente',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
