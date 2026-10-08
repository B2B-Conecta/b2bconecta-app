import 'package:flutter/material.dart';

import 'aliado_pedidos_filters_draft.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/widgets/app_date_picker.dart';
import 'package:motolink_pro_app/features/orders/shared/order_list_filter_bar.dart';

String formatAliadoPedidosFilterDate(DateTime d) {
  final local = d.toLocal();
  final dd = local.day.toString().padLeft(2, '0');
  final mm = local.month.toString().padLeft(2, '0');
  return '$dd/$mm/${local.year}';
}

/// Panel único de filtros de pedidos del aliado.
class AliadoPedidosFiltersSheet extends StatefulWidget {
  const AliadoPedidosFiltersSheet({
    super.key,
    required this.initial,
    required this.statusOptions,
    required this.scrollController,
  });

  final AliadoPedidosFiltersDraft initial;
  final List<OrderStatusFilterOption> statusOptions;
  final ScrollController scrollController;

  static Future<AliadoPedidosFiltersDraft?> show(
    BuildContext context, {
    required AliadoPedidosFiltersDraft initial,
    required List<OrderStatusFilterOption> statusOptions,
  }) {
    return showModalBottomSheet<AliadoPedidosFiltersDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.72,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        expand: false,
        builder: (_, scrollController) => AliadoPedidosFiltersSheet(
          initial: initial,
          statusOptions: statusOptions,
          scrollController: scrollController,
        ),
      ),
    );
  }

  @override
  State<AliadoPedidosFiltersSheet> createState() =>
      _AliadoPedidosFiltersSheetState();
}

class _AliadoPedidosFiltersSheetState extends State<AliadoPedidosFiltersSheet> {
  String? _status;
  bool _morosoOnly = false;
  DateTime? _dateFrom;
  DateTime? _dateTo;

  @override
  void initState() {
    super.initState();
    _status = widget.initial.statusFilter;
    _morosoOnly = widget.initial.morosoOnly;
    _dateFrom = widget.initial.dateFrom;
    _dateTo = widget.initial.dateTo;
  }

  AliadoPedidosFiltersDraft _buildDraft() {
    return AliadoPedidosFiltersDraft(
      statusFilter: _status,
      morosoOnly: _morosoOnly,
      dateFrom: _dateFrom,
      dateTo: _dateTo,
    );
  }

  void _resetPanel() {
    setState(() {
      _status = null;
      _morosoOnly = false;
      _dateFrom = null;
      _dateTo = null;
    });
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final now = DateTime.now();
    final initial = isFrom ? (_dateFrom ?? now) : (_dateTo ?? _dateFrom ?? now);
    final picked = await showAppDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: now.add(const Duration(days: 1)),
      helpText: isFrom ? 'Desde' : 'Hasta',
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isFrom) {
        _dateFrom = picked;
        if (_dateTo != null && _dateOnly(_dateTo!).isBefore(_dateOnly(picked))) {
          _dateTo = picked;
        }
      } else {
        _dateTo = picked;
        if (_dateFrom != null && _dateOnly(_dateFrom!).isAfter(_dateOnly(picked))) {
          _dateFrom = picked;
        }
      }
    });
  }

  DateTime _dateOnly(DateTime d) {
    final local = d.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  void _applyPresetDays(int days) {
    final today = _dateOnly(DateTime.now());
    setState(() {
      _dateTo = today;
      _dateFrom = today.subtract(Duration(days: days - 1));
    });
  }

  void _applyThisMonth() {
    final now = DateTime.now();
    setState(() {
      _dateFrom = DateTime(now.year, now.month, 1);
      _dateTo = _dateOnly(now);
    });
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewPadding.bottom;

    return Material(
      color: Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.borderSubtle,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Filtros de pedidos',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Puede acotar por un paso, por fechas o por pagos pendientes.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              controller: widget.scrollController,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              children: [
                _sectionTitle('PASO DEL PEDIDO'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilterChip(
                      label: const Text('Todos'),
                      selected: _status == null,
                      onSelected: (_) => setState(() => _status = null),
                      selectedColor: AppColors.brandBlue.withOpacity(0.2),
                      checkmarkColor: AppColors.brandBlue,
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: _status == null
                            ? AppColors.brandBlue
                            : AppColors.textPrimary,
                      ),
                    ),
                    ...widget.statusOptions.map((o) {
                      final selected = _status == o.status;
                      return FilterChip(
                        label: Text(o.label),
                        selected: selected,
                        onSelected: (_) => setState(() => _status = o.status),
                        selectedColor: AppColors.brandBlue.withOpacity(0.2),
                        checkmarkColor: AppColors.brandBlue,
                        labelStyle: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: selected
                              ? AppColors.brandBlue
                              : AppColors.textPrimary,
                        ),
                      );
                    }),
                  ],
                ),
                _sectionTitle('PAGO PENDIENTE'),
                SwitchListTile(
                  value: _morosoOnly,
                  onChanged: (v) => setState(() => _morosoOnly = v),
                  contentPadding: EdgeInsets.zero,
                  activeColor: Colors.red.shade800,
                  title: const Text(
                    'Solo con pago por confirmar',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: const Text(
                    'Pedidos entregados que aún no tienen el pago aprobado.',
                    style: TextStyle(fontSize: 12),
                  ),
                  secondary: Icon(
                    Icons.warning_amber_rounded,
                    color: _morosoOnly
                        ? Colors.red.shade800
                        : AppColors.textSecondary,
                  ),
                ),
                _sectionTitle('FECHA'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ActionChip(
                      label: const Text('7 días'),
                      onPressed: () => _applyPresetDays(7),
                    ),
                    ActionChip(
                      label: const Text('30 días'),
                      onPressed: () => _applyPresetDays(30),
                    ),
                    ActionChip(
                      label: const Text('Este mes'),
                      onPressed: _applyThisMonth,
                    ),
                    ActionChip(
                      label: const Text('Quitar fechas'),
                      onPressed: _dateFrom == null && _dateTo == null
                          ? null
                          : () => setState(() {
                                _dateFrom = null;
                                _dateTo = null;
                              }),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                FilterDateField(
                  label: 'Desde',
                  value: _dateFrom,
                  onTap: () => _pickDate(isFrom: true),
                  onClear: _dateFrom != null
                      ? () => setState(() => _dateFrom = null)
                      : null,
                ),
                const SizedBox(height: 12),
                FilterDateField(
                  label: 'Hasta',
                  value: _dateTo,
                  onTap: () => _pickDate(isFrom: false),
                  onClear: _dateTo != null
                      ? () => setState(() => _dateTo = null)
                      : null,
                ),
                SizedBox(height: bottom + 8),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, bottom + 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _resetPanel,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Restablecer'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () =>
                        Navigator.of(context).pop(_buildDraft()),
                    child: const Text('Aplicar filtros'),
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
