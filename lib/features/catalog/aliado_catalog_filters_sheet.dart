import 'package:flutter/material.dart';

import 'aliado_catalog_filters_draft.dart';
import 'aliado_catalog_reputation_filter_presets.dart';
import 'catalog_filters.dart';
import 'catalog_sort_mode.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';

/// Categorías rápidas del catálogo (tokens de búsqueda en [home_screen]).
const kAliadoCatalogCategoryLabels = <String>[
  'Todos',
  'Frenos',
  'Transmisión',
  'Motor',
  'Eléctrico',
];

/// Panel único de filtros del catálogo aliado.
class AliadoCatalogFiltersSheet extends StatefulWidget {
  const AliadoCatalogFiltersSheet({
    super.key,
    required this.initial,
    required this.importers,
    required this.scrollController,
    this.onOpenImporterStore,
  });

  final AliadoCatalogFiltersDraft initial;
  final List<ImporterOption> importers;
  final ScrollController scrollController;
  final ValueChanged<String>? onOpenImporterStore;

  static Future<AliadoCatalogFiltersDraft?> show(
    BuildContext context, {
    required AliadoCatalogFiltersDraft initial,
    required List<ImporterOption> importers,
    ValueChanged<String>? onOpenImporterStore,
  }) {
    return showModalBottomSheet<AliadoCatalogFiltersDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.96,
        expand: false,
        builder: (_, scrollController) => AliadoCatalogFiltersSheet(
          initial: initial,
          importers: importers,
          scrollController: scrollController,
          onOpenImporterStore: onOpenImporterStore,
        ),
      ),
    );
  }

  @override
  State<AliadoCatalogFiltersSheet> createState() =>
      _AliadoCatalogFiltersSheetState();
}

class _AliadoCatalogFiltersSheetState extends State<AliadoCatalogFiltersSheet> {
  late String _category;
  late Set<String> _importerIds;
  late final TextEditingController _estadoController;
  late final TextEditingController _ciudadController;
  late final TextEditingController _minPriceController;
  late final TextEditingController _maxPriceController;
  late final TextEditingController _importerSearchController;
  late CatalogSortMode _sortMode;
  double? _minRatingAvg;
  int? _minRatingCount;
  late bool _onlyWithCommercialDiscount;
  String _importerQuery = '';

  @override
  void initState() {
    super.initState();
    _category = widget.initial.categoryLabel;
    _importerIds = Set<String>.from(widget.initial.importerIds);
    _sortMode = widget.initial.sortMode;
    _minRatingAvg = widget.initial.minOwnerRatingAvg;
    _minRatingCount = widget.initial.minOwnerRatingCount;
    _onlyWithCommercialDiscount = widget.initial.onlyWithCommercialDiscount;
    _estadoController = TextEditingController(text: widget.initial.ownerEstado);
    _ciudadController = TextEditingController(text: widget.initial.ownerCiudad);
    _minPriceController = TextEditingController(text: widget.initial.minPrice);
    _maxPriceController = TextEditingController(text: widget.initial.maxPrice);
    _importerSearchController = TextEditingController();
    _importerSearchController.addListener(() {
      setState(
        () => _importerQuery = _importerSearchController.text.trim().toLowerCase(),
      );
    });
  }

  @override
  void dispose() {
    _estadoController.dispose();
    _ciudadController.dispose();
    _minPriceController.dispose();
    _maxPriceController.dispose();
    _importerSearchController.dispose();
    super.dispose();
  }

  AliadoCatalogFiltersDraft _buildDraft() {
    return AliadoCatalogFiltersDraft(
      categoryLabel: _category,
      importerIds: Set<String>.from(_importerIds),
      ownerEstado: _estadoController.text,
      ownerCiudad: _ciudadController.text,
      minPrice: _minPriceController.text,
      maxPrice: _maxPriceController.text,
      sortMode: _sortMode,
      minOwnerRatingAvg: _minRatingAvg,
      minOwnerRatingCount: _minRatingCount,
      onlyWithCommercialDiscount: _onlyWithCommercialDiscount,
    );
  }

  void _resetPanel() {
    setState(() {
      _category = 'Todos';
      _importerIds.clear();
      _sortMode = CatalogSortMode.defaultMode;
      _minRatingAvg = null;
      _minRatingCount = null;
      _onlyWithCommercialDiscount = false;
      _estadoController.clear();
      _ciudadController.clear();
      _minPriceController.clear();
      _maxPriceController.clear();
      _importerSearchController.clear();
    });
  }

  List<ImporterOption> get _visibleImporters {
    if (_importerQuery.isEmpty) return widget.importers;
    return widget.importers.where((o) {
      final haystack = [
        o.businessName,
        o.estado,
        o.ciudad,
      ].whereType<String>().join(' ').toLowerCase();
      return haystack.contains(_importerQuery);
    }).toList();
  }

  Widget _sectionHeader(String title, {IconData? icon, String? hint}) {
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.brandBlueContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: AppColors.brandBlue),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
                if (hint != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    hint,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _choiceChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: true,
      selectedColor: AppColors.brandBlue,
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 13,
        color: selected ? Colors.white : AppColors.textPrimary,
      ),
      backgroundColor: AppColors.surfaceTinted,
      side: BorderSide(
        color: selected ? AppColors.brandBlue : AppColors.borderSubtle,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
    );
  }

  InputDecoration _fieldDecoration({
    required String label,
    String? hint,
    IconData? icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon == null ? null : Icon(icon, size: 22),
      filled: true,
      fillColor: AppColors.fieldFill,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      isDense: true,
    );
  }

  Widget _sortCard(CatalogSortMode mode) {
    final selected = _sortMode == mode;
    return Material(
      color: selected ? AppColors.brandBlueContainer : AppColors.surfaceTinted,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => setState(() => _sortMode = mode),
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? AppColors.brandBlue.withOpacity(0.55)
                  : AppColors.borderSubtle,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: selected ? AppColors.brandBlue : AppColors.card,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  mode.iconData,
                  color: selected ? Colors.white : AppColors.brandBlue,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mode.labelEs,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      mode.subtitleEs,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: selected ? AppColors.brandBlue : AppColors.textMuted,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewPadding.bottom;
    final visible = _visibleImporters;
    final importerSummary = _importerIds.isEmpty
        ? 'Todos'
        : '${_importerIds.length} seleccionado${_importerIds.length == 1 ? '' : 's'}';

    return Material(
      color: Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Filtros',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 22,
                              letterSpacing: -0.4,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Afiná el catálogo por categoría, orden y proveedor.',
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.35,
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
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              children: [
                _sectionHeader(
                  'Categoría',
                  icon: Icons.category_outlined,
                  hint: 'Elige un rubro o mira todos los productos.',
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: kAliadoCatalogCategoryLabels.map((label) {
                    return _choiceChip(
                      label: label,
                      selected: _category == label,
                      onTap: () => setState(() => _category = label),
                    );
                  }).toList(),
                ),
                _sectionHeader(
                  'Orden',
                  icon: Icons.swap_vert_rounded,
                  hint: 'Cómo se listan los productos en el catálogo.',
                ),
                for (final mode in CatalogSortMode.values) ...[
                  _sortCard(mode),
                  const SizedBox(height: 8),
                ],
                _sectionHeader(
                  'Reputación del proveedor',
                  icon: Icons.star_outline_rounded,
                  hint:
                      'Solo productos de importadores que cumplan el umbral (últ. 100 valoraciones).',
                ),
                Text(
                  'Promedio mínimo',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: kAliadoCatalogMinRatingPresets.map((preset) {
                    return _choiceChip(
                      label: preset.label,
                      selected: _minRatingAvg == preset.minAvg,
                      onTap: () => setState(() => _minRatingAvg = preset.minAvg),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                Text(
                  'Cantidad mínima de valoraciones',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: kAliadoCatalogMinRatingCountPresets.map((preset) {
                    return _choiceChip(
                      label: preset.label,
                      selected: _minRatingCount == preset.minCount,
                      onTap: () =>
                          setState(() => _minRatingCount = preset.minCount),
                    );
                  }).toList(),
                ),
                _sectionHeader(
                  'Ubicación del proveedor',
                  icon: Icons.place_outlined,
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _estadoController,
                        textCapitalization: TextCapitalization.words,
                        decoration: _fieldDecoration(
                          label: 'Estado',
                          hint: 'Ej. Miranda',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _ciudadController,
                        textCapitalization: TextCapitalization.words,
                        decoration: _fieldDecoration(
                          label: 'Ciudad',
                          hint: 'Ej. Valencia',
                        ),
                      ),
                    ),
                  ],
                ),
                _sectionHeader(
                  'Descuentos',
                  icon: Icons.local_offer_outlined,
                  hint:
                      'Oferta directa, volumen o % extra en la línea USD (Zelle/divisas).',
                ),
                _choiceChip(
                  label: 'Solo con descuentos',
                  selected: _onlyWithCommercialDiscount,
                  onTap: () => setState(
                    () => _onlyWithCommercialDiscount =
                        !_onlyWithCommercialDiscount,
                  ),
                ),
                _sectionHeader(
                  'Precio (REF)',
                  icon: Icons.payments_outlined,
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _minPriceController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: _fieldDecoration(label: 'Mínimo'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _maxPriceController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: _fieldDecoration(label: 'Máximo'),
                      ),
                    ),
                  ],
                ),
                _sectionHeader(
                  'Proveedores · $importerSummary',
                  icon: Icons.storefront_outlined,
                  hint: 'Filtra por mayorista o abre su vitrina.',
                ),
                TextField(
                  controller: _importerSearchController,
                  decoration: _fieldDecoration(
                    label: 'Buscar',
                    hint: 'Nombre o ciudad…',
                    icon: Icons.search,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    TextButton(
                      onPressed: visible.isEmpty
                          ? null
                          : () {
                              setState(() {
                                for (final o in visible) {
                                  _importerIds.add(o.id);
                                }
                              });
                            },
                      child: const Text(
                        'Marcar visibles',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _importerIds.isEmpty
                          ? null
                          : () => setState(() => _importerIds.clear()),
                      child: const Text(
                        'Quitar selección',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                if (visible.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      widget.importers.isEmpty
                          ? 'No hay proveedores disponibles.'
                          : 'Ningún proveedor coincide con la búsqueda.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  )
                else
                  ...visible.map((o) {
                    final checked = _importerIds.contains(o.id);
                    return CheckboxListTile(
                      value: checked,
                      onChanged: (v) {
                        setState(() {
                          if (v == true) {
                            _importerIds.add(o.id);
                          } else {
                            _importerIds.remove(o.id);
                          }
                        });
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      activeColor: AppColors.brand,
                      title: Text(
                        o.businessName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        o.ubicacionLine,
                        style: const TextStyle(fontSize: 12),
                      ),
                      secondary: widget.onOpenImporterStore == null
                          ? null
                          : IconButton(
                              tooltip: 'Ver perfil',
                              icon: const Icon(Icons.storefront_outlined),
                              onPressed: () =>
                                  widget.onOpenImporterStore!(o.id),
                            ),
                    );
                  }),
                SizedBox(height: bottom + 8),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppColors.borderSubtle)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            padding: EdgeInsets.fromLTRB(20, 12, 20, bottom + 16),
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
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
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
