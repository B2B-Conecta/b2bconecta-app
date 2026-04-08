import 'package:flutter/material.dart';

import '../models/transaction_request_model.dart';
import '../models/transaction_request_status.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import 'admin_expandable_order_card.dart';

/// Solicitudes pendientes de aprobación o rechazo (pestaña Por validar — admin).
class AdminPendingValidationPanel extends StatefulWidget {
  const AdminPendingValidationPanel({super.key});

  @override
  State<AdminPendingValidationPanel> createState() =>
      _AdminPendingValidationPanelState();
}

class _AdminPendingValidationPanelState extends State<AdminPendingValidationPanel> {
  late Future<List<TransactionRequestModel>> _future;
  String? _expandedRequestId;

  @override
  void initState() {
    super.initState();
    _future = SupabaseService.fetchPendingValidationForAdmin();
  }

  void _reload() {
    setState(() {
      _future = SupabaseService.fetchPendingValidationForAdmin();
      _expandedRequestId = null;
    });
  }

  String _statusLabel(String s) => TransactionRequestStatus.labelEs(s);

  void _toggleExpand(String id) {
    setState(() {
      _expandedRequestId = _expandedRequestId == id ? null : id;
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
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Error: ${snapshot.error}'),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _reload, child: const Text('Reintentar')),
                ],
              ),
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
                SizedBox(height: 120),
                Center(
                  child: Text(
                    'No hay solicitudes por validar.',
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
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: rows.length,
            itemBuilder: (context, i) {
              final r = rows[i];
              return AdminExpandableOrderCard(
                request: r,
                expanded: _expandedRequestId == r.id,
                onToggle: () => _toggleExpand(r.id),
                statusLabel: _statusLabel(r.status),
                expandedFooter: _buildExpandedFooter(context, r),
              );
            },
          ),
        );
      },
    );
  }

  Widget? _buildExpandedFooter(
    BuildContext context,
    TransactionRequestModel r,
  ) {
    final children = <Widget>[];

    if (r.notasAdmin != null && r.notasAdmin!.isNotEmpty) {
      children.add(
        Text(
          'Notas: ${r.notasAdmin}',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade700,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    if (children.isNotEmpty) children.add(const SizedBox(height: 10));
    children.add(
      Row(
        children: [
          FilledButton(
            onPressed: () async {
              try {
                await SupabaseService.adminUpdateTransactionRequest(
                  id: r.id,
                  status: TransactionRequestStatus.aprobadoAdmin,
                );
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Solicitud aprobada.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                _reload();
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            child: const Text('Aprobar solicitud'),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: () async {
              try {
                await SupabaseService.adminUpdateTransactionRequest(
                  id: r.id,
                  status: TransactionRequestStatus.rechazado,
                );
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Solicitud rechazada.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                _reload();
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            child: const Text('Rechazar'),
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}
