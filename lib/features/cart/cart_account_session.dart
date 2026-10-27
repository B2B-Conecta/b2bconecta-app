import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:motolink_pro_app/features/catalog/catalog_service.dart';
import 'cart_draft_storage.dart';
import 'cart_service.dart';

/// Bind the local draft to the current account, including token expiry/logout.
abstract final class CartAccountSession {
  static StreamSubscription<AuthState>? _subscription;

  static void start(String environmentUrl) {
    unawaited(_subscription?.cancel());
    final auth = Supabase.instance.client.auth;
    void bind(String? userId) {
      Future<Map<String, ({String campaignId, double percent})>>? discounts;
      unawaited(CartService.instance.openAccount(
        accountKey:
            userId == null ? null : 'b2b.cart.v1:$environmentUrl:$userId',
        storage: PreferencesCartDraftStorage(),
        loadProduct: (id) async {
          final part = await CatalogService.fetchCatalogProductById(id);
          if (part == null) return null;
          discounts ??= CatalogService.fetchActivePromoProductDiscounts();
          final promo = (await discounts!)[id];
          return promo == null
              ? part
              : part.copyWith(
                  activeCampaignDiscountPercent: promo.percent,
                  activePromoCampaignId: promo.campaignId,
                );
        },
      ));
    }

    bind(auth.currentUser?.id);
    _subscription =
        auth.onAuthStateChange.listen((state) => bind(state.session?.user.id));
  }
}
