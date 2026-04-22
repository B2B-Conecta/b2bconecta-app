import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/transaction_request_model.dart';
import '../models/transaction_request_status.dart';
import '../theme/app_theme.dart';

/// Enlace externo a la ruta publicada por MotoLink (Google Maps).
/// Solo se muestra el botón cuando hay [TransactionRequestModel.adminRutaMapsUrl] guardado.
class TransactionRequestTransitSupplierToAliadoMapsCta extends StatelessWidget {
  const TransactionRequestTransitSupplierToAliadoMapsCta({
    super.key,
    required this.request,
  });

  final TransactionRequestModel request;

  Future<void> _open(BuildContext context, String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El enlace de ruta no es válido.')),
      );
      return;
    }
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!context.mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir Google Maps.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (request.status != TransactionRequestStatus.enTransito) {
      return const SizedBox.shrink();
    }

    if (!request.hasAdminRutaMapsUrl) {
      return Material(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, color: Colors.grey.shade700, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'MotoLink aún no ha publicado el enlace de la ruta en vivo. '
                  'Vuelva a consultar la ficha cuando esté disponible.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: Colors.grey.shade800,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final url = request.adminRutaMapsUrl!.trim();

    return Material(
      color: AppColors.brandBlue.withOpacity(0.08),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.alt_route, color: AppColors.brandBlue, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Ruta en vivo (MotoLink)',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Abre en Google Maps la ruta definida por MotoLink para este envío.',
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.35,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => _open(context, url),
              icon: const Icon(Icons.open_in_new, size: 20),
              label: const Text('Abrir ruta en Google Maps'),
            ),
          ],
        ),
      ),
    );
  }
}
