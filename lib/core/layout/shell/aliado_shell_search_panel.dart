import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';
import 'package:motolink_pro_app/features/cart/cart_product_actions.dart';
import 'package:motolink_pro_app/features/cart/cart_service.dart';
import 'package:motolink_pro_app/features/catalog/part_model.dart';
import 'package:motolink_pro_app/features/catalog/product_catalog_pricing.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';

import 'aliado_shell_search_model.dart';

/// Panel flotante del buscador web. No lo usa el panel móvil.
class AliadoShellSearchPanel extends StatefulWidget {
  const AliadoShellSearchPanel({
    super.key,
    required this.query,
    required this.items,
    required this.highlight,
    required this.loading,
    required this.error,
    required this.profile,
    required this.onActivate,
    required this.onClearRecents,
    required this.onAdd,
    required this.maxHeight,
  });

  final String query;
  final List<AliadoShellSearchItem> items;
  final int highlight;
  final bool loading;
  final String? error;
  final ProfileModel? profile;
  final ValueChanged<int> onActivate;
  final VoidCallback onClearRecents;
  final ValueChanged<PartModel> onAdd;
  final double maxHeight;

  @override
  State<AliadoShellSearchPanel> createState() => _AliadoShellSearchPanelState();
}

class _AliadoShellSearchPanelState extends State<AliadoShellSearchPanel> {
  final _keys = <int, GlobalKey>{};

  GlobalKey _keyFor(int index) => _keys.putIfAbsent(index, GlobalKey.new);

  @override
  void didUpdateWidget(AliadoShellSearchPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.highlight == widget.highlight || widget.highlight < 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final target = _keys[widget.highlight]?.currentContext;
      if (target == null) return;
      Scrollable.ensureVisible(target, alignment: 0.4);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final query = widget.query.trim();
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: widget.maxHeight),
      child: DecoratedBox(
      decoration: BoxDecoration(
        color: theme.dialogSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.borderSubtle),
        boxShadow: [
          BoxShadow(
            color: theme.textPrimary.withOpacity(0.10),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          shrinkWrap: true,
          children: [
            if (widget.loading && query.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: LinearProgressIndicator(
                  minHeight: 2,
                  color: B2BBrandHero.start,
                  backgroundColor: theme.brandContainer,
                ),
              ),
            if (widget.error != null && query.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  widget.error!,
                  style: TextStyle(fontSize: 12.5, color: theme.textSecondary),
                ),
              ),
            ..._sections(theme),
          ],
        ),
      ),
      ),
    );
  }

  List<Widget> _sections(B2BThemeExtension theme) {
    final children = <Widget>[];
    final chipRun = <int>[];
    var productHeader = false;
    var placeHeader = false;
    final query = widget.query.trim();

    void flushChips(String title, {Widget? trailing}) {
      if (chipRun.isEmpty) return;
      if (title.isNotEmpty) {
        children.add(_header(theme, title, trailing: trailing));
      }
      children.add(Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final index in chipRun)
              _chip(
                theme,
                index,
                widget.items[index].label,
                index == widget.highlight,
              ),
          ],
        ),
      ));
      chipRun.clear();
    }

    for (var index = 0; index < widget.items.length; index++) {
      final item = widget.items[index];
      final selected = index == widget.highlight;
      switch (item.kind) {
        case AliadoShellSearchKind.recent:
          chipRun.add(index);
          if (index + 1 >= widget.items.length ||
              widget.items[index + 1].kind != AliadoShellSearchKind.recent) {
            flushChips(
              'Búsquedas recientes',
              trailing: TextButton(
                onPressed: widget.onClearRecents,
                child: Text(
                  'Limpiar',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: theme.brand,
                  ),
                ),
              ),
            );
          }
        case AliadoShellSearchKind.suggested:
          chipRun.add(index);
          if (index + 1 >= widget.items.length ||
              widget.items[index + 1].kind != AliadoShellSearchKind.suggested) {
            flushChips('Búsquedas sugeridas');
          }
        case AliadoShellSearchKind.completion:
          chipRun.add(index);
          if (index + 1 >= widget.items.length ||
              widget.items[index + 1].kind !=
                  AliadoShellSearchKind.completion) {
            flushChips('Sugerencias rápidas');
          }
        case AliadoShellSearchKind.product:
          flushChips('');
          if (!productHeader) {
            productHeader = true;
            children.add(_header(theme, 'Repuestos'));
          }
          children.add(_product(theme, index, item.part!, selected));
        case AliadoShellSearchKind.supplier:
          flushChips('');
          if (!placeHeader) {
            placeHeader = true;
            children.add(_header(theme, 'Proveedores y categorías'));
          }
          children.add(_place(
            theme,
            index,
            item.label,
            item.supplier?.ubicacionLine ?? 'Ver catálogo del proveedor',
            LucideGlyph.store,
            selected,
          ));
        case AliadoShellSearchKind.category:
          if (query.isEmpty) {
            chipRun.add(index);
            if (index + 1 >= widget.items.length ||
                widget.items[index + 1].kind !=
                    AliadoShellSearchKind.category) {
              flushChips('Categorías');
            }
          } else {
            flushChips('');
            if (!placeHeader) {
              placeHeader = true;
              children.add(_header(theme, 'Proveedores y categorías'));
            }
            children.add(_place(
              theme,
              index,
              item.label,
              'Ver repuestos de esta categoría',
              LucideGlyph.layoutGrid,
              selected,
            ));
          }
        case AliadoShellSearchKind.seeAll:
          flushChips('');
          children.add(_seeAll(theme, index, item.label, selected));
      }
    }
    flushChips('');
    if (query.isNotEmpty &&
        !widget.loading &&
        widget.items.every((item) => item.kind == AliadoShellSearchKind.seeAll)) {
      children.insert(
        0,
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            'Sin coincidencias para «$query»',
            style: TextStyle(fontSize: 12.5, color: theme.textSecondary),
          ),
        ),
      );
    }
    return children;
  }

  Widget _header(B2BThemeExtension theme, String label, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: theme.textSecondary,
              ),
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _chip(
    B2BThemeExtension theme,
    int index,
    String label,
    bool selected,
  ) {
    return Semantics(
      key: _keyFor(index),
      selected: selected,
      button: true,
      child: Material(
            key: selected ? const Key('aliado-shell-search-active') : null,
            color: selected ? theme.brandContainer : theme.surfaceSubtle,
            borderRadius: BorderRadius.circular(999),
            child: InkWell(
              onTap: () => widget.onActivate(index),
              borderRadius: BorderRadius.circular(999),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                child: Text.rich(
                  TextSpan(
                    children: [
                      for (final piece
                          in aliadoSearchHighlightPieces(label, widget.query))
                        TextSpan(
                          text: piece.text,
                          style: TextStyle(
                            fontWeight:
                                piece.match ? FontWeight.w800 : FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                  style: TextStyle(
                    fontSize: 12.5,
                    color: selected ? theme.brand : theme.textPrimary,
                  ),
                ),
              ),
            ),
          ),
    );
  }

  Widget _place(
    B2BThemeExtension theme,
    int index,
    String title,
    String subtitle,
    LucideGlyph glyph,
    bool selected,
  ) {
    return Padding(
      key: _keyFor(index),
      padding: const EdgeInsets.only(bottom: 4),
      child: _rowShell(
        theme: theme,
        selected: selected,
        onTap: () => widget.onActivate(index),
        child: Row(
          children: [
            LucideIcon(glyph, size: 16, color: theme.textSecondary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        for (final piece
                            in aliadoSearchHighlightPieces(title, widget.query))
                          TextSpan(
                            text: piece.text,
                            style: TextStyle(
                              fontWeight: piece.match
                                  ? FontWeight.w800
                                  : FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: theme.textPrimary),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.5, color: theme.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _product(
    B2BThemeExtension theme,
    int index,
    PartModel part,
    bool selected,
  ) {
    final brand = aliadoPartBrand(part);
    final sku = part.sku?.trim();
    final supplier = part.ownerBusinessName?.trim();
    final meta = [
      if (sku != null && sku.isNotEmpty) sku,
      if (brand != null) brand,
      if (supplier != null && supplier.isNotEmpty) supplier,
    ].join(' · ');
    final usd = ProductCatalogPricing.aliadoUnitUsdPaymentLine(
      refUnitUsd: part.precio,
      salePriceUsd: part.salePriceUsd,
      discountRules: part.discountRules,
      ownerPagoSoloDivisas: part.ownerPagoSoloDivisas,
    );
    return Padding(
      key: _keyFor(index),
      padding: const EdgeInsets.only(bottom: 4),
      child: _rowShell(
        theme: theme,
        selected: selected,
        onTap: () => widget.onActivate(index),
        child: Row(
          children: [
            _thumb(theme, part),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        for (final piece in aliadoSearchHighlightPieces(
                          part.nombre,
                          widget.query,
                        ))
                          TextSpan(
                            text: piece.text,
                            style: TextStyle(
                              fontWeight: piece.match
                                  ? FontWeight.w800
                                  : FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: theme.textPrimary),
                  ),
                  if (meta.isNotEmpty)
                    Text.rich(
                      TextSpan(
                        children: [
                          for (final piece
                              in aliadoSearchHighlightPieces(meta, widget.query))
                            TextSpan(
                              text: piece.text,
                              style: TextStyle(
                                fontWeight: piece.match
                                    ? FontWeight.w800
                                    : FontWeight.w500,
                              ),
                            ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11.5, color: theme.textSecondary),
                    ),
                  const SizedBox(height: 2),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '${usd.toStringAsFixed(2)} USD',
                          style: TextStyle(
                            color: theme.successFg,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (!part.ownerPagoSoloDivisas)
                          TextSpan(
                            text: '   ${part.precio.toStringAsFixed(2)} REF',
                            style: TextStyle(
                              color: theme.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12.5),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _addButton(theme, part),
          ],
        ),
      ),
    );
  }

  Widget _addButton(B2BThemeExtension theme, PartModel part) {
    final profile = widget.profile;
    final cart = CartService.instance;
    final line = CartProductActions.lineFor(part, cart);
    final blocked = profile == null
        ? 'Inicia sesión para agregar productos.'
        : CartProductActions.blockReason(
            part: part,
            profile: profile,
            cart: cart,
          );
    final inCart = line != null;
    final enabled = profile != null && !inCart && blocked == null;
    final label = inCart ? 'En carrito' : '+ Agregar';
    return FilledButton(
        onPressed: enabled ? () => widget.onAdd(part) : null,
      style: FilledButton.styleFrom(
        elevation: 0,
        backgroundColor: inCart ? theme.brandContainer : B2BBrandHero.start,
        foregroundColor:
            inCart ? B2BBrandHero.start : B2BBrandHero.foreground,
        disabledBackgroundColor:
            inCart ? theme.brandContainer : theme.surfaceSubtle,
        disabledForegroundColor: inCart ? B2BBrandHero.start : theme.textMuted,
        minimumSize: const Size(0, 32),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(label),
    );
  }

  Widget _thumb(B2BThemeExtension theme, PartModel part) {
    final url = part.coverImageUrl?.trim();
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: ColoredBox(
        color: theme.inputFill,
        child: SizedBox(
          width: 46,
          height: 46,
          child: url == null || url.isEmpty
              ? _thumbFallback(theme)
              : Image.network(
                  url,
                  fit: BoxFit.contain,
                  excludeFromSemantics: true,
                  errorBuilder: (_, __, ___) => _thumbFallback(theme),
                ),
        ),
      ),
    );
  }

  Widget _thumbFallback(B2BThemeExtension theme) {
    return Center(
      child: LucideIcon(LucideGlyph.image, size: 18, color: theme.textMuted),
    );
  }

  Widget _seeAll(
    B2BThemeExtension theme,
    int index,
    String query,
    bool selected,
  ) {
    return Padding(
      key: _keyFor(index),
      padding: const EdgeInsets.only(top: 4),
      child: Semantics(
        selected: selected,
        button: true,
        child: Material(
          key: selected ? const Key('aliado-shell-search-active') : null,
          color: selected ? theme.brandContainer : theme.dialogSurface,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: () => widget.onActivate(index),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: Text(
                'Ver todos los resultados para «$query» en Catálogo →',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: theme.brand,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _rowShell({
    required B2BThemeExtension theme,
    required bool selected,
    required VoidCallback onTap,
    required Widget child,
  }) {
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        key: selected ? const Key('aliado-shell-search-active') : null,
        color: selected ? theme.brandContainer : theme.dialogSurface,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: child,
          ),
        ),
      ),
    );
  }
}
