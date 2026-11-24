import '../catalog/product_catalog_pricing.dart';
import '../logistics/importer_carrier_model.dart';
import '../orders/shared/order_return_rules.dart';
import 'cart_service.dart';
import 'delivery_destination_dialog.dart';

double checkoutUnitPrice(CartLine line, {required bool payUsd}) => payUsd
    ? ProductCatalogPricing.aliadoUnitUsdPaymentLine(
        refUnitUsd: line.precioUnitarioAliadoRef,
        salePriceUsd: line.part.salePriceUsd,
        discountRules: line.part.discountRules,
        ownerPagoSoloDivisas: line.part.ownerPagoSoloDivisas)
    : line.precioUnitarioAliadoRef;

class MobileCheckoutSubmission {
  const MobileCheckoutSubmission(
      {required this.destination,
      required this.payUsd,
      required this.carriers,
      this.savedAddressId,
      this.pickups = const {},
      this.payUsdBySupplier = const {}});
  final DeliveryDestinationResult destination;
  final bool payUsd;
  final Map<String, Map<String, String?>> carriers;
  final Map<String, bool> payUsdBySupplier;
  final String? savedAddressId;
  final Map<String, String> pickups;
  Map<String, Map<String, String>> get deliveryBySupplier => {
        for (final entry in pickups.entries)
          entry.key: {'mode': 'PICKUP', 'location_id': entry.value}
      };

  bool paysUsd(String id) => payUsdBySupplier[id] ?? payUsd;
  Map<String, String> get currenciesBySupplier => {
        for (final entry in payUsdBySupplier.entries)
          entry.key: entry.value ? 'DIVISAS' : 'BOLIVARES',
      };
}

class MobileSupplierTotals {
  MobileSupplierTotals(
      {required this.lines,
      required this.payUsd,
      required double availableCredit}) {
    refProducts = lines.fold(
        0.0,
        (sum, line) =>
            sum + checkoutUnitPrice(line, payUsd: false) * line.quantity);
    products = lines.fold(
        0.0,
        (sum, line) =>
            sum + checkoutUnitPrice(line, payUsd: payUsd) * line.quantity);
    usdOffer = lines.fold(
        0.0,
        (sum, line) =>
            sum + checkoutUnitPrice(line, payUsd: true) * line.quantity);
    credit = OrderReturnRules.cappedCredit(availableCredit, products);
  }
  final List<CartLine> lines;
  final bool payUsd;
  late final double refProducts, products, usdOffer, credit;
  double get net => (products - credit).clamp(0.0, double.infinity);
  double get usdSavings => (refProducts - usdOffer).clamp(0.0, double.infinity);
}

/// Shipping quotes are USD and remain estimates, independently of product REF.
class MobileCheckoutTotals {
  MobileCheckoutTotals(
      {required List<CartLine> lines,
      required bool payUsd,
      required Map<String, double> credits,
      required Map<String, ImporterCarrierModel> carriers,
      required int supplierCount,
      Map<String, bool> payUsdBySupplier = const {},
      Set<String> pickupSuppliers = const {},
      double? rate}) {
    final groups = <String, List<CartLine>>{};
    for (final line in lines) {
      final owner = line.part.ownerId ?? '';
      groups.putIfAbsent(owner, () => []).add(line);
    }
    suppliers = {
      for (final entry in groups.entries)
        entry.key: MobileSupplierTotals(
            lines: entry.value,
            payUsd: payUsdBySupplier[entry.key] ?? payUsd,
            availableCredit: credits[entry.key] ?? 0)
    };
    mixedCurrencies = suppliers.values.map((s) => s.payUsd).toSet().length > 1;
    netUsd = suppliers.values
        .where((s) => s.payUsd)
        .fold(0.0, (sum, s) => sum + s.net);
    netRef = suppliers.values
        .where((s) => !s.payUsd)
        .fold(0.0, (sum, s) => sum + s.net);
    products = suppliers.values.fold(0.0, (sum, s) => sum + s.products);
    credit = suppliers.values.fold(0.0, (sum, s) => sum + s.credit);
    netProducts = (products - credit).clamp(0.0, double.infinity);
    final deliveries =
        carriers.entries.where((e) => !pickupSuppliers.contains(e.key));
    quotedShippingUsd =
        deliveries.fold(0.0, (sum, e) => sum + (e.value.feeUsd ?? 0));
    shippingPending =
        deliveries.length + pickupSuppliers.length < supplierCount ||
            deliveries.any((e) => e.value.feeUsd == null);
    // Both products and shipping use the displayed BCV rate for the estimate.
    estimatedTotal = shippingPending || mixedCurrencies
        ? null
        : netProducts + quotedShippingUsd;
    estimatedBs = !(suppliers.values.firstOrNull?.payUsd ?? payUsd) &&
            !mixedCurrencies &&
            rate != null &&
            rate > 0 &&
            estimatedTotal != null
        ? estimatedTotal! * rate
        : null;
  }
  late final double products, credit, netProducts, quotedShippingUsd;
  late final bool shippingPending;
  late final bool mixedCurrencies;
  late final Map<String, MobileSupplierTotals> suppliers;
  late final double netUsd, netRef;
  late final double? estimatedTotal, estimatedBs;
}
