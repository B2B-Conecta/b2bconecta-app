import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/features/catalog/aliado_catalog_categories.dart';
import 'package:motolink_pro_app/features/catalog/aliado_catalog_layout.dart';
import 'package:motolink_pro_app/features/catalog/catalog_product_price_display.dart';
import 'package:motolink_pro_app/features/catalog/importer_catalog_logo.dart';
import 'package:motolink_pro_app/features/catalog/product_warranty_seal.dart';
import 'package:motolink_pro_app/features/inventory/product_custom_fields.dart';
import 'package:motolink_pro_app/features/inventory/product_custom_fields_section.dart';
import 'catalog_service.dart';
import 'part_model.dart';
import 'product_detail_screen.dart';

/// Producto abierto desde un enlace, sin cuenta.
class GuestSharedProductScreen extends StatefulWidget {
  const GuestSharedProductScreen({
    super.key,
    required this.productId,
    required this.onRegister,
  });

  final String productId;
  final VoidCallback onRegister;

  @override
  State<GuestSharedProductScreen> createState() =>
      _GuestSharedProductScreenState();
}

class _GuestSharedProductScreenState extends State<GuestSharedProductScreen> {
  late final Future<PartModel?> _product = CatalogService.fetchPublicSharedProduct(
    widget.productId,
  );

  void _openStore(PartModel part) {
    final owner = part.ownerId?.trim();
    if (owner == null || owner.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GuestSupplierStoreScreen(
          importerId: owner,
          onRegister: widget.onRegister,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PartModel?>(
      future: _product,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _GuestWait(title: 'Producto');
        }
        final part = snapshot.data;
        if (snapshot.hasError || part == null) {
          return _GuestUnavailable(
            message: snapshot.hasError
                ? 'No se pudo abrir el producto. Revisa la conexión e inténtalo de nuevo.'
                : 'Este producto no está disponible.',
            onRegister: widget.onRegister,
          );
        }
        return ProductDetailScreen(
          part: part,
          guestPreview: true,
          onRegisterToOrder: widget.onRegister,
          onOpenStore: () => _openStore(part),
        );
      },
    );
  }
}

class GuestSupplierStoreScreen extends StatefulWidget {
  const GuestSupplierStoreScreen({
    super.key,
    required this.importerId,
    required this.onRegister,
  });

  final String importerId;
  final VoidCallback onRegister;

  @override
  State<GuestSupplierStoreScreen> createState() =>
      _GuestSupplierStoreScreenState();
}

class _GuestSupplierStoreScreenState extends State<GuestSupplierStoreScreen> {
  late final Future<
      ({
        String name,
        String? estado,
        String? ciudad,
        String? logoStoragePath,
        List<PartModel> products,
      })?> _store = CatalogService.fetchPublicSharedStore(widget.importerId);
  String? _category;

  void _openProduct(PartModel part) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProductDetailScreen(
          part: part,
          guestPreview: true,
          onRegisterToOrder: widget.onRegister,
          onOpenStore: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(future: _store, builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const _GuestWait(title: 'Vitrina');
      }
      final store = snapshot.data;
      if (snapshot.hasError || store == null) {
        return _GuestUnavailable(
          message: 'No se pudo abrir la vitrina del proveedor.',
          onRegister: widget.onRegister,
        );
      }
      final place = [
        store.estado?.trim(),
        store.ciudad?.trim(),
      ].where((s) => s != null && s.isNotEmpty).join(' · ');
      final categories = <String>[];
      for (final part in store.products) {
        final category = part.category?.trim() ?? '';
        if (category.isNotEmpty && !categories.contains(category)) {
          categories.add(category);
        }
      }
      final selected = categories.contains(_category) ? _category : null;
      final visible = selected == null
          ? store.products
          : store.products
              .where((part) => (part.category ?? '').trim() == selected)
              .toList();
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(store.name),
          actions: [
            TextButton(
              onPressed: widget.onRegister,
              child: const Text('Regístrate'),
            ),
          ],
        ),
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: [
                _GuestStoreHeader(
                  name: store.name,
                  place: place,
                  logoStoragePath: store.logoStoragePath,
                  productCount: store.products.length,
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: widget.onRegister,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Regístrate para pedir'),
                ),
                if (categories.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: const Text('Todos'),
                            selected: selected == null,
                            onSelected: (_) => setState(() => _category = null),
                          ),
                        ),
                        for (final category in categories)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(formatCatalogCategoryLabel(category)),
                              selected: selected == category,
                              onSelected: (_) =>
                                  setState(() => _category = category),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                if (visible.isEmpty)
                  Text(
                    'Este proveedor no tiene productos publicados.',
                    style: TextStyle(color: AppColors.textSecondary),
                  )
                else
                  LayoutBuilder(
                    builder: (context, constraints) {
                      return AliadoCatalogCardWrap(
                        maxWidth: constraints.maxWidth,
                        itemCount: visible.length,
                        itemBuilder: (context, index) {
                          return _GuestStoreProductCard(
                            part: visible[index],
                            onTap: () => _openProduct(visible[index]),
                          );
                        },
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      );
    });
  }
}

class _GuestWait extends StatelessWidget {
  const _GuestWait({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(title)),
      body: Center(child: CircularProgressIndicator(color: AppColors.brand)),
    );
  }
}

class _GuestUnavailable extends StatelessWidget {
  const _GuestUnavailable({
    required this.message,
    required this.onRegister,
  });

  final String message;
  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Producto')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: onRegister,
                child: const Text('Regístrate para pedir'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GuestStoreHeader extends StatelessWidget {
  const _GuestStoreHeader({
    required this.name,
    required this.place,
    required this.productCount,
    this.logoStoragePath,
  });

  final String name;
  final String place;
  final int productCount;
  final String? logoStoragePath;

  @override
  Widget build(BuildContext context) {
    final countLabel = productCount == 1
        ? '1 producto publicado'
        : '$productCount productos publicados';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ImporterCatalogLogo(
              storagePath: logoStoragePath,
              size: 64,
              fallback: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.surfaceTinted,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.storefront_outlined, color: AppColors.brand),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (place.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      place,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    countLabel,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuestStoreProductCard extends StatelessWidget {
  const _GuestStoreProductCard({
    required this.part,
    required this.onTap,
  });

  final PartModel part;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cover = part.coverImageUrl;
    final category = (part.category ?? '').trim();
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AspectRatio(
                  aspectRatio: 1.7,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        cover != null && cover.isNotEmpty
                            ? Image.network(
                                cover,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    const _GuestImagePlaceholder(),
                              )
                            : const _GuestImagePlaceholder(),
                        if (part.hasWarranty)
                          const Positioned(
                            top: 6,
                            left: 6,
                            child: ProductWarrantySeal(compact: true),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  part.nombre,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (category.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    formatCatalogCategoryLabel(category),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.brand,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                CatalogProductPriceDisplay(
                  listPriceUsd: part.precio,
                  salePriceUsd: part.salePriceUsd,
                  discountRules: part.discountRules,
                  catalogGrid: true,
                  compact: true,
                  showPromotionChips: false,
                  ownerPagoSoloDivisas: part.ownerPagoSoloDivisas,
                ),
                const SizedBox(height: 6),
                Text(
                  '${part.stock} en stock · ${part.minOrderQtyLabelEs}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (productCustomFieldsDisplayEntries(
                  part.customFields,
                  aliadoView: true,
                ).isNotEmpty) ...[
                  const SizedBox(height: 6),
                  ProductCustomFieldsAliadoChips(
                    customFields: part.customFields,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GuestImagePlaceholder extends StatelessWidget {
  const _GuestImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.surfaceTinted,
      child: Icon(
        Icons.image_outlined,
        size: 32,
        color: AppColors.textMuted,
      ),
    );
  }
}
