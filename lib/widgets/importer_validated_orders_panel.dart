import 'package:flutter/material.dart';

import '../models/transaction_request_model.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';

/// Lista de pedidos ya validados por MotoLink (importador).
class ImporterValidatedOrdersPanel extends StatefulWidget {
  const ImporterValidatedOrdersPanel({super.key});

  @override
  State<ImporterValidatedOrdersPanel> createState() =>
      _ImporterValidatedOrdersPanelState();
}

class _ImporterValidatedOrdersPanelState
    extends State<ImporterValidatedOrdersPanel> {
  late Future<List<TransactionRequestModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = SupabaseService.fetchValidatedTransactionRequestsForImporter();
  }

  void _reload() {
    setState(() {
      _future = SupabaseService.fetchValidatedTransactionRequestsForImporter();
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
                Text('${snapshot.error}'),
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
                SizedBox(height: 100),
                Center(child: Text('No hay pedidos validados por MotoLink.')),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: rows.length,
            itemBuilder: (context, i) {
              final r = rows[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  title: Text(
                    r.productName ?? 'Producto',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    '${r.aliadoBusinessName ?? 'Aliado'} · ${r.cantidad} uds · '
                    '\$${r.precioTotal.toStringAsFixed(2)}',
                  ),
                  isThreeLine: true,
                ),
              );
            },
          ),
        );
      },
    );
  }
}
