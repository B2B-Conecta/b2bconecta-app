import 'package:flutter/material.dart';

import '../models/transaction_request_model.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';

/// Mis solicitudes de pedido (aliado).
class AliadoMyRequestsPanel extends StatefulWidget {
  const AliadoMyRequestsPanel({super.key});

  @override
  State<AliadoMyRequestsPanel> createState() => _AliadoMyRequestsPanelState();
}

class _AliadoMyRequestsPanelState extends State<AliadoMyRequestsPanel> {
  late Future<List<TransactionRequestModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = SupabaseService.fetchMyTransactionRequests();
  }

  void _reload() {
    setState(() {
      _future = SupabaseService.fetchMyTransactionRequests();
    });
  }

  String _label(String s) {
    switch (s) {
      case 'pendiente':
        return 'Pendiente de revisión';
      case 'aprobado_admin':
        return 'Aprobada por MotoLink';
      case 'rechazado':
        return 'Rechazada';
      case 'completado':
        return 'Completada';
      default:
        return s;
    }
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
                Center(child: Text('Aún no has solicitado pedidos.')),
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
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.productName ?? 'Producto',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _label(r.status),
                        style: TextStyle(
                          color: r.status == 'rechazado'
                              ? Colors.red.shade700
                              : AppColors.brandBlue,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        '${r.cantidad} uds · Total estimado: '
                        '\$${r.precioTotal.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ],
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
