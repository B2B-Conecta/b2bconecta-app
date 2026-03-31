import 'package:flutter/material.dart';

import '../services/supabase_service.dart';
import '../theme/app_theme.dart';

/// Lista de mensajes de negociación para un producto (importador).
class ProductInquiryMessagesList extends StatelessWidget {
  const ProductInquiryMessagesList({super.key, required this.productId});

  final String productId;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ProductMessageRow>>(
      future: SupabaseService.fetchMessagesForProduct(productId),
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
                'No se pudieron cargar los mensajes.\n${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        final rows = snapshot.data ?? [];
        if (rows.isEmpty) {
          return const Center(
            child: Text(
              'Aún no hay consultas sobre este producto.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: rows.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final m = rows[i];
            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                m.body,
                style: const TextStyle(fontSize: 15),
              ),
              subtitle: Text(
                '${m.createdAt.toLocal()} · remitente ${m.senderId.length > 8 ? m.senderId.substring(0, 8) : m.senderId}…',
                style: const TextStyle(fontSize: 11),
              ),
            );
          },
        );
      },
    );
  }
}
