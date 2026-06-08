import 'package:flutter/material.dart';

import '../models/admin_user_activity_row_model.dart';
import '../models/profile_role_labels.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_date_format.dart';

enum _ActivityPeriod { day, week }

enum _ActivityRoleFilter { all, aliado, importador }

/// Admin: monitoreo de ingresos y pedidos por aliado/importador.
class AdminUserMonitoringPanel extends StatefulWidget {
  const AdminUserMonitoringPanel({super.key});

  @override
  State<AdminUserMonitoringPanel> createState() =>
      _AdminUserMonitoringPanelState();
}

class _AdminUserMonitoringPanelState extends State<AdminUserMonitoringPanel> {
  List<AdminUserActivityRowModel> _rows = const [];
  bool _loading = true;
  String? _error;
  _ActivityPeriod _period = _ActivityPeriod.week;
  _ActivityRoleFilter _roleFilter = _ActivityRoleFilter.all;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final period = _period == _ActivityPeriod.day ? 'day' : 'week';
      final role = switch (_roleFilter) {
        _ActivityRoleFilter.all => null,
        _ActivityRoleFilter.aliado => 'aliado',
        _ActivityRoleFilter.importador => 'importador',
      };
      final rows = await SupabaseService.listAdminUserActivityMonitoring(
        role: role,
        period: period,
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

  List<AdminUserActivityRowModel> get _filtered {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return _rows;
    return _rows.where((r) {
      final name = (r.businessName ?? '').toLowerCase();
      final rif = (r.rif ?? '').toLowerCase();
      final city = (r.ciudad ?? '').toLowerCase();
      final state = (r.estado ?? '').toLowerCase();
      return name.contains(q) ||
          rif.contains(q) ||
          city.contains(q) ||
          state.contains(q);
    }).toList();
  }

  String get _periodLabel =>
      _period == _ActivityPeriod.day ? 'hoy' : 'últimos 7 días';

  @override
  Widget build(BuildContext context) {
    if (_loading && _rows.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppColors.brand));
    }

    if (_error != null && _rows.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: _load, child: const Text('Reintentar')),
            ],
          ),
        ),
      );
    }

    final filtered = _filtered;
    final totalLogins =
        filtered.fold<int>(0, (s, r) => s + r.loginCountPeriod);
    final totalOrders =
        filtered.fold<int>(0, (s, r) => s + r.ordersCountPeriod);
    final totalDelivered =
        filtered.fold<int>(0, (s, r) => s + r.ordersDeliveredPeriod);
    final totalVolume = filtered.fold<double>(
      0,
      (s, r) => s + r.ordersVolumeUsdPeriod,
    );

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.brand,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _toolbar(),
          const SizedBox(height: 12),
          _summaryRow(
            users: filtered.length,
            logins: totalLogins,
            orders: totalOrders,
            delivered: totalDelivered,
            volumeUsd: totalVolume,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Buscar por nombre, RIF o ubicación…',
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.brand,
                  ),
                ),
              ),
            ),
          if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  _rows.isEmpty
                      ? 'No hay usuarios B2B registrados.'
                      : 'Ningún usuario coincide con la búsqueda.',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            ...filtered.map(
              (r) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _UserActivityCard(row: r, periodLabel: _periodLabel),
              ),
            ),
        ],
      ),
    );
  }

  Widget _toolbar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Monitoreo de usuarios',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            IconButton(
              tooltip: 'Actualizar',
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh, size: 22),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SegmentedButton<_ActivityPeriod>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(
              value: _ActivityPeriod.day,
              label: Text('Hoy'),
              icon: Icon(Icons.today_outlined, size: 18),
            ),
            ButtonSegment(
              value: _ActivityPeriod.week,
              label: Text('Semana'),
              icon: Icon(Icons.date_range_outlined, size: 18),
            ),
          ],
          selected: {_period},
          onSelectionChanged: (s) {
            setState(() => _period = s.first);
            _load();
          },
        ),
        const SizedBox(height: 8),
        SegmentedButton<_ActivityRoleFilter>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: _ActivityRoleFilter.all, label: Text('Todos')),
            ButtonSegment(
              value: _ActivityRoleFilter.aliado,
              label: Text('Aliados'),
            ),
            ButtonSegment(
              value: _ActivityRoleFilter.importador,
              label: Text('Importadores'),
            ),
          ],
          selected: {_roleFilter},
          onSelectionChanged: (s) {
            setState(() => _roleFilter = s.first);
            _load();
          },
        ),
      ],
    );
  }

  Widget _summaryRow({
    required int users,
    required int logins,
    required int orders,
    required int delivered,
    required double volumeUsd,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _MiniStat(
          label: 'Usuarios',
          value: '$users',
          icon: Icons.people_outline,
        ),
        _MiniStat(
          label: 'Ingresos ($_periodLabel)',
          value: '$logins',
          icon: Icons.login_outlined,
        ),
        _MiniStat(
          label: 'Pedidos ($_periodLabel)',
          value: '$orders',
          icon: Icons.shopping_cart_outlined,
        ),
        _MiniStat(
          label: 'Entregados',
          value: '$delivered',
          icon: Icons.check_circle_outline,
        ),
        _MiniStat(
          label: 'Vol. USD entregado',
          value: '\$${volumeUsd.toStringAsFixed(0)}',
          icon: Icons.payments_outlined,
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.brand),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UserActivityCard extends StatelessWidget {
  const _UserActivityCard({
    required this.row,
    required this.periodLabel,
  });

  final AdminUserActivityRowModel row;
  final String periodLabel;

  @override
  Widget build(BuildContext context) {
    final roleLabel = ProfileRoleLabels.labelEs(row.role);
    final location = [
      if ((row.ciudad ?? '').trim().isNotEmpty) row.ciudad!.trim(),
      if ((row.estado ?? '').trim().isNotEmpty) row.estado!.trim(),
    ].join(', ');

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        title: Text(
          row.businessName?.trim().isNotEmpty == true
              ? row.businessName!.trim()
              : 'Sin nombre comercial',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              '$roleLabel${row.rif != null && row.rif!.isNotEmpty ? ' · ${row.rif}' : ''}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
            if (location.isNotEmpty)
              Text(
                location,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
          ],
        ),
        children: [
          _metricGrid(periodLabel),
          const SizedBox(height: 8),
          Text(
            'Último ingreso: ${formatEsShortDateTime(row.lastLoginAt)}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }

  Widget _metricGrid(String periodLabel) {
    final ordersLabel = row.ordersLabel;
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(),
        1: FlexColumnWidth(),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(
          children: [
            _metricCell(
              'Ingresos ($periodLabel)',
              '${row.loginCountPeriod}',
              Icons.login,
            ),
            _metricCell(
              'Ingresos hoy',
              '${row.loginCountToday}',
              Icons.today,
            ),
          ],
        ),
        TableRow(
          children: [
            _metricCell(
              '$ordersLabel ($periodLabel)',
              '${row.ordersCountPeriod}',
              Icons.receipt_long_outlined,
            ),
            _metricCell(
              'Entregados',
              '${row.ordersDeliveredPeriod}',
              Icons.local_shipping_outlined,
            ),
          ],
        ),
        TableRow(
          children: [
            _metricCell(
              'En curso',
              '${row.ordersInProgressPeriod}',
              Icons.hourglass_top_outlined,
            ),
            _metricCell(
              'Vol. USD entregado',
              '\$${row.ordersVolumeUsdPeriod.toStringAsFixed(2)}',
              Icons.attach_money,
            ),
          ],
        ),
      ],
    );
  }

  Widget _metricCell(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, right: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.brand),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
