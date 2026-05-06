import 'package:flutter/material.dart';

import '../models/document_type_preference.dart';
import '../models/transaction_request_model.dart';
import '../models/transaction_request_status.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';

/// A6: elección de nota de entrega vs factura fiscal (antes o durante el cierre; obligatorio para pagar con factura MotoLink).
class AliadoDocumentTypePreferenceSection extends StatefulWidget {
  const AliadoDocumentTypePreferenceSection({
    super.key,
    required this.request,
    required this.onChanged,
  });

  final TransactionRequestModel request;
  final VoidCallback onChanged;

  @override
  State<AliadoDocumentTypePreferenceSection> createState() =>
      _AliadoDocumentTypePreferenceSectionState();
}

class _AliadoDocumentTypePreferenceSectionState
    extends State<AliadoDocumentTypePreferenceSection> {
  String? _pending;
  bool _busy = false;

  static const _aplicaStatuses = <String>{
    TransactionRequestStatus.aprobadoAdmin,
    TransactionRequestStatus.enPreparacion,
    TransactionRequestStatus.pedidoListo,
    TransactionRequestStatus.enTransito,
    TransactionRequestStatus.entregado,
  };

  @override
  void didUpdateWidget(covariant AliadoDocumentTypePreferenceSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.request.id != widget.request.id) {
      _pending = null;
    }
  }

  Future<void> _guardar() async {
    final t = _pending;
    if (t == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Elija una de las dos opciones.')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await SupabaseService.aliadoSetDocumentTypePreference(
        transactionRequestId: widget.request.id,
        documentType: t,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Preferencia guardada. El equipo MotoLink fue notificado y podrá emitir su documento oficial.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      widget.onChanged();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    if (!_aplicaStatuses.contains(r.status) ||
        r.status == TransactionRequestStatus.rechazado) {
      return const SizedBox.shrink();
    }
    if (r.canceladoPorAliado) return const SizedBox.shrink();

    final fijada = r.documentTypePreference?.trim();
    final descripcion = fijada != null && fijada.isNotEmpty
        ? DocumentTypePreference.labelEs(fijada)
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '¿Cómo deseas registrar tu compra?',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        if (fijada != null && fijada.isNotEmpty) ...[
          Row(
            children: [
              Icon(Icons.check_circle_outline, size: 18, color: Colors.teal.shade800),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Elegido: $descripcion',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.teal.shade900,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ] else ...[
          const Text(
            'Basta elegir y el sistema procesará el documento según tu preferencia.',
            style: TextStyle(
              fontSize: 11.5,
              height: 1.35,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          RadioListTile<String>(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text('Nota de entrega simple (comprobante de compra y entrega).'),
            value: DocumentTypePreference.notaEntrega,
            groupValue: _pending,
            onChanged: _busy ? null : (v) => setState(() => _pending = v),
          ),
          RadioListTile<String>(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text('Factura fiscal (para trámites y registros contables).'),
            value: DocumentTypePreference.facturaFiscal,
            groupValue: _pending,
            onChanged: _busy ? null : (v) => setState(() => _pending = v),
          ),
          const SizedBox(height: 4),
          FilledButton(
            onPressed: _busy ? null : _guardar,
            child: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Confirmar preferencia'),
          ),
        ],
        const SizedBox(height: 12),
      ],
    );
  }
}
