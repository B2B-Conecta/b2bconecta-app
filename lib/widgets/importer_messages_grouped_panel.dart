import 'package:flutter/material.dart';

import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import 'inquiry_message_card.dart';

/// Pestaña Mensajes: conversaciones agrupadas por producto (importador).
class ImporterMessagesGroupedPanel extends StatelessWidget {
  const ImporterMessagesGroupedPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ProductMessageRow>>(
      future: SupabaseService.fetchMessagesForImporterInventory(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.brand),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No se pudieron cargar las conversaciones.\n'
                '${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        final rows = snapshot.data ?? [];
        if (rows.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Sin conversaciones activas. Cuando un aliado consulte por un '
                'producto, verás el hilo aquí agrupado por repuesto.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          );
        }

        final byProduct = <String, List<ProductMessageRow>>{};
        for (final r in rows) {
          byProduct.putIfAbsent(r.productId, () => []).add(r);
        }
        final entries = byProduct.entries.toList()
          ..sort((a, b) {
            final ta = a.value.first.createdAt;
            final tb = b.value.first.createdAt;
            return tb.compareTo(ta);
          });

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: entries.length,
          itemBuilder: (context, i) {
            final e = entries[i];
            final name = e.value.first.productName;
            final sku = e.value.first.productSku;
            final msgs = List<ProductMessageRow>.from(e.value)
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
            final lastContact = msgs.first.senderDisplayName;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: AppDecorations.radius12,
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: Theme(
                data: Theme.of(context).copyWith(
                  dividerColor: Colors.transparent,
                ),
                child: ExpansionTile(
                  initiallyExpanded: i == 0,
                  tilePadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
                  title: Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      if (sku != null && sku.trim().isNotEmpty)
                        Text(
                          'SKU: $sku',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.blue.shade800,
                          ),
                        ),
                      const SizedBox(height: 2),
                      Text(
                        '${msgs.length} mensaje(s) · último contacto: $lastContact',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  children: [
                    for (final m in msgs)
                      InquiryMessageCard(
                        message: m,
                        showProductMeta: false,
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
