import 'package:flutter/material.dart';

import '../../core/data/supabase_service.dart';
import '../cart/cart_service.dart';
import '../profile/profile_model.dart';
import 'aliado_promo_campaign_widgets.dart';
import 'catalog_route_lock.dart';
import 'importer_store_profile_screen.dart';
import 'part_model.dart';
import 'product_detail_screen.dart';
import 'promo_campaign_model.dart';

Future<void> openAliadoPromoCampaignDestination({
  required BuildContext context,
  required PromoCampaignModel campaign,
  required ProfileModel viewer,
  Iterable<PartModel> cachedParts = const [],
}) async {
  if (!CatalogRouteLock.tryHold()) return;
  var handedOff = false;
  try {
    handedOff = await _openDestination(context, campaign, viewer, cachedParts);
  } finally {
    if (!handedOff) CatalogRouteLock.release();
  }
}

Future<bool> _openDestination(
  BuildContext context,
  PromoCampaignModel campaign,
  ProfileModel viewer,
  Iterable<PartModel> cachedParts,
) async {
  if (campaign.opensStore) {
    final importadorId = campaign.importadorId!.trim();
    if (!context.mounted) return false;
    await CatalogRouteLock.pushHeld(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ImporterStoreProfileScreen(
          importerId: importadorId,
          viewer: viewer,
        ),
      ),
    );
    return true;
  }
  if (!campaign.opensProduct) return false;
  final importerId = campaign.importadorId!.trim();
  CartService.instance.setPromoAttribution(
    importadorId: importerId,
    campaignId: campaign.id,
  );
  final ids = campaign.resolvedProductIds;

  final byId = <String, PartModel>{};
  final missing = <String>[];
  for (final id in ids) {
    PartModel? cached;
    for (final part in cachedParts) {
      if (part.id == id && (part.ownerId?.trim() ?? '') == importerId) {
        cached = part;
        break;
      }
    }
    if (cached != null) {
      byId[id] = _withCampaignDiscount(cached, campaign);
    } else {
      missing.add(id);
    }
  }

  if (missing.isNotEmpty && context.mounted) {
    final navigator = Navigator.of(context, rootNavigator: true);
    final route = DialogRoute<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    navigator.push(route);
    try {
      final fetched = await SupabaseService.fetchVisibleImporterStoreProducts(
        importerId: importerId,
        productIds: missing,
      );
      for (final part in fetched) {
        byId[part.id] = _withCampaignDiscount(part, campaign);
      }
    } catch (_) {
      if (context.mounted && byId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudieron cargar los productos de la promoción.'),
          ),
        );
      }
      if (byId.isEmpty) return false;
    } finally {
      if (route.isActive) navigator.removeRoute(route);
    }
  }

  if (!context.mounted) return false;
  final parts = <PartModel>[
    for (final id in ids)
      if (byId[id] != null) byId[id]!,
  ];
  if (parts.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Esta promoción no tiene productos disponibles.'),
      ),
    );
    return false;
  }
  if (parts.length == 1) {
    await CatalogRouteLock.pushHeld(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ProductDetailScreen(part: parts.first),
      ),
    );
    return true;
  }

  final chosen = await showAliadoPromoProductsSheet(
    context: context,
    campaign: campaign,
    parts: parts,
  );
  if (!context.mounted || chosen == null) return false;
  await CatalogRouteLock.pushHeld(
    context,
    MaterialPageRoute<void>(
      builder: (_) => ProductDetailScreen(part: chosen),
    ),
  );
  return true;
}

PartModel _withCampaignDiscount(PartModel part, PromoCampaignModel campaign) {
  final pct = campaign.effectivePercentFor(part.id);
  if (pct == null || pct <= 0) return part;
  return part.copyWith(
    activeCampaignDiscountPercent: pct,
    activePromoCampaignId: campaign.id,
  );
}
