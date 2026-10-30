import 'package:flutter/material.dart';

import 'importer_pedidos_filters_draft.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/layout/adaptive_admin_sheet.dart';
import 'package:motolink_pro_app/core/widgets/app_date_picker.dart';
import 'package:motolink_pro_app/features/orders/shared/importer_order_date.dart';
import 'package:motolink_pro_app/features/orders/shared/order_signal_filters.dart';

String formatImporterPedidosFilterDate(DateTime d) {
  final local = d.toLocal();
  final dd = local.day.toString().padLeft(2, '0');
  final mm = local.month.toString().padLeft(2, '0');
  return '$dd/$mm/${local.year}';
}

/// Panel de filtros de pedidos (importador / admin): señales + fechas.
class ImporterPedidosFiltersSheet extends StatefulWidget {
  const ImporterPedidosFiltersSheet({
    super.key,
    required this.initial,
    required this.scrollController,
    this.showOnlyNuevos = false,
  });

  final ImporterPedidosFiltersDraft initial;
  final ScrollController? scrollController;

  /// Importador: chip «Pedido nuevo». Admin lo oculta.
  final bool showOnlyNuevos;

  static Future<ImporterPedidosFiltersDraft?> show(
    BuildContext context, {
    required ImporterPedidosFiltersDraft initial,
    bool showOnlyNuevos = false,
  }) {
    return showAdaptiveAdminSheet<ImporterPedidosFiltersDraft>(
      context: context,
      showDragHandle: false,
      draggable: true,
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      desktopMaxWidth: 560,
      builder: (_, scrollController) => ImporterPedidosFiltersSheet(
        initial: initial,
        scrollController: scrollController,
        showOnlyNuevos: showOnlyNuevos,
      ),
    );
  }

  @override
  State<ImporterPedidosFiltersSheet> createState() =>
      _ImporterPedidosFiltersSheetState();
}

class _ImporterPedidosFiltersSheetState
    extends State<ImporterPedidosFiltersSheet> {
  DateTime? _dateFrom;
  DateTime? _dateTo;
  bool _morosoOnly = false;
  bool _creditOnly = false;
  bool _replacementOnly = false;
  bool _onlyNuevos = false;

  @override
  void initState() {
    super.initState();
    _dateFrom = widget.initial.dateFrom;
    _dateTo = widget.initial.dateTo;
    _morosoOnly = widget.initial.morosoOnly;
    _creditOnly = widget.initial.creditOnly;
    _replacementOnly = widget.initial.replacementOnly;
    _onlyNuevos = widget.initial.onlyNuevos;
  }

  ImporterPedidosFiltersDraft _buildDraft() {
    return ImporterPedidosFiltersDraft(
      dateFrom: _dateFrom,
      dateTo: _dateTo,
      morosoOnly: _morosoOnly,
      creditOnly: _creditOnly,
      replacementOnly: _replacementOnly,
      onlyNuevos: widget.showOnlyNuevos && _onlyNuevos,
    );
  }

  void _resetPanel() {
    setState(() {
      _dateFrom = null;
      _dateTo = null;
      _morosoOnly = false;
      _creditOnly = false;
      _replacementOnly = false;
      _onlyNuevos = false;
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
    final desktop = isAdminDesktopLayout(context);
    final bottom = MediaQuery.viewPaddingOf(context).bottom;

    return Material(
      color: AppColors.card,
      borderRadius: desktop
          ? BorderRadius.circular(20)
          : const BorderRadius.vertical(top: Radius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(20, desktop ? 20 : 12, 12, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!desktop) ...[
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
                ],
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
                            'Afiná por señales, pago pendiente y fechas.',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Cerrar',
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: Icon(
                        Icons.close_rounded,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              controller: widget.scrollController,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              children: [
                if (widget.showOnlyNuevos) ...[
                  _sectionTitle('INGRESO'),
                  SwitchListTile(
                    value: _onlyNuevos,
                    onChanged: (v) => setState(() => _onlyNuevos = v),
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Solo pedidos nuevos',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: const Text(
                      'Pendientes de confirmación del proveedor.',
                      style: TextStyle(fontSize: 12),
                    ),
                    secondary: Icon(
                      Icons.fiber_new_rounded,
                      color: _onlyNuevos
                          ? AppColors.brandBlue
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
                _sectionTitle('TIPO DE PEDIDO'),
                OrderSignalFilterBar(
                  creditOnly: _creditOnly,
                  replacementOnly: _replacementOnly,
                  onChanged: (credit, replacement) => setState(() {
                    _creditOnly = credit;
                    _replacementOnly = replacement;
                  }),
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
                Text(
                  'Cerrados: fecha de cierre. Activos: fecha de alta.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ActionChip(
                      label: const Text('Hoy'),
                      onPressed: () => _applyPresetDays(1),
                    ),
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
                      onPressed: () => setState(() {
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
          Container(
            decoration: BoxDecoration(
              color: AppColors.card,
              border: Border(top: BorderSide(color: AppColors.borderSubtle)),
            ),
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              desktop ? 18 : bottom + 16,
            ),
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
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.brand,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context, _buildDraft()),
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
