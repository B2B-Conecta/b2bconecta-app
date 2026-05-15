import 'package:flutter/material.dart';

import '../config/app_backend.dart';
import '../models/transaction_request_model.dart';
import '../models/transaction_request_status.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../utils/transaction_request_filter_utils.dart';
import 'importer_expandable_order_card.dart';
import 'main_shell_tab.dart';
import 'order_list_filter_bar.dart';

/// Solo solicitudes aprobadas por MotoLink para este producto (pendientes de primera acción).
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
  late final TextEditingController _searchCtrl;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(ProductValidatedOrdersList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.productId != widget.productId) {
      _searchCtrl.clear();
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

  void _clearFilters() {
    _searchCtrl.clear();
    setState(() {});
  }

  List<TransactionRequestModel> get _filtered {
    return TransactionRequestFilterUtils.apply(
      _rows,
      searchQuery: _searchCtrl.text,
    );
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
    if (!kAppUsesMotoConectaBackend &&
        next == TransactionRequestStatus.pedidoListo &&
        !r.hasProveedorFactura) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Adjunte primero la factura digital del proveedor.',
          ),
        ),
      );
      return;
    }
    if (kAppUsesMotoConectaBackend &&
        next == TransactionRequestStatus.enviado &&
        !r.hasProveedorFactura) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Adjunte la factura del proveedor antes de marcar «Enviado».',
          ),
        ),
      );
      return;
    }
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Estado actualizado.'),
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
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'No hay solicitudes aprobadas por MotoLink pendientes de tu primera acción para este producto.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final filtered = _filtered;
    return Stack(
      children: [
        Positioned.fill(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OrderListFilterBar(
                searchController: _searchCtrl,
                onSearchChanged: (_) => setState(() {}),
                hintText: 'Buscar por aliado',
              ),
              Expanded(
                child: filtered.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          const SizedBox(height: 32),
                          Center(
                            child: Column(
                              children: [
                                Text(
                                  'Ningún pedido coincide con los filtros.',
                                  style: TextStyle(color: Colors.grey.shade700),
                                ),
                                TextButton(
                                  onPressed: _clearFilters,
                                  child: const Text('Limpiar filtros'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          itemCount: filtered.length,
                          itemBuilder: (context, i) {
                            final r = filtered[i];
                            final next =
                                TransactionRequestStatus.nextForImporter(
                              r.status,
                            );
                            final headline = TransactionRequestStatus
                                .importerOperationalHeadline(r.status);
                            return ImporterExpandableOrderCard(
                              request: r,
                              expanded: _expandedRequestId == r.id,
                              onToggle: () => _toggleExpand(r.id),
                              statusLabel:
                                  r.statusLabelEs(),
                              operationalHeadline: headline,
                              nextStatus: next,
                              nextActionLabel: next != null
                                  ? TransactionRequestStatus.actionLabelForNext(
                                      next,
                                    )
                                  : null,
                              onAdvance: next != null
                                  ? () => _advance(context, r, next)
                                  : null,
                            );
                          },
                        ),
                      ),
              ),
            ],
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
