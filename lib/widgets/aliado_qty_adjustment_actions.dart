import 'package:flutter/material.dart';

import '../models/transaction_request_model.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';

/// Aliado: aceptar o rechazar propuesta formal de menor cantidad (estado `pendiente`).
class AliadoQtyAdjustmentActions extends StatefulWidget {
  const AliadoQtyAdjustmentActions({
    super.key,
    required this.request,
    required this.onChanged,
  });

  final TransactionRequestModel request;
  final VoidCallback onChanged;

  @override
  State<AliadoQtyAdjustmentActions> createState() =>
      _AliadoQtyAdjustmentActionsState();
}

class _AliadoQtyAdjustmentActionsState extends State<AliadoQtyAdjustmentActions> {
  bool _busy = false;

  Future<void> _respond(bool aceptar) async {
    if (_busy || !widget.request.qtyAdjustmentPendienteAliado) return;
    setState(() => _busy = true);
    try {
      await SupabaseService.aliadoRespondeAjusteCantidad(
        transactionRequestId: widget.request.id,
        aceptar: aceptar,
      );
      widget.onChanged();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo enviar la respuesta: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    if (!r.qtyAdjustmentPendienteAliado) return const SizedBox.shrink();

    final off = r.qtyAdjustmentOffered;
    final snap = r.qtyAdjustmentSolicitadaSnapshot ?? r.cantidad;
    final note = r.qtyAdjustmentNote?.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Propuesta de cantidad del proveedor',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: Colors.amber.shade900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Solicitaste $snap uds; el proveedor ofrece ${off ?? '—'} uds.',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.35,
              color: Colors.grey.shade900,
            ),
          ),
          if (note != null && note.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Nota: $note',
              style: TextStyle(
                fontSize: 12,
                height: 1.35,
                color: Colors.grey.shade800,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy ? null : () => _respond(false),
                  child: Text(_busy ? '…' : 'Rechazar'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brand,
                  ),
                  onPressed: _busy ? null : () => _respond(true),
                  child: Text(_busy ? '…' : 'Aceptar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
