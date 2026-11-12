import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'package:motolink_pro_app/core/layout/b2b_data_table_shell.dart';
import 'package:motolink_pro_app/core/widgets/app_date_picker.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';
import 'package:motolink_pro_app/features/admin/unified_action_dialog.dart';
import 'package:motolink_pro_app/features/orders/importador/importer_pedidos_filters_draft.dart';
import 'package:motolink_pro_app/features/orders/shared/importer_order_date.dart';

/// Modal unificado de filtros para `OrdersModule` (`/admin/orders`).
class AdminOrdersFiltersDialog extends StatefulWidget {
  const AdminOrdersFiltersDialog({super.key, required this.initial});

  final ImporterPedidosFiltersDraft initial;

  static Future<ImporterPedidosFiltersDraft?> show(
    BuildContext context, {
    required ImporterPedidosFiltersDraft initial,
  }) {
    return UnifiedActionDialog.show<ImporterPedidosFiltersDraft>(
      context: context,
      builder: (ctx) => AdminOrdersFiltersDialog(initial: initial),
    );
  }

  @override
  State<AdminOrdersFiltersDialog> createState() =>
      _AdminOrdersFiltersDialogState();
}

class _AdminOrdersFiltersDialogState extends State<AdminOrdersFiltersDialog> {
  DateTime? _dateFrom;
  DateTime? _dateTo;
  bool _morosoOnly = false;
  bool _creditOnly = false;
  bool _replacementOnly = false;

  @override
  void initState() {
    super.initState();
    _dateFrom = widget.initial.dateFrom;
    _dateTo = widget.initial.dateTo;
    _morosoOnly = widget.initial.morosoOnly;
    _creditOnly = widget.initial.creditOnly;
    _replacementOnly = widget.initial.replacementOnly;
  }

  ImporterPedidosFiltersDraft _buildDraft() => ImporterPedidosFiltersDraft(
        dateFrom: _dateFrom,
        dateTo: _dateTo,
        morosoOnly: _morosoOnly,
        creditOnly: _creditOnly,
        replacementOnly: _replacementOnly,
      );

  void _resetPanel() {
    setState(() {
      _dateFrom = null;
      _dateTo = null;
      _morosoOnly = false;
      _creditOnly = false;
      _replacementOnly = false;
    });
  }

  void _applyPresetDays(int days) {
    final today = ImporterOrderDate.dateOnly(DateTime.now());
    setState(() {
      _dateTo = today;
      _dateFrom = today.subtract(Duration(days: days - 1));
    });
  }

  void _applyThisMonth() {
    final now = DateTime.now();
    setState(() {
      _dateFrom = DateTime(now.year, now.month, 1);
      _dateTo = ImporterOrderDate.dateOnly(now);
    });
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final now = DateTime.now();
    final initial = isFrom ? (_dateFrom ?? now) : (_dateTo ?? _dateFrom ?? now);
    final picked = await showAppDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: now.add(const Duration(days: 365)),
      helpText: isFrom ? 'Desde' : 'Hasta',
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isFrom) {
        _dateFrom = picked;
        if (_dateTo != null &&
            ImporterOrderDate.dateOnly(_dateTo!)
                .isBefore(ImporterOrderDate.dateOnly(picked))) {
          _dateTo = picked;
        }
      } else {
        _dateTo = picked;
        if (_dateFrom != null &&
            ImporterOrderDate.dateOnly(_dateFrom!)
                .isAfter(ImporterOrderDate.dateOnly(picked))) {
          _dateFrom = picked;
        }
      }
    });
  }

  int get _tipoIndex {
    if (_creditOnly) return 1;
    if (_replacementOnly) return 2;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    return UnifiedActionDialog(
      title: 'Filtros de pedidos',
      subtitle: 'Tipo, pago pendiente y rango de fechas.',
      glyph: LucideGlyph.slidersHorizontal,
      tone: UnifiedActionTone.info,
      maxWidth: 480,
      cancelLabel: 'Restaurar',
      onCancel: _resetPanel,
      primaryLabel: 'Aplicar filtros',
      onPrimary: () => Navigator.of(context).pop(_buildDraft()),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Tipo de pedido',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: theme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final entry in const [
                (0, 'Todos'),
                (1, 'Saldo aplicado'),
                (2, 'Cambio de producto'),
              ])
                B2bDataTableFilterPill(
                  label: entry.$2,
                  selected: _tipoIndex == entry.$1,
                  onTap: () => setState(() {
                    _creditOnly = entry.$1 == 1;
                    _replacementOnly = entry.$1 == 2;
                  }),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: theme.inputFill,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: theme.borderSubtle),
            ),
            child: SwitchListTile(
              value: _morosoOnly,
              onChanged: (v) => setState(() => _morosoOnly = v),
              contentPadding: EdgeInsets.zero,
              activeColor: theme.brand,
              title: Text(
                'Solo con pago por confirmar',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: theme.textPrimary,
                ),
              ),
              subtitle: Text(
                'Entregados sin pago aprobado.',
                style: TextStyle(fontSize: 12, color: theme.textSecondary),
              ),
              secondary: LucideIcon(
                LucideGlyph.triangleAlert,
                size: 18,
                color: _morosoOnly ? theme.brand : theme.textMuted,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Fecha',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: theme.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Cerrados: fecha de cierre. Activos: fecha de alta.',
            style: TextStyle(
              fontSize: 12,
              height: 1.35,
              color: theme.textMuted,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              B2bDataTableFilterPill(
                label: 'Hoy',
                selected: false,
                onTap: () => _applyPresetDays(1),
              ),
              B2bDataTableFilterPill(
                label: '7 días',
                selected: false,
                onTap: () => _applyPresetDays(7),
              ),
              B2bDataTableFilterPill(
                label: '30 días',
                selected: false,
                onTap: () => _applyPresetDays(30),
              ),
              B2bDataTableFilterPill(
                label: 'Este mes',
                selected: false,
                onTap: _applyThisMonth,
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
          const SizedBox(height: 10),
          FilterDateField(
            label: 'Hasta',
            value: _dateTo,
            onTap: () => _pickDate(isFrom: false),
            onClear:
                _dateTo != null ? () => setState(() => _dateTo = null) : null,
          ),
        ],
      ),
    );
  }
}
