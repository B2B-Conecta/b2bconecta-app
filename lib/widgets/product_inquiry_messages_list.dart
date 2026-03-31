import 'package:flutter/material.dart';

import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import 'inquiry_message_card.dart';

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
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
          itemCount: rows.length,
          itemBuilder: (context, i) {
            return InquiryMessageCard(
              message: rows[i],
              showProductMeta: false,
            );
          },
        );
      },
    );
  }
}
