import 'package:flutter/material.dart';

import '../models/aliado_catalog_filters_draft.dart';
import '../models/catalog_filters.dart';
import '../theme/app_theme.dart';

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
  });

  final AliadoCatalogFiltersDraft initial;
  final List<ImporterOption> importers;
  final ScrollController scrollController;

  static Future<AliadoCatalogFiltersDraft?> show(
    BuildContext context, {
    required AliadoCatalogFiltersDraft initial,
    required List<ImporterOption> importers,
  }) {
    return showModalBottomSheet<AliadoCatalogFiltersDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.88,
        minChildSize: 0.45,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => AliadoCatalogFiltersSheet(
          initial: initial,
          importers: importers,
          scrollController: scrollController,
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
  bool _closestToMe = false;
  String _importerQuery = '';

  @override
  void initState() {
    super.initState();
    _category = widget.initial.categoryLabel;
    _importerIds = Set<String>.from(widget.initial.importerIds);
    _closestToMe = widget.initial.closestToMe;
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
      closestToMe: _closestToMe,
    );
  }

  void _resetPanel() {
    setState(() {
      _category = 'Todos';
      _importerIds.clear();
      _closestToMe = false;
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

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
          color: AppColors.textSecondary,
        ),
      ),
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

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewPadding.bottom;
    final visible = _visibleImporters;
    final importerSummary = _importerIds.isEmpty
        ? 'Todos'
        : '${_importerIds.length} seleccionado${_importerIds.length == 1 ? '' : 's'}';

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
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Filtros',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Categoría, ubicación, precio, proveedores y orden.',
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
                _sectionTitle('CATEGORÍA'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: kAliadoCatalogCategoryLabels.map((label) {
                    final selected = _category == label;
                    return FilterChip(
                      label: Text(label),
                      selected: selected,
                      onSelected: (_) => setState(() => _category = label),
                      selectedColor: AppColors.brandOrange,
                      checkmarkColor: Colors.white,
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: selected ? Colors.white : AppColors.textPrimary,
                      ),
                      backgroundColor: Colors.grey.shade200,
                      side: BorderSide.none,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    );
                  }).toList(),
                ),
                _sectionTitle('ORDEN'),
                SwitchListTile(
                  value: _closestToMe,
                  onChanged: (v) => setState(() => _closestToMe = v),
                  contentPadding: EdgeInsets.zero,
                  activeColor: AppColors.brandOrange,
                  title: const Text(
                    'Más cercanos a mí',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: const Text(
                    'Usa tu ubicación para ordenar por distancia al almacén.',
                    style: TextStyle(fontSize: 12),
                  ),
                  secondary: const Icon(Icons.near_me_outlined),
                ),
                _sectionTitle('UBICACIÓN DEL PROVEEDOR'),
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
                _sectionTitle('PRECIO (REF)'),
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
                _sectionTitle('PROVEEDORES · $importerSummary'),
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
                      style: const TextStyle(
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
                      activeColor: AppColors.brandOrange,
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
                    );
                  }),
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
