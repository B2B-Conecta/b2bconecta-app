import 'package:flutter/material.dart';

import '../models/transaction_request_model.dart';
import '../models/transaction_request_status.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import 'admin_expandable_order_card.dart';

/// Pedidos activos del broker (pestaña Pedidos): no entregados ni rechazados.
class AdminActiveOrdersPanel extends StatefulWidget {
  const AdminActiveOrdersPanel({super.key});

  @override
  State<AdminActiveOrdersPanel> createState() => _AdminActiveOrdersPanelState();
}

class _AdminActiveOrdersPanelState extends State<AdminActiveOrdersPanel> {
  List<TransactionRequestModel> _rows = [];
  bool _loading = true;
  String? _error;
  String? _expandedRequestId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await SupabaseService.fetchActiveTransactionRequestsForAdmin();
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _loading = false;
        _expandedRequestId = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _statusLabel(String s) => TransactionRequestStatus.labelEs(s);

  void _toggleExpand(String id) {
    setState(() {
      _expandedRequestId = _expandedRequestId == id ? null : id;
    });
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
            SizedBox(height: 120),
            Center(
              child: Text(
                'No hay pedidos activos en curso.',
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
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: _rows.length,
            itemBuilder: (context, i) {
              final r = _rows[i];
              return AdminExpandableOrderCard(
                request: r,
                expanded: _expandedRequestId == r.id,
                onToggle: () => _toggleExpand(r.id),
                statusLabel: _statusLabel(r.status),
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
