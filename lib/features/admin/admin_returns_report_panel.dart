import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/utils/app_date_format.dart';
import 'package:motolink_pro_app/core/utils/ves_amount_format.dart';
import 'package:motolink_pro_app/features/orders/shared/order_return_rules.dart';
import 'package:motolink_pro_app/features/orders/shared/orders_service.dart';

/// Lectura de devoluciones: frecuencia por importador y saldo vigente.
class AdminReturnsReportPanel extends StatefulWidget {
  const AdminReturnsReportPanel({super.key});

  @override
  State<AdminReturnsReportPanel> createState() =>
      _AdminReturnsReportPanelState();
}

class _AdminReturnsReportPanelState extends State<AdminReturnsReportPanel> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _importers = const [];
  List<Map<String, dynamic>> _casos = const [];

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
      final data = await OrdersService.fetchAdminPostventaResumen();
      if (!mounted) return;
      setState(() {
        _importers = _maps(data['importers']);
        _casos = _maps(data['casos']);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'No se pudo cargar el reporte de devoluciones.';
      });
    }
  }

  List<Map<String, dynamic>> _maps(dynamic raw) {
    if (raw is! List) return const [];
    return raw.whereType<Map>().map(Map<String, dynamic>.from).toList();
  }

  double _num(dynamic raw) => double.tryParse(raw?.toString() ?? '') ?? 0;

  int _int(dynamic raw) => int.tryParse(raw?.toString() ?? '') ?? 0;

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              TextButton(onPressed: _load, child: const Text('Reintentar')),
            ],
          ),
        ),
      );
    }

    final totalCasos = _importers.fold<int>(
      0,
      (sum, row) => sum + _int(row['devoluciones']),
    );
    final abiertas = _importers.fold<int>(
      0,
      (sum, row) => sum + _int(row['abiertas']),
    );
    final saldo = _importers.fold<double>(
      0,
      (sum, row) => sum + _num(row['saldo_vigente']),
    );

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Text(
            'Devoluciones',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Lectura para mediación. La decisión sigue en el importador.',
            style: TextStyle(
              fontSize: 13,
              height: 1.35,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _Stat(
                  label: 'Casos',
                  value: '$totalCasos',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Stat(
                  label: 'En revisión',
                  value: '$abiertas',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Stat(
                  label: 'Saldo vigente',
                  value: '${formatRefAmount(saldo)} REF',
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Por importador',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          if (_importers.isEmpty)
            Text(
              'Todavía no hay devoluciones.',
              style: TextStyle(color: AppColors.textSecondary),
            )
          else
            for (final row in _importers) ...[
              _ImporterCard(row: row, number: _num, count: _int),
              const SizedBox(height: 8),
            ],
          const SizedBox(height: 12),
          Text(
            'Últimas solicitudes',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          for (final row in _casos) ...[
            _CaseCard(row: row, number: _num),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: AppColors.brand,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImporterCard extends StatelessWidget {
  const _ImporterCard({
    required this.row,
    required this.number,
    required this.count,
  });

  final Map<String, dynamic> row;
  final double Function(dynamic) number;
  final int Function(dynamic) count;

  @override
  Widget build(BuildContext context) {
    final saldo = number(row['saldo_vigente']);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              row['importer_name']?.toString() ?? 'Importador',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${count(row['devoluciones'])} devoluciones · '
              '${count(row['abiertas'])} en revisión · '
              '${count(row['creditos'])} créditos · '
              '${count(row['cambios'])} cambios · '
              '${count(row['rechazadas'])} no aceptadas',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.35,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Saldo vigente ${formatRefAmount(saldo)} REF',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: AppColors.brand,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CaseCard extends StatelessWidget {
  const _CaseCard({required this.row, required this.number});

  final Map<String, dynamic> row;
  final double Function(dynamic) number;

  @override
  Widget build(BuildContext context) {
    final when = DateTime.tryParse(row['created_at']?.toString() ?? '');
    final status = _statusLabel(row['status']?.toString());
    final pref = OrderReturnRules.preferenceLabel(
      row['requested_resolution']?.toString(),
    );
    final shipment = OrderReturnRules.replacementStatusLabel(
      row['replacement_status']?.toString(),
    );
    final note = row['rejection_note']?.toString().trim();
    final credit = number(row['credit_amount']);
    final remaining = row['remaining'];
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${row['aliado_name'] ?? 'Tienda'} · ${row['importer_name'] ?? 'Importador'}',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13.5,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${row['product_name'] ?? 'Producto'} · ${row['affected_qty'] ?? 1} uds',
              style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              [
                status,
                if (pref.isNotEmpty) 'Prefiere $pref',
                if (when != null) formatEsShortDateTime(when.toLocal()),
              ].join(' · '),
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            if (credit > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  remaining == null
                      ? 'Crédito ${formatRefAmount(credit)} REF'
                      : 'Crédito ${formatRefAmount(credit)} REF · vigente ${formatRefAmount(number(remaining))} REF'
                          '${row['erp_reference'] == null ? '' : ' · ${row['erp_reference']}'}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.brand,
                  ),
                ),
              ),
            if (shipment.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Cambio: $shipment',
                  style: TextStyle(fontSize: 12.5, color: AppColors.textPrimary),
                ),
              ),
            if (note != null && note.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  note,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.35,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'abierta':
        return 'En revisión';
      case 'aprobada_credito':
        return 'Crédito aprobado';
      case 'aprobada_cambio':
        return 'Cambio aprobado';
      case 'rechazada':
        return 'No aceptada';
      default:
        return 'Devolución';
    }
  }
}
