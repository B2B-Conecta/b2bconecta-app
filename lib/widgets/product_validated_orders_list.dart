import 'package:flutter/material.dart';

import '../models/transaction_request_model.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';

/// Pedidos validados para un producto (pestaña en edición de producto).
class ProductValidatedOrdersList extends StatefulWidget {
  const ProductValidatedOrdersList({super.key, required this.productId});

  final String productId;

  @override
  State<ProductValidatedOrdersList> createState() =>
      _ProductValidatedOrdersListState();
}

class _ProductValidatedOrdersListState extends State<ProductValidatedOrdersList> {
  late Future<List<TransactionRequestModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = SupabaseService.fetchValidatedTransactionRequestsForProduct(
      widget.productId,
    );
  }

  @override
  void didUpdateWidget(ProductValidatedOrdersList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.productId != widget.productId) {
      _future = SupabaseService.fetchValidatedTransactionRequestsForProduct(
        widget.productId,
      );
    }
  }

  void _reload() {
    setState(() {
      _future = SupabaseService.fetchValidatedTransactionRequestsForProduct(
        widget.productId,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<TransactionRequestModel>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.brand),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('${snapshot.error}'),
                ),
                TextButton(onPressed: _reload, child: const Text('Reintentar')),
              ],
            ),
          );
        }
        final rows = snapshot.data ?? [];
        if (rows.isEmpty) {
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 80),
                Center(
                  child: Text(
                    'No hay pedidos validados para este producto.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: rows.length,
            itemBuilder: (context, i) {
              final r = rows[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(
                    r.aliadoBusinessName ?? 'Aliado',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    '${r.cantidad} uds · \$${r.precioTotal.toStringAsFixed(2)}',
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
