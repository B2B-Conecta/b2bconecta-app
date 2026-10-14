import 'package:flutter/material.dart';

import 'commission_settlement_document_type.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/widgets/segmented_filter_bar.dart';
import 'commission_settlement_filter_utils.dart';

/// Búsqueda y chips para filtrar cortes de comisión en el panel admin.
class CommissionSettlementListFilterBar extends StatefulWidget {
  const CommissionSettlementListFilterBar({
    super.key,
    required this.searchController,
    required this.filters,
    required this.importadorOptions,
    required this.onFiltersChanged,
  });

  final TextEditingController searchController;
  final CommissionSettlementFilters filters;
  final List<CommissionSettlementImporterOption> importadorOptions;
  final ValueChanged<CommissionSettlementFilters> onFiltersChanged;

  @override
  State<CommissionSettlementListFilterBar> createState() =>
      _CommissionSettlementListFilterBarState();
}

class _CommissionSettlementListFilterBarState
    extends State<CommissionSettlementListFilterBar> {
  @override
  void initState() {
    super.initState();
    widget.searchController.addListener(_onText);
  }

  @override
  void didUpdateWidget(covariant CommissionSettlementListFilterBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchController != widget.searchController) {
      oldWidget.searchController.removeListener(_onText);
      widget.searchController.addListener(_onText);
    }
  }

  @override
  void dispose() {
    widget.searchController.removeListener(_onText);
    super.dispose();
  }

  void _onText() => setState(() {});

  void _patch(CommissionSettlementFilters Function(CommissionSettlementFilters f) fn) {
    widget.onFiltersChanged(fn(widget.filters));
  }

  int get _activeFilterCount {
    final f = widget.filters;
    var count = 0;
    if (f.searchQuery.trim().isNotEmpty) count++;
    if (f.status != null) count++;
    if (f.weekScope != null) count++;
    if (f.documentType != null) count++;
    if (f.importadorId != null) count++;
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.filters;
    final hasFilters = f.hasActiveFilters;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: widget.searchController,
          onChanged: (v) => _patch((x) => x.copyWithSearch(v)),
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Buscar importador, RIF o referencia (ML- o B2B-)',
            hintStyle: AppColors.hintStyle,
            prefixIcon:
                Icon(Icons.search, color: AppColors.textSecondary),
            suffixIcon: widget.searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 20),
                    color: AppColors.textSecondary,
                    onPressed: () {
                      widget.searchController.clear();
                      _patch((x) => x.copyWithSearch(''));
                    },
                  )
                : null,
            filled: true,
            fillColor: AppColors.fieldFill,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.borderSubtle),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.borderSubtle),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: AppColors.brandBlue, width: 1.2),
            ),
            isDense: true,
          ),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String?>(
          value: f.importadorId,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'Importador',
            prefixIcon:
                const Icon(Icons.storefront_outlined, size: 20),
            filled: true,
            fillColor: AppColors.fieldFill,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.borderSubtle),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.borderSubtle),
            ),
          ),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('Todos los importadores'),
            ),
            ...widget.importadorOptions.map(
              (o) => DropdownMenuItem<String?>(
                value: o.id,
                child: Text(
                  o.businessName,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
          onChanged: (v) => _patch((x) => x.copyWithImportadorId(v)),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Text(
              'Filtros rápidos',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: AppColors.textPrimary,
              ),
            ),
            const Spacer(),
            if (hasFilters)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.brandBlue.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$_activeFilterCount activos',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.brandBlue,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        SegmentedFilterBar(
          labels: const [
            'Todos',
            'Borrador',
            'Emitido',
            'En revisión',
            'Pagado',
          ],
          selectedIndex: switch (f.status) {
            'borrador' => 1,
            'emitido' => 2,
            'pago_revision' => 3,
            'pagado' => 4,
            _ => 0,
          },
          onSelected: (index) => _patch(
            (x) => x.copyWithStatus(
              const [null, 'borrador', 'emitido', 'pago_revision', 'pagado'][index],
            ),
          ),
        ),
        SegmentedFilterBar(
          labels: const ['Todas las semanas', 'Sem. actual', 'Sem. anterior'],
          selectedIndex: switch (f.weekScope) {
            CommissionSettlementWeekScope.current => 1,
            CommissionSettlementWeekScope.previous => 2,
            _ => 0,
          },
          onSelected: (index) => _patch(
            (x) => x.copyWithWeekScope(
              const [
                null,
                CommissionSettlementWeekScope.current,
                CommissionSettlementWeekScope.previous,
              ][index],
            ),
          ),
        ),
        SegmentedFilterBar(
          labels: const ['Todo documento', 'Factura fiscal', 'Nota (NOT)'],
          selectedIndex: switch (f.documentType) {
            CommissionSettlementDocumentType.fiscalInvoice => 1,
            CommissionSettlementDocumentType.deliveryNote => 2,
            _ => 0,
          },
          onSelected: (index) => _patch(
            (x) => x.copyWithDocumentType(
              const [
                null,
                CommissionSettlementDocumentType.fiscalInvoice,
                CommissionSettlementDocumentType.deliveryNote,
              ][index],
            ),
          ),
        ),
        if (hasFilters) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                widget.searchController.clear();
                widget.onFiltersChanged(const CommissionSettlementFilters());
              },
              icon: const Icon(Icons.filter_alt_off, size: 18),
              label: const Text('Limpiar filtros'),
            ),
          ),
        ],
      ],
    );
  }
}

class CommissionSettlementImporterOption {
  const CommissionSettlementImporterOption({
    required this.id,
    required this.businessName,
  });

  final String id;
  final String businessName;
}
