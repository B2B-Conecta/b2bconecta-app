import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/utils/ves_amount_format.dart';
import 'package:motolink_pro_app/features/orders/shared/orders_service.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_model.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_status.dart';

/// Proveedor define si el flete va incluido o el monto adicional en USD.
class ImporterOrderShippingSection extends StatefulWidget {
  const ImporterOrderShippingSection({
    super.key,
    required this.lines,
    this.onChanged,
  });

  final List<TransactionRequestModel> lines;
  final VoidCallback? onChanged;

  @override
  State<ImporterOrderShippingSection> createState() =>
      _ImporterOrderShippingSectionState();
}

class _ImporterOrderShippingSectionState
    extends State<ImporterOrderShippingSection> {
  late bool _included;
  final _costCtrl = TextEditingController();
  bool _saving = false;

  TransactionRequestModel get _primary => widget.lines.first;

  bool get _editable {
    final st = _primary.status;
    return st != TransactionRequestStatus.entregado &&
        st != TransactionRequestStatus.rechazado &&
        !_primary.canceladoPorAliado &&
        !_primary.canceladoPorImportador &&
        !_primary.anuladoPorMotolink;
  }

  @override
  void initState() {
    super.initState();
    _syncFromLines();
  }

  @override
  void didUpdateWidget(covariant ImporterOrderShippingSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lines.first.id != _primary.id ||
        oldWidget.lines.first.shippingIncluded != _primary.shippingIncluded ||
        oldWidget.lines.first.shippingCostUsd != _primary.shippingCostUsd) {
      _syncFromLines();
    }
  }

  void _syncFromLines() {
    _included = _primary.shippingIncluded ?? true;
    final cost = _primary.shippingCostUsd;
    _costCtrl.text =
        (!_included && cost != null) ? formatRefAmount(cost) : '';
  }

  @override
  void dispose() {
    _costCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_editable) return;
    double? cost;
    if (!_included) {
      cost = parseVesOrEnDecimal(_costCtrl.text);
      if (cost == null || cost < 0) {
        _snack('Indique el costo de envío en USD (0 o mayor).');
        return;
      }
    }
    setState(() => _saving = true);
    try {
      await OrdersService.importerSetOrderShipping(
        requestIds: widget.lines.map((l) => l.id).toList(),
        shippingIncluded: _included,
        shippingCostUsd: cost,
      );
      if (!mounted) return;
      _snack(_included
          ? 'Flete marcado como incluido.'
          : 'Costo de envío guardado.');
      widget.onChanged?.call();
    } catch (e) {
      if (mounted) _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final rate = _primary.tasaBcvAplicada;
    final previewUsd = !_included ? parseVesOrEnDecimal(_costCtrl.text) : null;
    final previewBs =
        (previewUsd != null && rate != null && rate > 0) ? previewUsd * rate : null;

    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.local_shipping_outlined,
                    size: 20, color: AppColors.brandLink),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Costo de envío',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Defina si el flete va incluido o el monto adicional en divisas. '
              'El equivalente en Bs usa la tasa BCV del pedido.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.35,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 10),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(
                _included ? 'Envío incluido' : 'Cobro adicional de flete',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  fontSize: 13.5,
                ),
              ),
              subtitle: Text(
                _included
                    ? 'No se suma monto de flete al pedido.'
                    : 'Indique el precio adicional en USD.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              value: _included,
              onChanged: !_editable || _saving
                  ? null
                  : (v) => setState(() {
                        _included = v;
                        if (v) _costCtrl.clear();
                      }),
            ),
            if (!_included) ...[
              const SizedBox(height: 4),
              TextField(
                controller: _costCtrl,
                enabled: _editable && !_saving,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Costo de envío (USD)',
                  hintText: '0.00',
                  prefixText: '\$ ',
                  isDense: true,
                ),
              ),
              if (previewBs != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Equivale a ${formatBsLabel(previewBs)}'
                  '${rate != null ? ' (BCV ${formatTasaBcvDisplay(rate)})' : ''}',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
            if (_primary.shippingConfigured) ...[
              const SizedBox(height: 8),
              Text(
                _primary.shippingSummaryLabel,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.brandLink,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (_editable) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Guardando…' : 'Guardar flete'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
