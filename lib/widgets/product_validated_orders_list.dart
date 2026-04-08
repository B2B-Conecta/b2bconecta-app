import 'package:flutter/material.dart';

import '../models/transaction_request_model.dart';
import '../models/transaction_request_status.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import 'importer_expandable_order_card.dart';
import 'main_shell_tab.dart';

/// Pedidos validados para un producto (pestaña en edición de producto).
class ProductValidatedOrdersList extends StatefulWidget {
  const ProductValidatedOrdersList({super.key, required this.productId});

  final String productId;

  @override
  State<ProductValidatedOrdersList> createState() =>
      _ProductValidatedOrdersListState();
}

class _ProductValidatedOrdersListState extends State<ProductValidatedOrdersList> {
  List<TransactionRequestModel> _rows = [];
  bool _loading = true;
  String? _error;
  String? _expandedRequestId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(ProductValidatedOrdersList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.productId != widget.productId) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await SupabaseService.fetchValidatedTransactionRequestsForProduct(
        widget.productId,
      );
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
      if (next == TransactionRequestStatus.enPreparacion) {
        MainShellTabController.goTo(1);
        MainShellTabController.notifyImporterPedidosReload();
      }
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
    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _load,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
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
