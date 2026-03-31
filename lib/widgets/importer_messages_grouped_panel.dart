import 'package:flutter/material.dart';

import '../services/supabase_service.dart';
import '../theme/app_theme.dart';

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
            final msgs = List<ProductMessageRow>.from(e.value)
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ExpansionTile(
                initiallyExpanded: i == 0,
                title: Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text('${msgs.length} mensaje(s)'),
                children: [
                  for (final m in msgs)
                    ListTile(
                      title: Text(m.body),
                      subtitle: Text(
                        m.createdAt.toLocal().toString(),
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
