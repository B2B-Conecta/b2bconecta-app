import 'package:flutter/material.dart';

import '../models/transaction_request_model.dart';
import '../models/transaction_request_status.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import 'importer_expandable_order_card.dart';
import 'main_shell_tab.dart';

/// Pedidos en preparación o en tránsito (pestaña Pedidos del importador).
class ImporterActiveOrdersPanel extends StatefulWidget {
  const ImporterActiveOrdersPanel({super.key});

  @override
  State<ImporterActiveOrdersPanel> createState() =>
      _ImporterActiveOrdersPanelState();
}

class _ImporterActiveOrdersPanelState extends State<ImporterActiveOrdersPanel> {
  List<TransactionRequestModel> _rows = [];
  bool _loading = true;
  String? _error;
  String? _expandedRequestId;

  @override
  void initState() {
    super.initState();
    MainShellTabController.registerImporterPedidosReload(() => _load());
    _load();
  }

  @override
  void dispose() {
    MainShellTabController.registerImporterPedidosReload(null);
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows =
          await SupabaseService.fetchActiveTransactionRequestsForImporter();
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _toggleExpand(String id) {
    setState(() {
      _expandedRequestId = _expandedRequestId == id ? null : id;
    });
  }

  Future<void> _advance(
    BuildContext context,
    TransactionRequestModel r,
    String next,
  ) async {
    try {
      await SupabaseService.importerAdvanceTransactionRequest(
        id: r.id,
        newStatus: next,
      );
      if (!context.mounted) return;
      if (next == TransactionRequestStatus.entregado) {
        MainShellTabController.notifyImporterInventoryReload();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            next == TransactionRequestStatus.entregado
                ? 'Pedido marcado como entregado. Inventario y crédito del aliado actualizados.'
                : 'Estado actualizado.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _load();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _rows.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.brand),
      );
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_error!),
            ),
            TextButton(onPressed: _load, child: const Text('Reintentar')),
          ],
        ),
      );
    }
    if (_rows.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 100),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Aquí verás los pedidos en preparación y en tránsito. '
                'Desde «Validados», marca «En preparación» para que aparezcan aquí.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      );
    }
    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _load,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: _rows.length,
            itemBuilder: (context, i) {
              final r = _rows[i];
              final next = TransactionRequestStatus.nextForImporter(r.status);
              final headline =
                  TransactionRequestStatus.importerOperationalHeadline(r.status);
              return ImporterExpandableOrderCard(
                request: r,
                expanded: _expandedRequestId == r.id,
                onToggle: () => _toggleExpand(r.id),
                statusLabel: TransactionRequestStatus.labelEs(r.status),
                operationalHeadline: headline,
                nextStatus: next,
                nextActionLabel: next != null
                    ? TransactionRequestStatus.actionLabelForNext(next)
                    : null,
                onAdvance: next != null
                    ? () => _advance(context, r, next)
                    : null,
              );
            },
          ),
        ),
        if (_loading)
          const Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppColors.brand,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
