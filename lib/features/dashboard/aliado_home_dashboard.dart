import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../core/widgets/aliado_header_search.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';

import '../../app/main_shell_tab.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/b2b_theme_extension.dart';
import '../../core/widgets/ios_chrome.dart';
import '../../core/data/supabase_service.dart';
import '../../core/widgets/bandeja_sheet.dart';
import '../../core/widgets/bcv_rate_badge.dart';
import '../onboarding/retailer_induction.dart';
import '../cart/cart_screen.dart';
import '../cart/cart_service.dart';
import '../cart/cart_product_actions.dart';
import '../cart/catalog_cart_bar.dart';
import '../catalog/aliado_catalog_categories.dart';
import '../catalog/aliado_promo_campaign_widgets.dart';
import '../catalog/aliado_promo_campaign_navigation.dart';
import '../catalog/favorite_heart_button.dart';
import '../catalog/product_stock_summary.dart';
import '../catalog/catalog_category_icon.dart';
import '../catalog/catalog_product_price_display.dart';
import '../catalog/catalog_service.dart';
import '../catalog/catalog_filters.dart';
import '../catalog/catalog_taxonomy.dart';
import '../catalog/catalog_route_lock.dart';
import '../catalog/importer_store_profile_screen.dart';
import '../catalog/supplier_directory_screen.dart';
import '../catalog/part_model.dart';
import '../catalog/product_detail_screen.dart';
import '../catalog/promo_banner_layout.dart';
import '../catalog/promo_campaign_model.dart';
import '../catalog/recent_product_views.dart';
import '../catalog/new_consultation_screen.dart';
import '../inventory/product_custom_fields.dart';
import '../onboarding/entrepreneur_first_purchase_warning_banner.dart';
import '../onboarding/entrepreneur_rail_status_card.dart';
import '../profile/profile_model.dart';
import 'aliado_home_service.dart';
import 'aliado_home_header.dart';

part 'aliado_home_mobile.dart';
part 'aliado_home_web.dart';

/// Descubrimiento y recompra. El catálogo conserva búsqueda y filtros completos.
class AliadoHomeDashboard extends StatefulWidget {
  const AliadoHomeDashboard(
      {super.key,
      required this.profile,
      this.embedInDesktopShell = false,
      this.isActiveTab = true,
      this.onNotificationTap,
      this.onMessagesTap,
      this.unreadNotifications = 0,
      this.unreadMessages = 0,
      this.loader});
  final ProfileModel profile;
  final bool embedInDesktopShell;
  final bool isActiveTab;
  final VoidCallback? onNotificationTap;
  final VoidCallback? onMessagesTap;
  final int unreadNotifications;
  final int unreadMessages;
  final Future<AliadoHomeData> Function()? loader;

  @override
  State<AliadoHomeDashboard> createState() => _AliadoHomeDashboardState();
}

class _AliadoHomeDashboardState extends State<AliadoHomeDashboard> {
  final _search = TextEditingController();
  late Future<AliadoHomeData> _data;

  @override
  void initState() {
    super.initState();
    _data = _load();
    if (widget.embedInDesktopShell) {
      MainShellTabController.registerAliadoHomeReload(() {
        _refresh();
      });
    }
  }

  Future<AliadoHomeData> _load() async {
    final data = await (widget.loader ?? AliadoHomeService.load)();
    if (widget.loader != null) return data;
    try {
      final stock = await CatalogService.fetchWebCatalogStockIndex();
      return data.withWebStock(stock);
    } catch (_) {
      return data;
    }
  }

  @override
  void didUpdateWidget(covariant AliadoHomeDashboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile.id != widget.profile.id ||
        (!widget.embedInDesktopShell &&
            widget.isActiveTab &&
            !oldWidget.isActiveTab)) {
      _data = _load();
    }
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() {
      _data = next;
    });
    // FutureBuilder muestra el error y ofrece reintentar sin perder el buscador.
    try {
      await next;
    } catch (_) {}
  }

  @override
  void dispose() {
    if (widget.embedInDesktopShell) {
      MainShellTabController.registerAliadoHomeReload(null);
    }
    _search.dispose();
    super.dispose();
  }

  void _catalog([CatalogFilters filters = CatalogFilters.empty]) =>
      MainShellTabController.navigateToAliadoCatalog(filters: filters);

  void _searchCatalog() =>
      _catalog(CatalogFilters(searchQuery: _search.text.trim()));

  void _cart() => Navigator.of(context).push<void>(MaterialPageRoute(
      builder: (_) => CartScreen(profile: widget.profile, liveTasaBcv: null)));

  void _promotion(PromoCampaignModel campaign) =>
      MainShellTabController.navigateToAliadoCatalog(campaign: campaign);

  void _openCategory(
    AliadoCatalogCategoryGroup group, {
    bool includeBlankCategory = false,
  }) =>
      _catalog(CatalogFilters(
        category: group.label,
        categoryAnyOf:
            group.productIds.isEmpty ? group.values : const [],
        productIds: group.productIds,
        includeBlankCategory:
            includeBlankCategory && group.productIds.isEmpty,
      ));

  Widget _categorySheetTitle(
    String text,
    AliadoCatalogCategoryGroup group, {
    required bool showCount,
  }) {
    final count = group.productIds.length;
    return Row(
      children: [
        Expanded(child: Text(text)),
        if (showCount || !group.hasInventory) ...[
          const SizedBox(width: 8),
          _WebStockBadge(
            label: showCount
                ? (count == 1 ? '1 disponible' : '$count disponibles')
                : 'Sin stock',
          ),
        ],
      ],
    );
  }

  void _categories(
    AliadoHomeData data, {
    List<AliadoCatalogCategoryGroup>? groups,
    bool includeBlankAccessories = false,
  }) {
    if (widget.embedInDesktopShell) {
      _showWebCategoryDialog(
        groups: groups ?? data.categories,
        includeBlankAccessories: includeBlankAccessories,
      );
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
              child: SizedBox(
            height: MediaQuery.sizeOf(sheetContext).height * .65,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(children: [
                        const Expanded(
                            child: Text('Categorías',
                                style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700))),
                        IconButton(
                            tooltip: 'Cerrar categorías',
                            onPressed: () => Navigator.pop(sheetContext),
                            icon: const LucideIcon(LucideGlyph.close)),
                      ])),
                  Expanded(
                      child: ListView(children: [
                    for (final group in groups ?? data.categories)
                      if (group.children.isEmpty)
                        ListTile(
                          leading: CatalogCategoryIcon(
                            art: CatalogCategoryArt.forLabel(group.label),
                            size: 24,
                          ),
                          title: _categorySheetTitle(
                            catalogCategoryDisplayLabel(group.label),
                            group,
                            showCount: data.stockIndex.isNotEmpty,
                          ),
                          trailing: const _HomeAngle(),
                          onTap: () {
                            Navigator.pop(sheetContext);
                            _openCategory(
                              group,
                              includeBlankCategory: includeBlankAccessories &&
                                  group.label == 'Accesorios',
                            );
                          },
                        )
                      else
                        ExpansionTile(
                          leading: CatalogCategoryIcon(
                            art: CatalogCategoryArt.forLabel(group.label),
                            size: 24,
                          ),
                          title: _categorySheetTitle(
                            catalogCategoryDisplayLabel(group.label),
                            group,
                            showCount: data.stockIndex.isNotEmpty,
                          ),
                          children: [
                            for (final option in [group, ...group.children])
                              ListTile(
                                contentPadding:
                                    const EdgeInsets.symmetric(horizontal: 32),
                                leading: option.label ==
                                        'Lubricantes y mantenimiento / Aceites'
                                    ? const CatalogCategoryIcon(
                                        art: CatalogCategoryArt.oil, size: 20)
                                    : null,
                                title: _categorySheetTitle(
                                  identical(option, group)
                                      ? 'Ver todo en ${catalogCategoryDisplayLabel(group.label)}'
                                      : categoryLeaf(option.label),
                                  option,
                                  showCount: data.stockIndex.isNotEmpty,
                                ),
                                onTap: () {
                                  Navigator.pop(sheetContext);
                                  _openCategory(
                                    option,
                                    includeBlankCategory:
                                        includeBlankAccessories &&
                                            identical(option, group) &&
                                            group.label == 'Accesorios',
                                  );
                                },
                              ),
                          ],
                        ),
                  ])),
                ]),
          )));
  }

  @override
  Widget build(BuildContext context) {
    AppColors.brightness = Theme.of(context).brightness;
    return RetailerTourScreen(
      stop: RetailerTourStop.home,
      child: widget.embedInDesktopShell ? _webHome() : _mobile(),
    );
  }
}

class _HomeAngle extends StatelessWidget {
  const _HomeAngle({
    this.size = 24,
    this.color,
    this.reverse = false,
    this.enabled,
  });

  final double size;
  final Color? color;
  final bool reverse;
  final bool? enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.brightness == Brightness.dark ? 'dark' : 'light';
    final variant = enabled == true ? 'normal' : 'disabled';
    final icon = SvgPicture.asset(
      enabled == null
          ? 'assets/angulo/angulo-pequeno-derecho.svg'
          : 'assets/angulo/$palette-$variant.svg',
      width: size,
      height: size,
      excludeFromSemantics: true,
      colorFilter: enabled == null
          ? ColorFilter.mode(
              color ??
                  IconTheme.of(context).color ??
                  theme.colorScheme.onSurface,
              BlendMode.srcIn)
          : null,
    );
    return reverse ? Transform.flip(flipX: true, child: icon) : icon;
  }
}

class _CategoryShortcut extends StatelessWidget {
  const _CategoryShortcut(
      {required this.label, required this.onTap, this.illustrated = false});
  final String label;
  final VoidCallback onTap;
  final bool illustrated;

  @override
  Widget build(BuildContext context) {
    final art = CatalogCategoryArt.forLabel(label);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
            backgroundColor: art == null || !illustrated
                ? AppColors.surfaceTinted
                : dark
                    ? Color.lerp(AppColors.card, art.ink, .20)
                    : art.surface,
            foregroundColor: AppColors.textPrimary,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Transform.scale(
            scale: switch (art) {
              CatalogCategoryArt.tires => 1.24,
              CatalogCategoryArt.transmission => 1.28,
              _ => 1,
            },
            child: CatalogCategoryIcon(
              art: art,
              size: illustrated ? 54 : 42,
              color: art == null ? AppColors.brandLink : null,
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
              height: MediaQuery.textScalerOf(context).scale(28.8),
              child: Center(
                child: Text(catalogCategoryDisplayLabel(label),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12,
                        height: 1.2,
                        fontWeight: illustrated ? FontWeight.w700 : null)),
              ))
        ]));
  }
}
