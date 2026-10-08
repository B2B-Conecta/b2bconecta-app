import 'package:flutter/material.dart';

import 'importer_pedidos_filters_draft.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/widgets/app_date_picker.dart';
import 'package:motolink_pro_app/features/orders/shared/importer_order_date.dart';

/// Panel de filtro por fecha (cierre o alta de pedidos activos).
class ImporterPedidosFiltersSheet extends StatefulWidget {
  const ImporterPedidosFiltersSheet({
    super.key,
    required this.initial,
    required this.scrollController,
  });

  final ImporterPedidosFiltersDraft initial;
  final ScrollController scrollController;

  static Future<ImporterPedidosFiltersDraft?> show(
    BuildContext context, {
    required ImporterPedidosFiltersDraft initial,
  }) {
    return showModalBottomSheet<ImporterPedidosFiltersDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.52,
        minChildSize: 0.35,
        maxChildSize: 0.85,
        expand: false,
        builder: (_, scrollController) => ImporterPedidosFiltersSheet(
          initial: initial,
          scrollController: scrollController,
        ),
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

  @override
  void initState() {
    super.initState();
    _dateFrom = widget.initial.dateFrom;
    _dateTo = widget.initial.dateTo;
  }

  ImporterPedidosFiltersDraft _buildDraft() {
    return ImporterPedidosFiltersDraft(
      dateFrom: _dateFrom,
      dateTo: _dateTo,
    );
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
      lastDate: now.add(const Duration(days: 1)),
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 8),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.borderSubtle,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Filtrar por fecha',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => setState(() {
                  _dateFrom = null;
                  _dateTo = null;
                }),
                child: const Text('Limpiar'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Pedidos cerrados: fecha de cierre. Pedidos activos: fecha de alta.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.35),
          ),
        ),
        Expanded(
          child: ListView(
            controller: widget.scrollController,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
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
                onClear: _dateTo != null ? () => setState(() => _dateTo = null) : null,
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.brand,
                    ),
                    onPressed: () => Navigator.pop(context, _buildDraft()),
                    child: const Text('Aplicar'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

