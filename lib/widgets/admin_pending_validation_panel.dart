import 'package:flutter/material.dart';

import '../models/transaction_request_model.dart';
import '../models/transaction_request_status.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../utils/transaction_request_filter_utils.dart';
import 'admin_expandable_order_card.dart';
import 'main_shell_tab.dart';
import 'order_list_filter_bar.dart';

/// Solicitudes pendientes de aprobación o rechazo (pestaña Por validar — admin).
class AdminPendingValidationPanel extends StatefulWidget {
  const AdminPendingValidationPanel({super.key});

  @override
  State<AdminPendingValidationPanel> createState() =>
      _AdminPendingValidationPanelState();
}

class _AdminPendingValidationPanelState
    extends State<AdminPendingValidationPanel> {
  List<TransactionRequestModel> _rows = [];
  bool _loading = true;
  String? _error;
  String? _expandedRequestId;
  late final TextEditingController _searchCtrl;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController();
    MainShellTabController.registerAdminPorValidarNotificationDeepLink(
      _onNotificationPorValidarDeepLink,
    );
    _load();
  }

  @override
  void dispose() {
    MainShellTabController.registerAdminPorValidarNotificationDeepLink(null);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onNotificationPorValidarDeepLink() {
    final pending = MainShellTabController.peekPendingNotificationRelatedId();
    if (pending == null) return;
    if (_rows.any((r) => r.id == pending)) {
      MainShellTabController.consumePendingNotificationRelatedId();
      setState(() => _expandedRequestId = pending);
    } else if (!_loading) {
      _load();
    }
  }

  void _tryExpandFromPendingNotification() {
    final pending = MainShellTabController.peekPendingNotificationRelatedId();
    if (pending == null) return;
    if (_rows.any((r) => r.id == pending)) {
      MainShellTabController.consumePendingNotificationRelatedId();
      setState(() => _expandedRequestId = pending);
    } else if (!_loading) {
      MainShellTabController.consumePendingNotificationRelatedId();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await SupabaseService.fetchPendingValidationForAdmin();
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _loading = false;
        _expandedRequestId = null;
      });
      _tryExpandFromPendingNotification();
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
      statusFilter: null,
    );
  }

  String _statusLabel(TransactionRequestModel r) => r.statusLabelEs();

  void _toggleExpand(String id) {
    setState(() {
      _expandedRequestId = _expandedRequestId == id ? null : id;
    });
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
                _load();
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
                _load();
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

  @override
  Widget build(BuildContext context) {
    if (_loading && _rows.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.brand),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error: $_error'),
              const SizedBox(height: 12),
              FilledButton(onPressed: _load, child: const Text('Reintentar')),
            ],
          ),
        ),
      );
    }
    if (_rows.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
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
                hintText: 'Buscar solicitud por producto, SKU o empresa',
              ),
              Expanded(
                child: filtered.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          const SizedBox(height: 48),
                          Center(
                            child: Column(
                              children: [
                                Text(
                                  'Ninguna solicitud coincide con la búsqueda.',
                                  style: TextStyle(color: Colors.grey.shade700),
                                ),
                                TextButton(
                                  onPressed: _clearFilters,
                                  child: const Text('Limpiar búsqueda'),
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
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          itemCount: filtered.length,
                          itemBuilder: (context, i) {
                            final r = filtered[i];
                            return AdminExpandableOrderCard(
                              request: r,
                              expanded: _expandedRequestId == r.id,
                              onToggle: () => _toggleExpand(r.id),
                              statusLabel: _statusLabel(r),
                              expandedFooter: _buildExpandedFooter(context, r),
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
