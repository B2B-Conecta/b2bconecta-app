import 'dart:async';

import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';
import 'package:motolink_pro_app/features/cart/cart_product_actions.dart';
import 'package:motolink_pro_app/features/cart/cart_service.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';

import 'aliado_catalog_reputation_filter_presets.dart';
import 'catalog_filters.dart';
import 'catalog_sort_mode.dart';
import 'part_model.dart';
import 'variant_cart_picker_sheet.dart';

/// Panel lateral del catálogo de escritorio. Aplica cada cambio al momento.
class AliadoCatalogWebSidebar extends StatefulWidget {
  const AliadoCatalogWebSidebar({
    super.key,
    required this.categories,
    required this.selectedCategory,
    required this.onCategory,
    required this.usdPromo,
    required this.shippingIncluded,
    required this.onUsdPromo,
    required this.onShippingIncluded,
    required this.minPrice,
    required this.maxPrice,
    required this.onPrice,
    required this.importers,
    required this.selectedImporterIds,
    required this.onToggleImporter,
    required this.onOpenStore,
    required this.estado,
    required this.ciudad,
    required this.onLocation,
    required this.minRating,
    required this.onRating,
    required this.minRatingCount,
    required this.onRatingCount,
  });

  final List<String> categories;
  final String selectedCategory;
  final ValueChanged<String> onCategory;
  final bool usdPromo;
  final bool shippingIncluded;
  final ValueChanged<bool> onUsdPromo;
  final ValueChanged<bool> onShippingIncluded;
  final TextEditingController minPrice;
  final TextEditingController maxPrice;
  final VoidCallback onPrice;
  final List<ImporterOption> importers;
  final Set<String> selectedImporterIds;
  final ValueChanged<String> onToggleImporter;
  final ValueChanged<String> onOpenStore;
  final TextEditingController estado;
  final TextEditingController ciudad;
  final VoidCallback onLocation;
  final double? minRating;
  final ValueChanged<double?> onRating;
  final int? minRatingCount;
  final ValueChanged<int?> onRatingCount;

  @override
  State<AliadoCatalogWebSidebar> createState() => _AliadoCatalogWebSidebarState();
}

class _AliadoCatalogWebSidebarState extends State<AliadoCatalogWebSidebar> {
  Timer? _priceTimer;

  @override
  void dispose() {
    _priceTimer?.cancel();
    super.dispose();
  }

  void _schedulePrice() {
    _priceTimer?.cancel();
    _priceTimer = Timer(const Duration(milliseconds: 380), widget.onPrice);
  }

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.surfaceCard,
        border: Border(right: BorderSide(color: theme.borderSubtle)),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 24),
        children: [
          Text(
            'Filtros',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: theme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _Section(
            title: 'Categoría',
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final label in widget.categories)
                  _ChoiceChip(
                    label: label,
                    selected: widget.selectedCategory == label,
                    onTap: () => widget.onCategory(label),
                  ),
              ],
            ),
          ),
          _Section(
            title: 'Condiciones rápidas',
            child: Column(
              children: [
                _CheckRow(
                  label: 'Solo promociones USD',
                  value: widget.usdPromo,
                  onChanged: widget.onUsdPromo,
                ),
                _CheckRow(
                  label: 'Envío incluido',
                  value: widget.shippingIncluded,
                  onChanged: widget.onShippingIncluded,
                ),
              ],
            ),
          ),
          _Section(
            title: 'Precio (REF)',
            child: Row(
              children: [
                Expanded(
                  child: _PriceField(
                    controller: widget.minPrice,
                    hint: 'Mínimo',
                    onChanged: _schedulePrice,
                    onSubmitted: widget.onPrice,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _PriceField(
                    controller: widget.maxPrice,
                    hint: 'Máximo',
                    onChanged: _schedulePrice,
                    onSubmitted: widget.onPrice,
                  ),
                ),
              ],
            ),
          ),
          _Section(
            title: 'Proveedores',
            child: _SupplierList(
              importers: widget.importers,
              selected: widget.selectedImporterIds,
              onToggle: widget.onToggleImporter,
              onOpenStore: widget.onOpenStore,
            ),
          ),
          _Section(
            title: 'Ubicación',
            initiallyExpanded: false,
            child: _LocationFields(
              importers: widget.importers,
              estado: widget.estado,
              ciudad: widget.ciudad,
              onChanged: widget.onLocation,
            ),
          ),
          _Section(
            title: 'Reputación',
            initiallyExpanded: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Promedio mínimo',
                  style: TextStyle(fontSize: 12, color: theme.textSecondary),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final preset in kAliadoCatalogMinRatingPresets)
                      if (preset.minAvg != null)
                        _ChoiceChip(
                          label: preset.label,
                          selected: widget.minRating == preset.minAvg,
                          onTap: () => widget.onRating(
                            widget.minRating == preset.minAvg ? null : preset.minAvg,
                          ),
                        ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Valoraciones',
                  style: TextStyle(fontSize: 12, color: theme.textSecondary),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final preset in kAliadoCatalogMinRatingCountPresets)
                      if (preset.minCount != null)
                        _ChoiceChip(
                          label: preset.label,
                          selected: widget.minRatingCount == preset.minCount,
                          onTap: () => widget.onRatingCount(
                            widget.minRatingCount == preset.minCount
                                ? null
                                : preset.minCount,
                          ),
                        ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AliadoCatalogWebToolbar extends StatelessWidget {
  const AliadoCatalogWebToolbar({
    super.key,
    required this.resultLabel,
    required this.chips,
    required this.filtersOpen,
    required this.onToggleFilters,
    required this.sortMode,
    required this.onSort,
    required this.onReset,
    required this.showReset,
  });

  final String resultLabel;
  final List<Widget> chips;
  final bool filtersOpen;
  final VoidCallback onToggleFilters;
  final CatalogSortMode sortMode;
  final ValueChanged<CatalogSortMode> onSort;
  final VoidCallback onReset;
  final bool showReset;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            resultLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: theme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (showReset)
                TextButton(
                  onPressed: onReset,
                  style: TextButton.styleFrom(
                    foregroundColor: B2BBrandHero.start,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 36),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Restablecer'),
                ),
              OutlinedButton.icon(
                onPressed: onToggleFilters,
                style: OutlinedButton.styleFrom(
                  foregroundColor:
                      filtersOpen ? B2BBrandHero.start : theme.textPrimary,
                  backgroundColor:
                      filtersOpen ? theme.brandContainer : theme.surfaceCard,
                  side: BorderSide(
                    color: filtersOpen ? B2BBrandHero.start : theme.borderSubtle,
                  ),
                  visualDensity: VisualDensity.compact,
                  minimumSize: const Size(0, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const LucideIcon(LucideGlyph.slidersHorizontal, size: 16),
                label: const Text('Filtros'),
              ),
              _SortMenu(mode: sortMode, onSelected: onSort),
              ...chips,
            ],
          ),
        ],
      ),
    );
  }
}

class AliadoCatalogWebChip extends StatelessWidget {
  const AliadoCatalogWebChip({
    super.key,
    required this.label,
    required this.onDeleted,
  });

  final String label;
  final VoidCallback onDeleted;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    return Material(
      color: theme.brandContainer,
      borderRadius: BorderRadius.circular(999),
      child: Padding(
        padding: const EdgeInsets.only(left: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 180),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: B2BBrandHero.start,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Quitar $label',
              onPressed: onDeleted,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              icon: const LucideIcon(
                LucideGlyph.close,
                size: 14,
                color: B2BBrandHero.start,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Agregar / En carrito del catálogo web, alineado con Inicio.
class AliadoCatalogWebAddButton extends StatelessWidget {
  const AliadoCatalogWebAddButton({
    super.key,
    required this.part,
    required this.profile,
  });

  final PartModel part;
  final ProfileModel profile;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final cart = CartService.instance;
    return ListenableBuilder(
      listenable: cart,
      builder: (context, _) {
        final added = CartProductActions.lineFor(part, cart) != null;
        final blocked = CartProductActions.blockReason(
          part: part,
          profile: profile,
          cart: cart,
        );
        final variants =
            part.hasVariantFamily || part.variantChoices.isNotEmpty;
        final unavailable = !part.isActive ||
            part.stockForSale < 1 ||
            part.stockForSale < part.minOrderQtyEffective ||
            profile.pedidosSuspendidosMorosidad ||
            cart.restoring;
        final label = added
            ? 'En carrito'
            : cart.restoring
                ? 'Recuperando…'
                : variants
                    ? 'Ver opciones'
                    : !part.isActive
                        ? 'Producto pausado'
                        : part.stockForSale < 1
                            ? 'Sin stock'
                            : part.stockForSale < part.minOrderQtyEffective
                                ? 'Stock insuficiente'
                                : profile.pedidosSuspendidosMorosidad
                                    ? 'Pedidos suspendidos'
                                    : blocked != null
                                        ? 'No disponible'
                                        : 'Agregar';
        final enabled = !added && !unavailable && blocked == null;
        return SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: !enabled
                ? null
                : variants
                    ? () => showVariantCartPickerSheet(
                          context: context,
                          part: part,
                          profile: profile,
                          cart: cart,
                        )
                    : () => CartProductActions.addMinimum(
                          part: part,
                          profile: profile,
                          cart: cart,
                        ),
            style: ButtonStyle(
              elevation: const WidgetStatePropertyAll(0),
              minimumSize: const WidgetStatePropertyAll(Size.fromHeight(40)),
              padding: const WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
              shape: const WidgetStatePropertyAll(
                RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                ),
              ),
              textStyle: const WidgetStatePropertyAll(
                TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (added) return theme.brandContainer;
                if (!enabled) return B2BBrandHero.start.withOpacity(0.35);
                if (states.contains(WidgetState.hovered)) {
                  return Color.lerp(B2BBrandHero.start, B2BBrandHero.end, .28);
                }
                return B2BBrandHero.start;
              }),
              foregroundColor: WidgetStatePropertyAll(
                added ? B2BBrandHero.start : B2BBrandHero.foreground,
              ),
              side: WidgetStatePropertyAll(
                added
                    ? BorderSide(color: B2BBrandHero.start.withOpacity(.55))
                    : BorderSide.none,
              ),
            ),
            icon: LucideIcon(
              added
                  ? LucideGlyph.check
                  : variants
                      ? LucideGlyph.arrowRight
                      : LucideGlyph.handbag,
              size: 16,
              color: added ? B2BBrandHero.start : B2BBrandHero.foreground,
            ),
            label: Text(label, overflow: TextOverflow.ellipsis),
          ),
        );
      },
    );
  }
}

class _Section extends StatefulWidget {
  const _Section({
    required this.title,
    required this.child,
    this.initiallyExpanded = true,
  });

  final String title;
  final Widget child;
  final bool initiallyExpanded;

  @override
  State<_Section> createState() => _SectionState();
}

class _SectionState extends State<_Section> {
  late bool _open = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _open = !_open),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: theme.textPrimary,
                      ),
                    ),
                  ),
                  LucideIcon(
                    _open ? LucideGlyph.chevronDown : LucideGlyph.chevronRight,
                    size: 16,
                    color: theme.textMuted,
                  ),
                ],
              ),
            ),
          ),
          if (_open) widget.child,
          const SizedBox(height: 4),
          Divider(height: 1, color: theme.borderSubtle),
        ],
      ),
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    return Material(
      color: selected ? B2BBrandHero.start : theme.surfaceCard,
      shape: StadiumBorder(
        side: BorderSide(
          color: selected ? B2BBrandHero.start : theme.borderSubtle,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected ? B2BBrandHero.foreground : theme.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: Checkbox(
                value: value,
                onChanged: (next) => onChanged(next ?? false),
                activeColor: B2BBrandHero.start,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: TextStyle(fontSize: 13, color: theme.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PriceField extends StatelessWidget {
  const _PriceField({
    required this.controller,
    required this.hint,
    required this.onChanged,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final String hint;
  final VoidCallback onChanged;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (_) => onChanged(),
      onSubmitted: (_) => onSubmitted(),
      style: TextStyle(fontSize: 13, color: theme.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        isDense: true,
        filled: true,
        fillColor: theme.inputFill,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        hintStyle: TextStyle(fontSize: 12, color: theme.textMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: theme.borderSubtle),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: theme.borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: B2BBrandHero.start),
        ),
      ),
    );
  }
}

class _SupplierList extends StatefulWidget {
  const _SupplierList({
    required this.importers,
    required this.selected,
    required this.onToggle,
    required this.onOpenStore,
  });

  final List<ImporterOption> importers;
  final Set<String> selected;
  final ValueChanged<String> onToggle;
  final ValueChanged<String> onOpenStore;

  @override
  State<_SupplierList> createState() => _SupplierListState();
}

class _SupplierListState extends State<_SupplierList> {
  final _query = TextEditingController();
  int _page = 0;
  static const _pageSize = 5;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final q = _query.text.trim().toLowerCase();
    final filtered = [
      for (final importer in widget.importers)
        if (q.isEmpty ||
            importer.businessName.toLowerCase().contains(q) ||
            (importer.estado ?? '').toLowerCase().contains(q) ||
            (importer.ciudad ?? '').toLowerCase().contains(q))
          importer,
    ];
    final pages = filtered.isEmpty ? 1 : ((filtered.length - 1) ~/ _pageSize) + 1;
    final page = _page.clamp(0, pages - 1);
    final start = page * _pageSize;
    final slice = filtered.skip(start).take(_pageSize).toList();
    final end = filtered.isEmpty ? 0 : start + slice.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _query,
          onChanged: (_) => setState(() => _page = 0),
          style: TextStyle(fontSize: 13, color: theme.textPrimary),
          decoration: InputDecoration(
            hintText: 'Buscar proveedor',
            isDense: true,
            filled: true,
            fillColor: theme.inputFill,
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 10, right: 4),
              child: LucideIcon(
                LucideGlyph.search,
                size: 15,
                color: theme.textMuted,
              ),
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 32,
              minHeight: 32,
              maxWidth: 34,
              maxHeight: 32,
            ),
            contentPadding: const EdgeInsets.only(right: 10, top: 10, bottom: 10),
            hintStyle: TextStyle(fontSize: 12, color: theme.textMuted),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: theme.borderSubtle),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: theme.borderSubtle),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: B2BBrandHero.start),
            ),
          ),
        ),
        const SizedBox(height: 6),
        if (slice.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Ningún proveedor coincide',
              style: TextStyle(fontSize: 12, color: theme.textSecondary),
            ),
          )
        else
          for (final importer in slice)
            Row(
              children: [
                SizedBox(
                  width: 28,
                  height: 32,
                  child: Checkbox(
                    value: widget.selected.contains(importer.id),
                    onChanged: (_) => widget.onToggle(importer.id),
                    activeColor: B2BBrandHero.start,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () => widget.onToggle(importer.id),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(
                        importer.businessName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12.5, color: theme.textPrimary),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Ver tienda',
                  onPressed: () => widget.onOpenStore(importer.id),
                  visualDensity: VisualDensity.compact,
                  icon: LucideIcon(
                    LucideGlyph.store,
                    size: 16,
                    color: theme.textSecondary,
                  ),
                ),
              ],
            ),
        if (filtered.length > _pageSize)
          Row(
            children: [
              Text(
                'Mostrando ${start + 1}–$end de ${filtered.length}',
                style: TextStyle(fontSize: 11, color: theme.textSecondary),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Anterior',
                onPressed: page == 0 ? null : () => setState(() => _page = page - 1),
                visualDensity: VisualDensity.compact,
                icon: const LucideIcon(LucideGlyph.chevronLeft, size: 16),
              ),
              Text(
                '${page + 1} / $pages',
                style: TextStyle(fontSize: 12, color: theme.textPrimary),
              ),
              IconButton(
                tooltip: 'Siguiente',
                onPressed: page >= pages - 1
                    ? null
                    : () => setState(() => _page = page + 1),
                visualDensity: VisualDensity.compact,
                icon: const LucideIcon(LucideGlyph.chevronRight, size: 16),
              ),
            ],
          ),
      ],
    );
  }
}

class _LocationFields extends StatelessWidget {
  const _LocationFields({
    required this.importers,
    required this.estado,
    required this.ciudad,
    required this.onChanged,
  });

  final List<ImporterOption> importers;
  final TextEditingController estado;
  final TextEditingController ciudad;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final estados = {
      for (final importer in importers)
        if ((importer.estado ?? '').trim().isNotEmpty) importer.estado!.trim(),
    }.toList()
      ..sort();
    final selectedEstado = estado.text.trim();
    final ciudades = {
      for (final importer in importers)
        if ((importer.ciudad ?? '').trim().isNotEmpty &&
            (selectedEstado.isEmpty ||
                (importer.estado ?? '').trim() == selectedEstado))
          importer.ciudad!.trim(),
    }.toList()
      ..sort();
    return Column(
      children: [
        _Picker(
          hint: 'Estado',
          value: selectedEstado.isEmpty ? null : selectedEstado,
          options: estados,
          onChanged: (value) {
            estado.text = value ?? '';
            final allowed = {
              for (final importer in importers)
                if ((importer.ciudad ?? '').trim().isNotEmpty &&
                    (value == null ||
                        value.isEmpty ||
                        (importer.estado ?? '').trim() == value))
                  importer.ciudad!.trim(),
            };
            if (ciudad.text.trim().isNotEmpty &&
                !allowed.contains(ciudad.text.trim())) {
              ciudad.clear();
            }
            onChanged();
          },
        ),
        const SizedBox(height: 8),
        _Picker(
          hint: 'Ciudad',
          value: ciudad.text.trim().isEmpty ? null : ciudad.text.trim(),
          options: ciudades,
          onChanged: (value) {
            ciudad.text = value ?? '';
            onChanged();
          },
        ),
      ],
    );
  }
}

class _Picker extends StatelessWidget {
  const _Picker({
    required this.hint,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String hint;
  final String? value;
  final List<String> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final items = value != null && !options.contains(value) ? [value!, ...options] : options;
    return DropdownButtonFormField<String?>(
      value: value,
      isExpanded: true,
      hint: Text(hint, style: TextStyle(fontSize: 13, color: theme.textMuted)),
      items: [
        DropdownMenuItem<String?>(
          value: null,
          child: Text(hint, style: TextStyle(fontSize: 13, color: theme.textMuted)),
        ),
        for (final option in items)
          DropdownMenuItem<String?>(
            value: option,
            child: Text(
              option,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: theme.textPrimary),
            ),
          ),
      ],
      onChanged: onChanged,
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: theme.inputFill,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: theme.borderSubtle),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: theme.borderSubtle),
        ),
      ),
    );
  }
}

class _SortMenu extends StatelessWidget {
  const _SortMenu({required this.mode, required this.onSelected});

  final CatalogSortMode mode;
  final ValueChanged<CatalogSortMode> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    return PopupMenuButton<CatalogSortMode>(
      tooltip: 'Ordenar por',
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final option in CatalogSortMode.values)
          PopupMenuItem(
            value: option,
            child: Text(option.labelEs),
          ),
      ],
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.surfaceCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: theme.borderSubtle),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Ordenar por',
                style: TextStyle(fontSize: 12, color: theme.textSecondary),
              ),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 120),
                child: Text(
                  mode.labelEs,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: theme.textPrimary,
                  ),
                ),
              ),
              LucideIcon(
                LucideGlyph.chevronDown,
                size: 16,
                color: theme.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
