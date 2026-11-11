import '../../core/data/supabase_access.dart';
import '../catalog/aliado_catalog_categories.dart';
import '../catalog/catalog_service.dart';
import '../catalog/catalog_filters.dart';
import '../catalog/part_model.dart';
import '../catalog/promo_campaign_model.dart';
import '../orders/shared/transaction_request_status.dart';

class AliadoHomeSelection {
  const AliadoHomeSelection(
      {this.buyAgain = const [], this.bestSellers = const []});
  final List<String> buyAgain;
  final List<String> bestSellers;

  factory AliadoHomeSelection.fromJson(Map<String, dynamic> json) {
    List<String> ids(String key) => (json[key] as List? ?? const [])
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .take(12)
        .toList();
    return AliadoHomeSelection(
        buyAgain: ids('buy_again'), bestSellers: ids('best_sellers'));
  }
}

class AliadoHomeData {
  const AliadoHomeData({
    this.buyAgain = const [],
    this.bestSellers = const [],
    this.categories = const [],
    this.promotions = const [],
    this.newArrivals = const [],
    this.suppliers = const [],
    this.activeOrders = 0,
    this.errors = const [],
  });
  final List<PartModel> buyAgain;
  final List<PartModel> bestSellers;
  final List<AliadoCatalogCategoryGroup> categories;
  final List<PromoCampaignModel> promotions;
  final List<PartModel> newArrivals;
  final List<ImporterOption> suppliers;
  final int activeOrders;
  final List<String> errors;
}

/// Accesos habituales primero, siempre con los valores reales del catálogo.
List<AliadoCatalogCategoryGroup> prioritizeHomeCategories(
    List<AliadoCatalogCategoryGroup> groups) {
  int priority(String label) {
    final key = catalogCategoryKey(label);
    if (key.contains('caucho')) return 0;
    if (key.contains('freno')) return 1;
    if (key.contains('transmision')) return 2;
    if (key.contains('electrico')) return 3;
    return 4;
  }

  return [...groups]..sort((a, b) {
      final rank = priority(a.label).compareTo(priority(b.label));
      return rank != 0 ? rank : a.label.compareTo(b.label);
    });
}

/// Inicio no lee pedidos de terceros. El servidor entrega solo IDs de productos;
/// precios, disponibilidad, proveedores y promociones salen del catálogo actual.
abstract final class AliadoHomeService {
  static Future<AliadoHomeData> load() async {
    final errors = <String>[];
    Future<T> section<T>(
        String label, Future<T> Function() read, T empty) async {
      try {
        return await read();
      } catch (_) {
        errors.add(label);
        return empty;
      }
    }

    final selection = section('tus compras y los más vendidos', () async {
      final result =
          await SupabaseAccess.client.rpc('aliado_home_product_selection');
      return AliadoHomeSelection.fromJson(
          Map<String, dynamic>.from(result as Map));
    }, const AliadoHomeSelection());
    final categories = section('las categorías',
        CatalogService.fetchAliadoCatalogCategories, <String>[]);
    final promotions = section(
        'las promociones',
        CatalogService.fetchActivePromoCampaignsForAliado,
        <PromoCampaignModel>[]);
    final arrivals = section(
        'las novedades', CatalogService.fetchHomeNewArrivals, <PartModel>[]);
    final suppliers = section('los proveedores', () async {
      final (options, published) = await (
        CatalogService.fetchImporterOptions(),
        CatalogService.fetchPublishedCatalogOwnerIds()
      ).wait;
      return options.where((option) => published.contains(option.id)).toList();
    }, <ImporterOption>[]);
    final activeOrders = section('el seguimiento', _countActiveOrders, 0);
    final selected = await selection;
    final products = await section(
        'los productos',
        () => CatalogService.fetchHomeProducts(
            [...selected.buyAgain, ...selected.bestSellers]),
        <PartModel>[]);
    final byId = {for (final product in products) product.id: product};
    List<PartModel> resolve(List<String> ids) => [
          for (final id in ids)
            if (byId[id] != null) byId[id]!,
        ].take(6).toList();
    return AliadoHomeData(
      buyAgain: resolve(selected.buyAgain),
      bestSellers: resolve(selected.bestSellers),
      categories:
          prioritizeHomeCategories(catalogCategoryFamilies(await categories)),
      promotions: await promotions,
      newArrivals: await arrivals,
      suppliers: await suppliers,
      activeOrders: await activeOrders,
      errors: errors,
    );
  }

  static Future<int> _countActiveOrders() async {
    final user = SupabaseAccess.currentUserId;
    if (user == null) return 0;
    final orders = <String>{};
    const pageSize = 250;
    for (var offset = 0;; offset += pageSize) {
      final rows = await SupabaseAccess.client
          .from('transaction_requests')
          .select('id, checkout_group_id')
          .eq('aliado_id', user)
          .inFilter('status', TransactionRequestStatus.aliadoPedidosEnCurso)
          .order('id')
          .range(offset, offset + pageSize - 1);
      for (final row in rows) {
        orders.add((row['checkout_group_id'] ?? row['id']).toString());
      }
      if (rows.length < pageSize) return orders.length;
    }
  }
}
