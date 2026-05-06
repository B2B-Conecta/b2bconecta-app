import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/transaction_request_model.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_date_format.dart';

/// Factura oficial MotoLink al aliado: referencia para el transportista (mercancía / entrega).
class TransportistaFacturaAliadoSection extends StatelessWidget {
  const TransportistaFacturaAliadoSection({
    super.key,
    required this.request,
  });

  final TransactionRequestModel request;

  Future<void> _openPath(BuildContext context, String rawPath) async {
    final path = rawPath.trim();
    if (path.isEmpty) return;
    try {
      final url = await SupabaseService.createSignedUrlForFacturaAliado(path);
      final uri = Uri.tryParse(url);
      if (uri == null || !uri.hasScheme) {
        throw StateError('URL inválida');
      }
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir el documento.')),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo abrir la factura: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = request;
    if (!r.hasFacturaAliado) return const SizedBox.shrink();

    return Material(
      color: AppColors.brandBlueContainer.withOpacity(0.5),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.receipt_long_outlined,
                    size: 20, color: AppColors.brandBlue),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Factura MotoLink (referencia)',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Documento oficial del pedido hacia el aliado. Úselo para contrastar carga al retirar en almacén.',
              style: TextStyle(
                fontSize: 11.5,
                height: 1.35,
                color: Colors.grey.shade800,
              ),
            ),
            if (r.motolinkAllyInvoicesDescargables.length <= 1 &&
                r.facturaAliadoFileName != null &&
                r.facturaAliadoFileName!.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                r.facturaAliadoFileName!.trim(),
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade700,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            if (r.facturaAliadoSubmittedAt != null) ...[
              const SizedBox(height: 2),
              Text(
                'Emitida: ${formatEsShortDateTime(r.facturaAliadoSubmittedAt)}',
                style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
              ),
            ],
            const SizedBox(height: 10),
            if (r.motolinkAllyInvoicesDescargables.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final e in r.motolinkAllyInvoicesDescargables)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: OutlinedButton.icon(
                        onPressed: e.storagePath == null ||
                                e.storagePath!.trim().isEmpty
                            ? null
                            : () => _openPath(context, e.storagePath!),
                        icon: const Icon(Icons.open_in_new, size: 18),
                        label: Text(
                          e.downloadButtonLabel,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                ],
              )
            else if (r.facturaAliadoStoragePath != null &&
                r.facturaAliadoStoragePath!.trim().isNotEmpty)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () =>
                      _openPath(context, r.facturaAliadoStoragePath!),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('Abrir factura'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
