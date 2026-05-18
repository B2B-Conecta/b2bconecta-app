import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/transaction_request_model.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_date_format.dart';

/// Factura que adjunta el importador; el aliado la revisa antes de pagar.
class AliadoImportadorFacturaSection extends StatelessWidget {
  const AliadoImportadorFacturaSection({
    super.key,
    required this.lines,
    this.compact = false,
  });

  final List<TransactionRequestModel> lines;
  final bool compact;

  TransactionRequestModel? get _ref {
    for (final r in lines) {
      if (r.hasProveedorFactura) return r;
    }
    return null;
  }

  Future<void> _abrir(BuildContext context, String path) async {
    try {
      final url = await SupabaseService.createSignedUrlForFacturaAliado(path);
      final uri = Uri.parse(url);
      if (!context.mounted) return;
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo abrir la factura: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _ref;
    if (r == null) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(compact ? 10 : 12, compact ? 8 : 10, 12, 10),
        decoration: BoxDecoration(
          color: Colors.amber.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.amber.shade300),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.receipt_long_outlined, size: 20, color: Colors.amber.shade900),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'El importador aún no adjunta su factura. Cuando la suba, podrá '
                'registrar aquí el pago correspondiente a este proveedor.',
                style: TextStyle(
                  fontSize: compact ? 11 : 11.5,
                  height: 1.35,
                  color: Colors.amber.shade900,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final path = r.proveedorFacturaStoragePath!.trim();
    final name = r.proveedorFacturaFileName?.trim();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(compact ? 10 : 12, compact ? 8 : 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.description_outlined, size: 20, color: Colors.blue.shade800),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Factura del importador',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: compact ? 12 : 13,
                    color: Colors.blue.shade900,
                  ),
                ),
              ),
              Icon(Icons.check_circle, size: 18, color: Colors.green.shade700),
            ],
          ),
          if (name != null && name.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              name,
              style: TextStyle(fontSize: 11.5, color: Colors.grey.shade800),
            ),
          ],
          if (r.proveedorFacturaSubmittedAt != null) ...[
            const SizedBox(height: 2),
            Text(
              'Recibida: ${formatEsShortDateTime(r.proveedorFacturaSubmittedAt)}',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _abrir(context, path),
            icon: const Icon(Icons.visibility_outlined, size: 18),
            label: const Text('Ver factura del proveedor'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.brandBlue,
            ),
          ),
          if (!compact) ...[
            const SizedBox(height: 6),
            Text(
              'Revise el monto antes de registrar su pago en la pasarela de abajo.',
              style: TextStyle(
                fontSize: 10.5,
                height: 1.3,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
