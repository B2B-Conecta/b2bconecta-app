import 'package:flutter/material.dart';

import '../models/commission_settlement_document_type.dart';
import '../theme/app_theme.dart';
import '../utils/commission_settlement_filter_utils.dart';

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

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    Color? selectedColor,
  }) {
    return FilterChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: selected,
      onSelected: (_) => onTap(),
      visualDensity: VisualDensity.compact,
      selectedColor: (selectedColor ?? AppColors.brandBlue).withOpacity(0.2),
      checkmarkColor: selectedColor ?? AppColors.brandBlue,
    );
  }

  Widget _chipRow(List<Widget> chips) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: chips),
    );
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
            hintText: 'Buscar importador, RIF o referencia',
            prefixIcon:
                const Icon(Icons.search, color: AppColors.textSecondary),
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
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
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
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
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
                color: Colors.grey.shade800,
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
        _chipRow([
          _chip(
            label: 'Todos',
            selected: f.status == null,
            onTap: () => _patch((x) => x.copyWithStatus(null)),
          ),
          const SizedBox(width: 6),
          _chip(
            label: 'Borrador',
            selected: f.status == 'borrador',
            onTap: () => _patch((x) => x.copyWithStatus('borrador')),
          ),
          const SizedBox(width: 6),
          _chip(
            label: 'Emitido',
            selected: f.status == 'emitido',
            onTap: () => _patch((x) => x.copyWithStatus('emitido')),
          ),
          const SizedBox(width: 6),
          _chip(
            label: 'En revisión',
            selected: f.status == 'pago_revision',
            onTap: () => _patch((x) => x.copyWithStatus('pago_revision')),
            selectedColor: Colors.deepOrange,
          ),
          const SizedBox(width: 6),
          _chip(
            label: 'Pagado',
            selected: f.status == 'pagado',
            onTap: () => _patch((x) => x.copyWithStatus('pagado')),
            selectedColor: Colors.green.shade700,
          ),
        ]),
        const SizedBox(height: 8),
        _chipRow([
          _chip(
            label: 'Todas las semanas',
            selected: f.weekScope == null,
            onTap: () => _patch((x) => x.copyWithWeekScope(null)),
          ),
          const SizedBox(width: 6),
          _chip(
            label: 'Sem. actual',
            selected: f.weekScope == CommissionSettlementWeekScope.current,
            onTap: () => _patch(
              (x) => x.copyWithWeekScope(CommissionSettlementWeekScope.current),
            ),
          ),
          const SizedBox(width: 6),
          _chip(
            label: 'Sem. anterior',
            selected: f.weekScope == CommissionSettlementWeekScope.previous,
            onTap: () => _patch(
              (x) =>
                  x.copyWithWeekScope(CommissionSettlementWeekScope.previous),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        _chipRow([
          _chip(
            label: 'Todo documento',
            selected: f.documentType == null,
            onTap: () => _patch((x) => x.copyWithDocumentType(null)),
          ),
          const SizedBox(width: 6),
          _chip(
            label: 'Factura fiscal',
            selected: f.documentType ==
                CommissionSettlementDocumentType.fiscalInvoice,
            onTap: () => _patch(
              (x) => x.copyWithDocumentType(
                CommissionSettlementDocumentType.fiscalInvoice,
              ),
            ),
          ),
          const SizedBox(width: 6),
          _chip(
            label: 'ML-NOT',
            selected: f.documentType ==
                CommissionSettlementDocumentType.deliveryNote,
            onTap: () => _patch(
              (x) => x.copyWithDocumentType(
                CommissionSettlementDocumentType.deliveryNote,
              ),
            ),
          ),
        ]),
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
