import 'package:flutter/material.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';

import 'commission_settlement_filter_utils.dart';
import 'commission_settlement_list_filter_bar.dart';

class CommissionSettlementFiltersSheet extends StatefulWidget {
  const CommissionSettlementFiltersSheet({
    super.key,
    required this.initial,
    required this.importadorOptions,
  });

  final CommissionSettlementFilters initial;
  final List<CommissionSettlementImporterOption> importadorOptions;

  static Future<CommissionSettlementFilters?> show(
    BuildContext context, {
    required CommissionSettlementFilters initial,
    required List<CommissionSettlementImporterOption> importadorOptions,
  }) async {
    return showModalBottomSheet<CommissionSettlementFilters?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.45,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: CommissionSettlementFiltersSheet(
            initial: initial,
            importadorOptions: importadorOptions,
          ),
        ),
      ),
    );
  }

  @override
  State<CommissionSettlementFiltersSheet> createState() =>
      _CommissionSettlementFiltersSheetState();
}

class _CommissionSettlementFiltersSheetState
    extends State<CommissionSettlementFiltersSheet> {
  late CommissionSettlementFilters _draft;
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _draft = widget.initial;
    _searchController = TextEditingController(text: widget.initial.searchQuery);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasFilters = _draft.hasActiveFilters;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 5,
            decoration: BoxDecoration(
              color: AppColors.borderSubtle,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Filtros de cortes',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
              if (hasFilters)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Activos',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          CommissionSettlementListFilterBar(
            searchController: _searchController,
            filters: _draft,
            importadorOptions: widget.importadorOptions,
            onFiltersChanged: (f) => setState(() => _draft = f),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              OutlinedButton(
                onPressed: () => Navigator.pop(context, null),
                child: const Text('Cancelar'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, _draft),
                  child: const Text('Aplicar filtros'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

