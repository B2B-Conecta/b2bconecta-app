import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/utils/ves_amount_format.dart';
import 'package:motolink_pro_app/core/widgets/motolink_pro_logo.dart';
import 'package:motolink_pro_app/features/catalog/importer_catalog_logo.dart';
import 'package:motolink_pro_app/features/inventory/product_images.dart';
import 'package:motolink_pro_app/features/orders/shared/b2b_orders_panel_layout.dart';
import 'package:motolink_pro_app/features/orders/shared/qty_adjustment_status.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_model.dart';
import 'package:motolink_pro_app/features/profile/app_home_role.dart';
import 'package:motolink_pro_app/features/profile/profile_role_labels.dart';

enum OrderCardPartyKind { retailer, wholesaler }

/// Contraparte visible en la ficha compacta (sin teléfono, RIF ni correo).
class OrderCardRelatedParty {
  const OrderCardRelatedParty({
    required this.kind,
    required this.roleLabel,
    required this.displayName,
    this.logoStoragePath,
    this.locationLine,
  });

  final OrderCardPartyKind kind;
  final String roleLabel;
  final String displayName;
  final String? logoStoragePath;
  final String? locationLine;

  IconData get icon => kind == OrderCardPartyKind.retailer
      ? Icons.storefront_outlined
      : Icons.inventory_2_outlined;
}

/// Partida de producto siempre visible en la ficha.
class OrderCardProductPeek {
  const OrderCardProductPeek({
    required this.name,
    required this.quantity,
    required this.lineTotalRef,
    this.sku,
    this.imageUrl,
    this.lineStatusLabel,
  });

  final String name;
  final int quantity;
  final double lineTotalRef;
  final String? sku;
  final String? imageUrl;
  final String? lineStatusLabel;
}

String? _locationLine(String? ciudad, String? estado) {
  final loc = [
    if (ciudad?.trim().isNotEmpty == true) ciudad!.trim(),
    if (estado?.trim().isNotEmpty == true) estado!.trim(),
  ].join(', ');
  return loc.isEmpty ? null : loc;
}

String orderCardPartyInitials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) {
    final s = parts.first;
    return s.substring(0, s.length >= 2 ? 2 : 1).toUpperCase();
  }
  final a = parts[0].isNotEmpty ? parts[0][0] : '';
  final b = parts[1].isNotEmpty ? parts[1][0] : '';
  final out = '$a$b'.toUpperCase();
  return out.isEmpty ? '?' : out;
}

/// Usuarios/empresas relacionados según el rol que mira el listado.
///
/// No incluye vendedor externo ni `confirmado_por`: no forman parte del
/// modelo de contraparte del pedido.
List<OrderCardRelatedParty> orderCardRelatedParties({
  required List<TransactionRequestModel> lines,
  required AppHomeRole viewerRole,
}) {
  if (lines.isEmpty) return const [];

  final parties = <OrderCardRelatedParty>[];

  void addRetailers() {
    final seen = <String>{};
    for (final r in lines) {
      final id = r.aliadoId.trim();
      if (id.isEmpty || !seen.add(id)) continue;
      final name = r.aliadoBusinessName?.trim();
      parties.add(
        OrderCardRelatedParty(
          kind: OrderCardPartyKind.retailer,
          roleLabel: ProfileRoleLabels.aliadoEs,
          displayName: (name != null && name.isNotEmpty)
              ? name
              : ProfileRoleLabels.aliadoEs,
          logoStoragePath: r.aliadoLogoStoragePath,
          locationLine: _locationLine(r.aliadoCiudad, r.aliadoEstado),
        ),
      );
    }
  }

  void addWholesalers() {
    final seen = <String>{};
    for (final r in lines) {
      final id = r.ownerId.trim();
      if (id.isEmpty || !seen.add(id)) continue;
      final name = r.ownerBusinessName?.trim();
      parties.add(
        OrderCardRelatedParty(
          kind: OrderCardPartyKind.wholesaler,
          roleLabel: ProfileRoleLabels.labelEs('importador'),
          displayName: (name != null && name.isNotEmpty)
              ? name
              : ProfileRoleLabels.labelEs('importador'),
          logoStoragePath: r.ownerLogoStoragePath,
          locationLine: _locationLine(r.ownerCiudad, r.ownerEstado),
        ),
      );
    }
  }

  switch (viewerRole) {
    case AppHomeRole.aliado:
      addWholesalers();
    case AppHomeRole.importador:
      addRetailers();
    case AppHomeRole.administrador:
      addRetailers();
      addWholesalers();
  }
  return parties;
}

/// Productos y cantidades de las líneas ya cargadas (sin peticiones extra).
List<OrderCardProductPeek> orderCardProductPeeks({
  required List<TransactionRequestModel> lines,
  String? importerUserId,
}) {
  if (lines.isEmpty) return const [];
  final out = <OrderCardProductPeek>[];
  for (final r in lines) {
    final desglose = r.lineasProductoDesglose(
      forImportadorUserId: importerUserId,
    );
    final cover = productCoverImageUrl(r.productImageUrls);
    final lineStatus = r.qtyAdjustmentStatus == QtyAdjustmentStatus.pendienteAliado
        ? 'Ajuste pendiente'
        : null;
    for (var i = 0; i < desglose.length; i++) {
      final p = desglose[i];
      out.add(
        OrderCardProductPeek(
          name: p.nombre,
          sku: p.sku,
          quantity: p.cantidad,
          lineTotalRef: p.precioRef,
          imageUrl: desglose.length == 1 ? cover : null,
          lineStatusLabel: lineStatus,
        ),
      );
    }
  }
  return out;
}

/// Usuarios relacionados y productos, siempre visibles en la ficha de pedido.
class OrderCardDirectSummary extends StatelessWidget {
  const OrderCardDirectSummary({
    super.key,
    required this.lines,
    required this.viewerRole,
    this.importerUserId,
  });

  final List<TransactionRequestModel> lines;
  final AppHomeRole viewerRole;
  final String? importerUserId;

  @override
  Widget build(BuildContext context) {
    final density = B2bOrderCardDensity.ofContext(context);
    final parties = orderCardRelatedParties(
      lines: lines,
      viewerRole: viewerRole,
    );
    final products = orderCardProductPeeks(
      lines: lines,
      importerUserId: importerUserId,
    );
    if (parties.isEmpty && products.isEmpty) {
      return const SizedBox.shrink();
    }

    final showLineTotal = products.length > 1;
    final gap = density.isDesktop ? 4.0 : 6.0;
    final singleProduct = products.length == 1;

    return Padding(
      padding: EdgeInsets.only(top: density.isDesktop ? 6 : 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final party in parties) ...[
            _OrderCardPartyRow(party: party, density: density),
            SizedBox(height: gap),
          ],
          for (var i = 0; i < products.length; i++) ...[
            _OrderCardProductRow(
              product: products[i],
              density: density,
              emphasizeName: singleProduct,
              showLineTotal: showLineTotal,
            ),
            if (i < products.length - 1) SizedBox(height: gap),
          ],
        ],
      ),
    );
  }
}

class _OrderCardPartyRow extends StatelessWidget {
  const _OrderCardPartyRow({
    required this.party,
    required this.density,
  });

  final OrderCardRelatedParty party;
  final B2bOrderCardDensity density;

  @override
  Widget build(BuildContext context) {
    final markSize = density.isDesktop ? 22.0 : 24.0;
    return Semantics(
      label: '${party.roleLabel}: ${party.displayName}',
      child: Row(
        children: [
          _PartyMark(
            icon: party.icon,
            logoStoragePath: party.logoStoragePath,
            size: markSize,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              party.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: density.metaTextSize,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PartyMark extends StatelessWidget {
  const _PartyMark({
    required this.icon,
    required this.size,
    this.logoStoragePath,
  });

  final IconData icon;
  final double size;
  final String? logoStoragePath;

  @override
  Widget build(BuildContext context) {
    final path = logoStoragePath?.trim();
    final fallback = Icon(
      icon,
      size: size * 0.78,
      color: AppColors.textSecondary,
    );
    if (path == null || path.isEmpty) return fallback;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          fallback,
          ClipRRect(
            borderRadius: BorderRadius.circular(size * 0.22),
            child: ImporterCatalogLogo(storagePath: path, size: size),
          ),
        ],
      ),
    );
  }
}

class _OrderCardProductRow extends StatelessWidget {
  const _OrderCardProductRow({
    required this.product,
    required this.density,
    required this.emphasizeName,
    required this.showLineTotal,
  });

  final OrderCardProductPeek product;
  final B2bOrderCardDensity density;
  final bool emphasizeName;
  final bool showLineTotal;

  @override
  Widget build(BuildContext context) {
    final thumb = density.isDesktop ? 32.0 : 36.0;
    final sku = product.sku?.trim();
    final hasSku = sku != null && sku.isNotEmpty;
    final status = product.lineStatusLabel;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _ProductThumb(url: product.imageUrl, size: thumb),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                product.name,
                maxLines: emphasizeName ? 2 : 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: emphasizeName
                      ? density.productTitleSize
                      : density.metaTextSize,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  height: 1.2,
                ),
              ),
              if (hasSku)
                Text(
                  sku,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: density.skuTextSize,
                    color: AppColors.textSecondary,
                    height: 1.2,
                  ),
                ),
              if (status != null)
                Text(
                  status,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: density.contentSmallSize,
                    fontWeight: FontWeight.w600,
                    color: AppColors.brandBlue,
                    height: 1.2,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '×${product.quantity}',
              style: TextStyle(
                fontSize: density.metaTextSize,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                height: 1.2,
              ),
            ),
            if (showLineTotal)
              Text(
                '${formatRefAmount(product.lineTotalRef)} REF',
                style: TextStyle(
                  fontSize: density.contentSmallSize,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                  height: 1.2,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _ProductThumb extends StatelessWidget {
  const _ProductThumb({required this.size, this.url});

  final double size;
  final String? url;

  @override
  Widget build(BuildContext context) {
    final src = url?.trim();
    final radius = BorderRadius.circular(size * 0.16);
    Widget fallback() => BusinessLogoPlaceholder(size: size);

    if (src == null || src.isEmpty) {
      return fallback();
    }

    return ClipRRect(
      borderRadius: radius,
      child: Image.network(
        src,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback(),
      ),
    );
  }
}
