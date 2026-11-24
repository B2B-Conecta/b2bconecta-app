import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:motolink_pro_app/features/catalog/catalog_service.dart';
import 'package:motolink_pro_app/features/catalog/part_model.dart';
import 'package:motolink_pro_app/features/profile/profile_location_exception.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';
import 'cart_service.dart';
import 'cart_quantity_field.dart';
import 'delivery_destination_dialog.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'package:motolink_pro_app/app/main_shell_tab.dart';
import 'package:motolink_pro_app/features/ads/meta_pixel.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'package:motolink_pro_app/core/layout/app_breakpoints.dart';
import 'package:motolink_pro_app/features/catalog/catalog_cart_price.dart';
import 'package:motolink_pro_app/features/catalog/importer_catalog_logo.dart';
import 'package:motolink_pro_app/core/utils/ves_amount_format.dart';
import 'package:motolink_pro_app/core/widgets/app_notice_message.dart';
import 'package:motolink_pro_app/core/widgets/b2b_header_title.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';
import 'package:motolink_pro_app/features/catalog/product_catalog_pricing.dart';
import 'package:motolink_pro_app/features/logistics/envio_politica.dart';
import 'package:motolink_pro_app/features/orders/shared/order_return_rules.dart';
import 'package:motolink_pro_app/features/orders/shared/orders_service.dart';
import 'cart_product_actions.dart';
import 'cart_suggestions.dart';
import 'cart_suggestions_section.dart';
import 'importer_min_order.dart';
import 'min_order_currency.dart';
import 'mobile_checkout_model.dart';
import 'mobile_checkout_screen.dart';
import 'checkout_attempt.dart';
import 'checkout_delivery_data.dart';

part 'cart_screen_web.dart';

/// Carrito multi-importador: agrupa por importador y confirma un solo pedido maestro.
class CartScreen extends StatefulWidget {
  const CartScreen({
    super.key,
    required this.profile,
    this.liveTasaBcv,
    this.loadSuggestionCandidates,
    this.suggestionAutoPlay = true,
  });

  final ProfileModel profile;
  final double? liveTasaBcv;

  /// Sustituye la lectura del catálogo. Las pruebas pasan una lista fija.
  final Future<List<PartModel>> Function(CartSuggestionQuery query)?
      loadSuggestionCandidates;

  /// Auto-desplazamiento del carrusel de sugerencias (desactivar en tests).
  final bool suggestionAutoPlay;

  @override
  State<CartScreen> createState() => _CartScreenState();
}

enum _PagoMoneda { bolivares, usd }

/// Every display currency starts with the same effective price as checkout.
double _cartUnitDollars(CartLine line, _PagoMoneda modo) {
  return checkoutUnitPrice(line, payUsd: modo == _PagoMoneda.usd);
}

String _cartMoney(double dollars, _PagoMoneda modo, double? tasa) {
  switch (modo) {
    case _PagoMoneda.usd:
      return '${formatRefAmount(dollars)} USD';
    case _PagoMoneda.bolivares:
      if (tasa == null || tasa <= 0) return 'Sin tasa';
      return formatBsLabel(dollars * tasa);
  }
}

class _CartScreenState extends State<CartScreen> {
  final _cart = CartService.instance;
  bool _submitting = false;
  bool _choosingDelivery = false;
  _PagoMoneda _pagoMoneda = _PagoMoneda.bolivares;
  double? _tasa;
  DateTime? _tasaEffectiveDate;
  Map<String, ImporterCreditBalance> _credits = const {};
  final Set<String> _creditOptOut = {};
  bool _loadingSuggestions = false;
  List<CartSuggestion> _suggestions = const [];
  List<PartModel> _suggestionPool = const [];
  String? _suggestionCartKey;
  String? _suggestionInflightKey;
  int _suggestionTicket = 0;
  final Set<String> _confirmingSuggestionIds = {};
  final Map<String, CartSuggestion> _pinnedSuggestions = {};
  final Map<String, Timer> _suggestionConfirmTimers = {};
  final GlobalKey _summaryKey = GlobalKey();
  double _summaryHeight = 420;
  bool get _mobileCheckout =>
      MediaQuery.sizeOf(context).width < AppBreakpoints.mobileMenu;
  bool _supplierPaysUsd(String owner) {
    final lines = _cart.supplierGroups[owner] ?? const <CartLine>[];
    if (lines.any((line) => line.part.ownerPagoSoloDivisas) ||
        (_tasa ?? 0) <= 0) return true;
    return _cart.supplierCurrencyPreferences[owner] ??
        (_pagoMoneda == _PagoMoneda.usd);
  }

  Map<String, bool> get _supplierCurrencies => {
        for (final owner in _cart.supplierGroups.keys)
          owner: _supplierPaysUsd(owner),
      };
  _PagoMoneda _modeFor(List<CartLine> lines) =>
      _mobileCheckout && lines.isNotEmpty
          ? (_supplierPaysUsd(lines.first.part.ownerId ?? '')
              ? _PagoMoneda.usd
              : _PagoMoneda.bolivares)
          : _pagoMoneda;
  MobileCheckoutTotals get _mobileTotals => MobileCheckoutTotals(
      lines: _cart.lines,
      payUsd: _pagoMoneda == _PagoMoneda.usd,
      payUsdBySupplier: _supplierCurrencies,
      credits: {
        for (final e in _credits.entries)
          if (!_creditOptOut.contains(e.key)) e.key: e.value.remaining
      },
      carriers: const {},
      supplierCount: _cart.supplierGroups.length,
      rate: _tasa);

  void _selectDesktopCurrency(int index) {
    setState(() => _pagoMoneda = _PagoMoneda.values[index]);
  }

  void _setDesktopCredit(String ownerId, bool useCredit) {
    setState(() {
      if (useCredit) {
        _creditOptOut.remove(ownerId);
      } else {
        _creditOptOut.add(ownerId);
      }
    });
  }

  void _syncSummaryHeight() {
    final box = _summaryKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final next = box.size.height;
    if ((next - _summaryHeight).abs() < 1) return;
    setState(() => _summaryHeight = next);
  }

  @override
  void initState() {
    super.initState();
    _tasa = widget.liveTasaBcv;
    _cart.addListener(_onCart);
    _loadCredits();
    if (_cart.lines.isNotEmpty) _loadingSuggestions = true;
    _reloadSuggestions();
    SupabaseService.fetchGlobalTasaBcvRecord().then((record) {
      if (!mounted || record == null) return;
      setState(() {
        _tasa = record.tasa;
        _tasaEffectiveDate = DateTime.tryParse(record.effectiveDate ?? '');
      });
    }).catchError((_) {});
  }

  void _onCart() {
    if (!mounted) return;
    setState(() {});
    final key = _cartProductKey();
    if (key == _suggestionCartKey) {
      _publishSuggestions();
      return;
    }
    if (key == _suggestionInflightKey) return;
    _reloadSuggestions();
  }

  String _cartProductKey() {
    final ids = [for (final line in _cart.lines) line.part.id]..sort();
    return ids.join(',');
  }

  Future<List<PartModel>> _loadSuggestionCandidates(
    CartSuggestionQuery query,
  ) {
    final custom = widget.loadSuggestionCandidates;
    if (custom != null) return custom(query);
    return CatalogService.fetchCartSuggestionCandidates(
      excludeProductIds: query.productIds,
      categoryFragments: query.categoryFragments,
    );
  }

  Future<void> _reloadSuggestions() async {
    final key = _cartProductKey();
    final parts = [for (final line in _cart.lines) line.part];
    if (parts.isEmpty) {
      _suggestionCartKey = key;
      _suggestionInflightKey = null;
      _suggestionPool = const [];
      if (!mounted) return;
      setState(() {
        _suggestions = [
          for (final entry in _pinnedSuggestions.entries)
            if (_confirmingSuggestionIds.contains(entry.key)) entry.value,
        ];
        _loadingSuggestions = false;
      });
      return;
    }
    final ticket = ++_suggestionTicket;
    _suggestionInflightKey = key;
    final skeleton = _suggestions.isEmpty &&
        _pinnedSuggestions.isEmpty &&
        !_loadingSuggestions;
    if (skeleton && mounted) setState(() => _loadingSuggestions = true);
    try {
      final candidates = await _loadSuggestionCandidates(
        CartSuggestionQuery.fromParts(parts),
      );
      if (!mounted || ticket != _suggestionTicket) return;
      _suggestionPool = candidates;
      _suggestionCartKey = key;
      _suggestionInflightKey = null;
      _publishSuggestions();
    } catch (_) {
      if (!mounted || ticket != _suggestionTicket) return;
      _suggestionInflightKey = null;
      setState(() => _loadingSuggestions = false);
    }
  }

  void _publishSuggestions() {
    final ranked = rankCartSuggestions(
      cartParts: [for (final line in _cart.lines) line.part],
      candidates: _suggestionPool,
    );
    final visible = <CartSuggestion>[
      for (final entry in _pinnedSuggestions.entries)
        if (_confirmingSuggestionIds.contains(entry.key)) entry.value,
      for (final suggestion in ranked)
        if (!_confirmingSuggestionIds.contains(suggestion.part.id)) suggestion,
    ];
    if (!mounted) return;
    setState(() {
      _suggestions = visible;
      _loadingSuggestions = false;
    });
  }

  void _addSuggestion(CartSuggestion suggestion) {
    if (_confirmingSuggestionIds.contains(suggestion.part.id)) return;
    final blocked = CartProductActions.blockReason(
      part: suggestion.part,
      profile: widget.profile,
      cart: _cart,
    );
    if (blocked != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(blocked)));
      return;
    }
    final added = CartProductActions.addMinimum(
      part: suggestion.part,
      profile: widget.profile,
      cart: _cart,
    );
    if (added == 0) return;
    _pinnedSuggestions[suggestion.part.id] = suggestion;
    _confirmingSuggestionIds.add(suggestion.part.id);
    _suggestionConfirmTimers[suggestion.part.id]?.cancel();
    _suggestionConfirmTimers[suggestion.part.id] = Timer(
      const Duration(milliseconds: 700),
      () {
        if (!mounted) return;
        _confirmingSuggestionIds.remove(suggestion.part.id);
        _pinnedSuggestions.remove(suggestion.part.id);
        _suggestionConfirmTimers.remove(suggestion.part.id);
        _publishSuggestions();
      },
    );
    _publishSuggestions();
  }

  Future<void> _loadCredits() async {
    try {
      final rows = await OrdersService.fetchImporterCreditBalances();
      if (!mounted) return;
      setState(() {
        _credits = {for (final row in rows) row.importadorId: row};
      });
    } catch (_) {}
  }

  double _groupSubtotal(List<CartLine> lines) => lines.fold<double>(
        0,
        (sum, line) =>
            sum + _cartUnitDollars(line, _modeFor(lines)) * line.quantity,
      );

  double _creditFor(List<CartLine> lines) {
    final id = lines.isEmpty ? null : lines.first.part.ownerId?.trim();
    if (id == null || id.isEmpty || _creditOptOut.contains(id)) return 0;
    final available = _credits[id]?.remaining ?? 0;
    return OrderReturnRules.cappedCredit(available, _groupSubtotal(lines));
  }

  double get _appliedCredit => _cart.supplierGroups.values.fold(
        0,
        (sum, lines) => sum + _creditFor(lines),
      );

  Map<String, bool> _creditPayload() {
    final out = <String, bool>{};
    for (final entry in _cart.linesGroupedByImportadorId.entries) {
      if (_creditOptOut.contains(entry.key)) continue;
      if ((_credits[entry.key]?.remaining ?? 0) <= 0) continue;
      out[entry.key] = true;
    }
    return out;
  }

  @override
  void dispose() {
    for (final timer in _suggestionConfirmTimers.values) {
      timer.cancel();
    }
    _cart.removeListener(_onCart);
    super.dispose();
  }

  /// En escritorio, un proveedor bajo su monto mínimo en USD no puede enviarse.
  bool get _desktopShortOnUsdMinimum {
    if (MediaQuery.sizeOf(context).width < AppBreakpoints.mobileMenu) {
      return false;
    }
    return !_cart.supplierGroups.values.every(SupplierUsdMinOrder.meetsLines);
  }

  /// En escritorio, un proveedor bajo su mínimo de unidades no puede enviarse.
  bool get _desktopShortOnUnits {
    if (MediaQuery.sizeOf(context).width < AppBreakpoints.mobileMenu) {
      return false;
    }
    return !_cart.supplierGroups.values.every(SupplierOrderMinUnits.meets);
  }

  Future<void> _checkout() async {
    if (_cart.pendingCheckoutAttempt != null &&
        !_submitting &&
        !_choosingDelivery) {
      await _recoverPendingCheckout();
      return;
    }
    if (!_cart.canEdit ||
        _cart.isEmpty ||
        _submitting ||
        _choosingDelivery ||
        !_cart.meetsAllImporterMinOrders ||
        _desktopShortOnUsdMinimum ||
        _desktopShortOnUnits) {
      return;
    }

    if (MediaQuery.sizeOf(context).width < AppBreakpoints.mobileMenu) {
      await _checkoutMobile();
      return;
    }

    final accountRevision = _cart.accountRevision;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _choosingDelivery = true);
    final result = await showDialog<DeliveryDestinationResult?>(
      context: context,
      builder: (ctx) => DeliveryDestinationDialog(
          profile: widget.profile,
          paymentSummary: _pagoMoneda == _PagoMoneda.usd
              ? 'Pago en divisas (USD).'
              : 'Pago en bolívares a la tasa BCV. El REF es la base de cálculo.'),
    );

    if (!mounted) return;
    setState(() => _choosingDelivery = false);
    if (result == null ||
        !_cart.canEdit ||
        _cart.isEmpty ||
        accountRevision != _cart.accountRevision ||
        !_cart.meetsAllImporterMinOrders ||
        _desktopShortOnUsdMinimum ||
        _desktopShortOnUnits) return;

    setState(() => _submitting = true);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    try {
      final lines = _cart.lines
          .map(
            (l) => <String, dynamic>{
              'product_id': l.part.id,
              'cantidad': l.quantity,
            },
          )
          .toList();

      final appliedCredit = _appliedCredit;
      final moneda = _pagoMoneda == _PagoMoneda.usd ? 'DIVISAS' : 'BOLIVARES';
      final orderId = await SupabaseService.checkoutMultiImportadorCart(
        lines: lines,
        destinoEntregaUsaPerfil: result.useProfile,
        destinoEntregaTexto: result.texto,
        destinoEntregaMapsUrl: result.mapsUrl,
        promoByImportador: _cart.promoAttributionPayloadForCheckout(),
        applyCreditByImportador: _creditPayload(),
        moneda: moneda,
      );
      final purchaseValue = _cart.lines.fold<double>(
              0,
              (sum, line) =>
                  sum + _cartUnitDollars(line, _pagoMoneda) * line.quantity) -
          appliedCredit;
      trackPurchase(
        orderId: orderId.trim().isNotEmpty
            ? orderId.trim()
            : 'checkout-${DateTime.now().millisecondsSinceEpoch}',
        valueUsd: purchaseValue,
      );

      _cart.clear();
      MainShellTabController.notifyPedidosReload();
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            appliedCredit > 0
                ? 'Pedido registrado. Se aplicaron ${_cartMoney(appliedCredit, _pagoMoneda, _tasa)} de saldo a favor.'
                : 'Pedido registrado. Los importadores recibirán un aviso para confirmar stock.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      nav.pop(true);
    } on ProfileLocationException catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(e.message), behavior: SnackBarBehavior.floating),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(cartMinOrderErrorMessage(e) ?? '$e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _checkoutMobile() async {
    final revision = _cart.accountRevision;
    final snapshot = _cart.lines
        .map((line) => CartLine(
            part: line.part,
            quantity: line.quantity,
            precioUnitarioAliadoRef: line.precioUnitarioAliadoRef))
        .toList();
    String fingerprint(Iterable<CartLine> lines) => lines
        .map((l) => '${l.part.id}:${l.quantity}:${l.precioUnitarioAliadoRef}')
        .join('|');
    final original = fingerprint(snapshot);
    final promos =
        Map<String, String>.from(_cart.promoAttributionPayloadForCheckout());
    final applyCredit = _creditPayload();
    final credits = <String, double>{
      for (final e in applyCredit.entries)
        if (e.value) e.key: _credits[e.key]?.remaining ?? 0
    };
    String? createdId;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _choosingDelivery = true);
    try {
      final exit = await Navigator.of(context)
          .push<MobileCheckoutExit>(MaterialPageRoute(
              builder: (_) => MobileCheckoutScreen(
                    profile: widget.profile,
                    lines: snapshot,
                    initialPayUsd: _pagoMoneda == _PagoMoneda.usd,
                    initialPayUsdBySupplier: _supplierCurrencies,
                    onCurrenciesChanged: (choices) {
                      if (revision == _cart.accountRevision) {
                        _cart.setSupplierCurrencies(choices);
                      }
                    },
                    rate: _tasa,
                    credits: credits,
                    loadAddresses: CheckoutDeliveryData.loadAddresses,
                    saveAddress: CheckoutDeliveryData.saveAddress,
                    deleteAddress: CheckoutDeliveryData.deleteAddress,
                    loadPickups: CheckoutDeliveryData.loadPickups,
                    submit: (submission) async {
                      if (!mounted ||
                          _submitting ||
                          !_cart.canEdit ||
                          _cart.isEmpty ||
                          revision != _cart.accountRevision ||
                          original != fingerprint(_cart.lines)) {
                        throw const MobileCheckoutException(
                            'Tu bolsa cambió. Vuelve a ella y revisa los productos antes de confirmar.');
                      }
                      if (!_cart.meetsAllImporterMinOrders) {
                        throw const MobileCheckoutException(
                            'Completa el mínimo de cada proveedor para continuar.');
                      }
                      if (snapshot.any((line) =>
                          !submission.paysUsd(line.part.ownerId ?? '') &&
                          (line.part.ownerPagoSoloDivisas ||
                              (_tasa ?? 0) <= 0))) {
                        throw const MobileCheckoutException(
                            'Revisa la moneda de pago. Hay proveedores que requieren divisas o falta la tasa BCV.');
                      }
                      setState(() => _submitting = true);
                      try {
                        final attempt = await _cart.prepareCheckoutAttempt(
                            CheckoutAttempt.signatureFor({
                              'lines': [
                                for (final l in snapshot)
                                  {
                                    'product_id': l.part.id,
                                    'cantidad': l.quantity
                                  }
                              ],
                              'destination': {
                                'profile': submission.destination.useProfile,
                                'text': submission.destination.texto,
                                'maps': submission.destination.mapsUrl,
                                'saved': submission.savedAddressId
                              },
                              'currencies': submission.currenciesBySupplier,
                              'carriers': submission.carriers,
                              'pickups': submission.deliveryBySupplier,
                              'promos': promos,
                              'credit': applyCredit,
                            }),
                            resolve: CheckoutDeliveryData.resolveAttempt);
                        final id =
                            await SupabaseService.checkoutMultiImportadorCart(
                                lines: [
                              for (final l in snapshot)
                                {
                                  'product_id': l.part.id,
                                  'cantidad': l.quantity
                                }
                            ],
                                destinoEntregaUsaPerfil:
                                    submission.destination.useProfile,
                                destinoEntregaTexto:
                                    submission.destination.texto,
                                destinoEntregaMapsUrl:
                                    submission.destination.mapsUrl,
                                promoByImportador: promos,
                                applyCreditByImportador: applyCredit,
                                carriersByImportador: submission.carriers,
                                moneda:
                                    submission.payUsd ? 'DIVISAS' : 'BOLIVARES',
                                currencyByImportador:
                                    submission.currenciesBySupplier,
                                requestId: attempt.id,
                                savedAddressId: submission.savedAddressId,
                                deliveryByImportador:
                                    submission.deliveryBySupplier);
                        if (id.trim().isEmpty) {
                          throw const MobileCheckoutException(
                              'No recibimos la referencia. Revisa Pedidos antes de volver a enviar.');
                        }
                        createdId = id;
                        final totals = MobileCheckoutTotals(
                            lines: snapshot,
                            payUsd: submission.payUsd,
                            payUsdBySupplier: submission.payUsdBySupplier,
                            credits: credits,
                            carriers: const {},
                            supplierCount: submission.carriers.length);
                        if (revision == _cart.accountRevision) {
                          _cart.completeCheckout();
                        }
                        MainShellTabController.notifyPedidosReload();
                        try {
                          trackPurchase(
                              orderId: id, valueUsd: totals.netProducts);
                        } catch (_) {
                          // Analytics must not turn a created order into a failed checkout.
                        }
                        return id;
                      } on CheckoutRecoveredException catch (recovered) {
                        createdId = recovered.orderId;
                        if (revision == _cart.accountRevision) {
                          if (recovered.samePayload &&
                              original == fingerprint(_cart.lines)) {
                            _cart.completeCheckout();
                          } else {
                            _cart.acknowledgeCheckout();
                          }
                        }
                        MainShellTabController.notifyPedidosReload();
                        throw MobileCheckoutRecovered(recovered.orderId);
                      } on ProfileLocationException catch (error) {
                        throw MobileCheckoutException(error.message);
                      } catch (error) {
                        if (error.toString().contains('PGRST202')) {
                          throw const MobileCheckoutException(
                              'Esta forma de confirmar aún no está disponible. No se creó el pedido y conservamos tu selección.');
                        }
                        final minOrderError = cartMinOrderErrorMessage(error);
                        if (minOrderError != null) {
                          throw MobileCheckoutException(minOrderError);
                        }
                        rethrow;
                      } finally {
                        if (mounted) setState(() => _submitting = false);
                      }
                    },
                  )));
      if (!mounted || createdId == null) return;
      Navigator.of(context).pop(true);
      if (exit?.viewOrder == true) {
        MainShellTabController.setPendingOpenOrderChat(false);
        MainShellTabController.setPendingNotificationType(null);
        MainShellTabController.setPendingNotificationRelatedId(createdId);
        MainShellTabController.navigateToPedidosForNotification();
      }
    } finally {
      if (mounted) setState(() => _choosingDelivery = false);
    }
  }

  Future<void> _recoverPendingCheckout() async {
    final attempt = _cart.pendingCheckoutAttempt;
    if (attempt == null ||
        _submitting ||
        _choosingDelivery ||
        _cart.restoring) {
      return;
    }
    final revision = _cart.accountRevision;
    setState(() => _submitting = true);
    try {
      final orderId = await CheckoutDeliveryData.resolveAttempt(attempt.id);
      if (!mounted || revision != _cart.accountRevision) return;
      if (orderId == null || orderId.isEmpty) {
        _cart.acknowledgeCheckout();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'La confirmación anterior no creó un pedido. Puedes revisar tu bolsa y continuar.')));
        return;
      }
      if (attempt.cartSignature == _cart.checkoutCartSignature) {
        _cart.completeCheckout();
      } else {
        _cart.acknowledgeCheckout();
      }
      MainShellTabController.notifyPedidosReload();
      final view = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
                  title: const Text('Pedido recuperado'),
                  content: Text(
                      'Tu pedido #${orderId.substring(0, 8).toUpperCase()} ya había sido creado. No se envió otra vez.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Volver a la bolsa')),
                    FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Ver pedido'))
                  ]));
      if (view == true && mounted) {
        MainShellTabController.setPendingNotificationRelatedId(orderId);
        MainShellTabController.navigateToPedidosForNotification();
        Navigator.pop(context, true);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'No pudimos verificar la confirmación anterior. Conservamos la referencia; reintenta cuando tengas conexión.')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _removeLine(CartLine line) {
    final accountRevision = _cart.accountRevision;
    final campaign = _cart.promoCampaignIdForImportador(line.part.ownerId);
    _cart.removeProduct(line.part.id);
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final narrow = MediaQuery.sizeOf(context).width < 980;
    // Con checkout sticky: subir el banner. Bolsa vacía: pegarlo abajo.
    final bottomGap = _cart.isEmpty ? 12.0 : (narrow ? 88.0 : 24.0);
    void undo() {
      if (!mounted || _submitting || accountRevision != _cart.accountRevision) {
        return;
      }
      if (_cart.lines.any((item) => item.part.id == line.part.id)) return;
      _cart.addOrIncrement(line.part,
          precioUnitarioAliadoRef: line.precioUnitarioAliadoRef,
          delta: line.quantity);
      if (campaign != null && line.part.ownerId != null) {
        _cart.setPromoAttribution(
            importadorId: line.part.ownerId!, campaignId: campaign);
      }
    }

    messenger.showSnackBar(appActionNotice(
      margin: EdgeInsets.fromLTRB(16, 0, 16, bottomGap + bottomInset),
      duration: const Duration(seconds: 5),
      content: const AppNoticeMessage(
        'Producto eliminado',
        icon: LucideGlyph.handbag,
      ),
      actionLabel: 'Deshacer',
      onAction: undo,
    ));
  }

  bool _importerGroupHasPromo(List<CartLine> lines) {
    for (final line in lines) {
      if (_cart.importadorHasPromoAttribution(line.part.ownerId)) {
        return true;
      }
    }
    return false;
  }

  ImporterMinOrderProgress? _progressFor(List<CartLine> lines) {
    final ownerId = lines.isEmpty ? null : lines.first.part.ownerId;
    final matches =
        _cart.importerMinOrderProgress().where((e) => e.importerId == ownerId);
    return matches.isEmpty ? null : matches.first;
  }

  List<Widget> _mixedSummaryRows(MobileCheckoutTotals totals, double? rate) {
    final usd = totals.suppliers.values.where((s) => s.payUsd);
    final bs = totals.suppliers.values.where((s) => !s.payUsd);
    final usdCredit = usd.fold(0.0, (sum, s) => sum + s.credit);
    final bsCredit = bs.fold(0.0, (sum, s) => sum + s.credit);
    final savings = usd.fold(0.0, (sum, s) => sum + s.usdSavings);
    return [
      if (usdCredit > 0) ...[
        _CartSummaryRow(
            label: 'Productos en USD',
            value:
                '${formatRefAmount(usd.fold(0.0, (sum, s) => sum + s.products))} USD'),
        const SizedBox(height: 8),
        _CartSummaryRow(
            label: 'Saldo a favor en USD',
            value: '−${formatRefAmount(usdCredit)} USD'),
      ],
      const SizedBox(height: 10),
      _CartSummaryRow(
          key: const ValueKey('cart-total-usd'),
          label: 'Subtotal en USD',
          value: '${formatRefAmount(totals.netUsd)} USD',
          prominent: true),
      const SizedBox(height: 12),
      Divider(height: 1, color: AppColors.divider),
      const SizedBox(height: 12),
      _CartSummaryRow(
          label: bsCredit > 0 ? 'Productos en REF' : 'Base en REF',
          value:
              '${formatRefAmount(bs.fold(0.0, (sum, s) => sum + s.products))} REF'),
      if (bsCredit > 0) ...[
        const SizedBox(height: 8),
        _CartSummaryRow(
            label: 'Saldo a favor en REF',
            value: '−${formatRefAmount(bsCredit)} REF'),
      ],
      const SizedBox(height: 10),
      _CartSummaryRow(
          key: const ValueKey('cart-total-bs'),
          label: 'Subtotal en bolívares',
          value: rate != null && rate > 0
              ? formatBsLabel(totals.netRef * rate)
              : '${formatRefAmount(totals.netRef)} REF',
          prominent: true),
      if (rate != null && rate > 0) ...[
        const SizedBox(height: 8),
        _CartBcvRate(tasa: rate, effectiveDate: _tasaEffectiveDate),
      ],
      if (savings > 0.009) ...[
        const SizedBox(height: 12),
        _CartSummaryRow(
            label: 'Ahorro en USD', value: '${formatRefAmount(savings)} USD'),
      ],
      const SizedBox(height: 10),
      const Text('Cada proveedor recibe el pago en la moneda elegida.',
          style: TextStyle(fontSize: 12)),
    ];
  }

  Widget _buildSupplierGroup(
      MapEntry<String, List<CartLine>> entry, double? tasa) {
    final progress = _progressFor(entry.value);
    final ownerId = entry.value.first.part.ownerId?.trim() ?? '';
    final mode = _modeFor(entry.value);
    final quote = MobileSupplierTotals(
        lines: entry.value,
        payUsd: mode == _PagoMoneda.usd,
        availableCredit: _creditOptOut.contains(ownerId)
            ? 0
            : _credits[ownerId]?.remaining ?? 0);
    return _CartPanel(
        key: ValueKey('cart-supplier-$ownerId'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
              child: Row(children: [
                const LucideIcon(LucideGlyph.store,
                    size: 20, color: AppColors.brandBlue),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(_cart.importadorDisplayName(entry.key),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: Color(0xFF004BDD)))),
                if (entry.value.any((l) => l.part.ownerPagoSoloDivisas)) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: _CartOfferChip(
                        label: 'Solo divisas',
                        bg: AppColors.infoSurface,
                        fg: AppColors.brandLink,
                        border: AppColors.borderSubtle),
                  ),
                ],
                if (_importerGroupHasPromo(entry.value)) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: _CartOfferChip(
                        label: 'Promoción',
                        bg: AppColors.brandBlueContainer,
                        fg: AppColors.brandLink,
                        border: AppColors.divider),
                  ),
                ],
              ]),
            ),
            Divider(height: 1, color: AppColors.divider),
            if (progress != null && progress.hasMinimum)
              Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                            progress.meets
                                ? 'Pedido mínimo ${formatMinOrderAmount(progress.minRef, progress.currency)} cubierto'
                                : 'Llevas ${formatMinOrderAmount(progress.currentRef, progress.currency)} de ${formatMinOrderAmount(progress.minRef, progress.currency)}',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: progress.meets
                                    ? AppColors.successGreen
                                    : AppColors.textPrimary)),
                        const SizedBox(height: 6),
                        ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                                value: progress.fraction,
                                minHeight: 4,
                                backgroundColor: AppColors.divider,
                                color: progress.meets
                                    ? AppColors.successGreen
                                    : AppColors.brandBlue)),
                      ])),
            if ((_credits[ownerId]?.remaining ?? 0) > 0)
              Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  child: _CreditToggle(
                    lines: entry.value,
                    balance: _credits[ownerId],
                    availableLabel: _cartMoney(
                        _credits[ownerId]?.remaining ?? 0, mode, tasa),
                    appliedLabel:
                        _cartMoney(_creditFor(entry.value), mode, tasa),
                    optedOut: _creditOptOut.contains(ownerId),
                    onChanged: (useCredit) => setState(() {
                      if (useCredit) {
                        _creditOptOut.remove(ownerId);
                      } else {
                        _creditOptOut.add(ownerId);
                      }
                    }),
                  )),
            for (var i = 0; i < entry.value.length; i++) ...[
              if (i > 0)
                Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Divider(height: 1, color: AppColors.divider)),
              _CartLineDismissible(
                lineId: entry.value[i].part.id,
                enabled: !_submitting && _cart.canEdit,
                onDismissed: () => _removeLine(entry.value[i]),
                child: _CartLineCard(
                  line: entry.value[i],
                  modo: mode,
                  tasa: tasa,
                  onRemove: _submitting || !_cart.canEdit
                      ? null
                      : () => _removeLine(entry.value[i]),
                  onQuantityChanged: _submitting || !_cart.canEdit
                      ? null
                      : (qty) => _cart.setQuantity(entry.value[i].part.id, qty),
                ),
              ),
            ],
            if (_mobileCheckout)
              Padding(
                  key: ValueKey('supplier-currency-$ownerId'),
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Divider(height: 20, color: AppColors.divider),
                        const Text('Moneda de pago',
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 13)),
                        const SizedBox(height: 8),
                        _CartCurrencySelector(
                            selected: mode.index,
                            labels: const ['Bolívares', 'USD'],
                            canPayBolivares: (_tasa ?? 0) > 0 &&
                                !entry.value.any(
                                    (line) => line.part.ownerPagoSoloDivisas),
                            onSelected: _submitting ||
                                    _choosingDelivery ||
                                    !_cart.canEdit
                                ? null
                                : (index) => _cart.setSupplierCurrencies(
                                    {ownerId: index == _PagoMoneda.usd.index})),
                        const SizedBox(height: 8),
                        if (entry.value
                            .any((line) => line.part.ownerPagoSoloDivisas))
                          const Text('Este proveedor solo acepta USD.',
                              style: TextStyle(fontSize: 12))
                        else if ((_tasa ?? 0) <= 0)
                          const Text(
                              'Bolívares no disponible: falta la tasa BCV.',
                              style: TextStyle(fontSize: 12)),
                        if (quote.usdSavings > 0.009)
                          Text(
                              mode == _PagoMoneda.usd
                                  ? 'Ahorras ${formatRefAmount(quote.usdSavings)} USD con este proveedor.'
                                  : 'Si pagas en USD, ahorras ${formatRefAmount(quote.usdSavings)} USD.',
                              style: TextStyle(
                                  fontSize: 12, color: AppColors.textPrimary))
                        else
                          const Text('Elige la moneda para este proveedor.',
                              style: TextStyle(fontSize: 12)),
                        const SizedBox(height: 10),
                        _CartSummaryRow(
                            label: 'Subtotal del proveedor',
                            value:
                                '${formatRefAmount(quote.net)} ${quote.payUsd ? 'USD' : 'REF'}'),
                        if (!quote.payUsd && (tasa ?? 0) > 0) ...[
                          const SizedBox(height: 6),
                          _CartSummaryRow(
                              label: 'En bolívares',
                              value: formatBsLabel(quote.net * tasa!)),
                        ],
                      ])),
          ],
        ));
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).width >= AppBreakpoints.mobileMenu) {
      return _buildDesktopCartScreen(this);
    }
    final tasa = _tasa;
    final mobileCheckout = _mobileCheckout;
    final mobileTotals = mobileCheckout ? _mobileTotals : null;
    final grossRef = _cart.totalRef();
    final appliedCredit = mobileTotals?.credit ?? _appliedCredit;
    final totalRef = grossRef - appliedCredit;
    final totalBs = tasa != null && tasa > 0 ? totalRef * tasa : null;
    final displayGross = mobileTotals?.products ??
        _cart.lines.fold<double>(
          0,
          (sum, line) =>
              sum + _cartUnitDollars(line, _pagoMoneda) * line.quantity,
        );
    final displayNet = displayGross - appliedCredit;
    final pagaBolivares =
        !(mobileTotals?.suppliers.values.firstOrNull?.payUsd ??
            (_pagoMoneda == _PagoMoneda.usd));
    final currencyBlocked = pagaBolivares &&
        _cart.lines.any((line) => line.part.ownerPagoSoloDivisas);
    final canConfirm = _cart.canEdit &&
        !_submitting &&
        !_choosingDelivery &&
        (mobileCheckout || !currencyBlocked) &&
        _cart.meetsAllImporterMinOrders &&
        (mobileCheckout || !pagaBolivares || totalBs != null);

    return Scaffold(
      backgroundColor: AppColors.surfaceTinted,
      appBar: _BolsaAppBar(profile: widget.profile),
      bottomNavigationBar: _cart.pendingCheckoutAttempt == null
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: OutlinedButton.icon(
                      onPressed:
                          _submitting || _choosingDelivery || _cart.restoring
                              ? null
                              : _recoverPendingCheckout,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Verificar confirmación anterior')))),
      body: _cart.restoring || (_cart.isEmpty && !_cart.canEdit)
          ? Center(
              child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    if (_cart.restoring) const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(_cart.storageMessage ?? 'Recuperando tu bolsa…',
                        textAlign: TextAlign.center),
                    if (!_cart.restoring)
                      _cart.invalidDraft
                          ? TextButton(
                              onPressed: _cart.discardInvalidDraft,
                              child: const Text('Iniciar bolsa nueva'))
                          : TextButton(
                              onPressed: _cart.retryRestore,
                              child: const Text('Reintentar')),
                  ])))
          : _cart.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        LucideIcon(
                          LucideGlyph.handbag,
                          size: 48,
                          color: AppColors.textSecondary.withOpacity(0.55),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Tu bolsa está vacía',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        if (_cart.restoreMessage != null) ...[
                          Text(_cart.restoreMessage!,
                              textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                        ],
                        Text(
                          'Encuentra los repuestos que necesitas y agrégalos aquí.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13.5,
                            height: 1.35,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.search),
                            label: const Text('Explorar catálogo')),
                      ],
                    ),
                  ),
                )
              : LayoutBuilder(builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 980 &&
                      MediaQuery.textScalerOf(context).scale(14) <= 18;
                  final groups = _cart.supplierGroups.entries.toList();
                  final statsLabel =
                      '${_cart.lines.length} ${_cart.lines.length == 1 ? 'repuesto' : 'repuestos'} • ${_cart.itemCount} unidades • ${groups.length} ${groups.length == 1 ? 'proveedor' : 'proveedores'}';
                  final heading = Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(statsLabel,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0A317B))),
                      TextButton(
                        onPressed: _submitting
                            ? null
                            : () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          minimumSize: const Size(0, 40),
                          padding: EdgeInsets.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          foregroundColor: const Color(0xFF004BDD),
                          textStyle: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                        child: const FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Seguir comprando'),
                              SizedBox(width: 4),
                              LucideIcon(LucideGlyph.arrowRight,
                                  size: 16, color: Color(0xFF004BDD)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                  final currencyBlock = mobileCheckout
                      ? Text(
                          'Elige la moneda en cada proveedor. Puedes cambiarla al revisar.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 13, color: AppColors.textSecondary),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _CartCurrencySelector(
                              selected: _pagoMoneda.index,
                              onSelected: _submitting
                                  ? null
                                  : (index) {
                                      setState(() => _pagoMoneda =
                                          _PagoMoneda.values[index]);
                                    },
                            ),
                            const SizedBox(height: 8),
                            Text(
                              pagaBolivares
                                  ? 'Pago en Bs al BCV'
                                  : 'Pago en divisas',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        );
                  final warning = _cart.restoreMessage ?? _cart.storageMessage;
                  final listRefGross = _cart.totalRef();
                  final usdSavings =
                      !pagaBolivares ? (listRefGross - displayGross) : 0.0;
                  final net = displayNet < 0 ? 0.0 : displayNet;
                  final summaryRows = <Widget>[
                    if (mobileTotals?.mixedCurrencies == true)
                      ..._mixedSummaryRows(mobileTotals!, tasa)
                    else ...[
                      _CartSummaryRow(
                          label: !pagaBolivares && usdSavings > 0.009
                              ? 'Precio sin descuento'
                              : 'Productos (${_cart.itemCount} uds)',
                          value: !pagaBolivares && usdSavings > 0.009
                              ? '${formatRefAmount(listRefGross)} USD'
                              : (pagaBolivares
                                  ? '${formatRefAmount(displayGross)} REF'
                                  : '${formatRefAmount(displayGross)} USD')),
                      if (appliedCredit > 0) ...[
                        const SizedBox(height: 10),
                        _CartSummaryRow(
                            label: 'Saldo a favor',
                            value: pagaBolivares
                                ? '−${formatRefAmount(appliedCredit)} REF'
                                : '−${formatRefAmount(appliedCredit)} USD'),
                      ],
                      if (!pagaBolivares && usdSavings > 0.009) ...[
                        const SizedBox(height: 10),
                        _CartSummaryRow(
                            label: 'Ahorro en divisas',
                            value: '−${formatRefAmount(usdSavings)} USD',
                            valueColor: AppColors.successGreen),
                      ],
                      const SizedBox(height: 12),
                      Divider(height: 1, color: AppColors.divider),
                      const SizedBox(height: 12),
                      _CartSummaryRow(
                          label: 'Subtotal',
                          value: pagaBolivares
                              ? '${formatRefAmount(net)} REF'
                              : '${formatRefAmount(net)} USD',
                          // REF/Bs: el destaque es el equivalente en Bs.
                          // USD: el destaque es el subtotal neto.
                          prominent: !pagaBolivares),
                      if (pagaBolivares && totalBs != null) ...[
                        const SizedBox(height: 12),
                        _CartSummaryRow(
                            label: 'Equivalente en Bs',
                            value: formatBsLabel(totalBs),
                            prominent: true),
                        const SizedBox(height: 8),
                        _CartBcvRate(
                            tasa: tasa!, effectiveDate: _tasaEffectiveDate),
                      ],
                      if (pagaBolivares && totalBs == null) ...[
                        const SizedBox(height: 12),
                        const Text(
                            'No hay tasa BCV vigente para cobrar en bolívares.',
                            style: TextStyle(
                                fontSize: 12, color: AppColors.brandBlue)),
                      ],
                      if (currencyBlocked && !mobileCheckout) ...[
                        const SizedBox(height: 12),
                        const Text(
                            'Un proveedor solo acepta divisas. Elige USD para continuar.'),
                      ],
                    ],
                    if (!_cart.meetsAllImporterMinOrders) ...[
                      const SizedBox(height: 12),
                      Text(
                          'Completa el mínimo de cada proveedor para continuar.',
                          style: TextStyle(
                              fontSize: 12,
                              height: 1.4,
                              color: AppColors.textPrimary)),
                    ],
                  ];
                  final summary = _CartPanel(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Resumen de tu compra',
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary)),
                          const SizedBox(height: 16),
                          ...summaryRows,
                          if (wide) ...[
                            const SizedBox(height: 12),
                            Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const LucideIcon(LucideGlyph.truck,
                                      size: 18, color: Color(0xFF004BDD)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                      child: Text(
                                          'El envío se revisa en el siguiente paso.',
                                          style: TextStyle(
                                              fontSize: 13,
                                              height: 1.4,
                                              color: AppColors.textSecondary))),
                                ]),
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: canConfirm ? _checkout : null,
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF004BDD),
                                disabledBackgroundColor:
                                    const Color(0xFF004BDD).withOpacity(0.35),
                                minimumSize: const Size(double.infinity, 50),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                                textStyle: const TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.w700),
                              ),
                              child: _submitting
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white))
                                  : const Text('Continuar con la entrega →',
                                      textAlign: TextAlign.center),
                            ),
                          ],
                        ]),
                  );
                  final checkoutBar = Material(
                    color: AppColors.card,
                    elevation: 10,
                    shadowColor: AppColors.black.withOpacity(0.12),
                    child: SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const LucideIcon(LucideGlyph.truck,
                                    size: 18, color: Color(0xFF004BDD)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'El envío se revisa en el siguiente paso.',
                                    softWrap: true,
                                    style: TextStyle(
                                      fontSize: 13,
                                      height: 1.35,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: FilledButton(
                                onPressed: canConfirm ? _checkout : null,
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF004BDD),
                                  disabledBackgroundColor:
                                      const Color(0xFF004BDD).withOpacity(0.35),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  textStyle: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                child: _submitting
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white))
                                    : const FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child:
                                            Text('Continuar con la entrega →'),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                  final products = [
                    if (warning != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(warning,
                            style: TextStyle(color: AppColors.textSecondary)),
                      ),
                    for (final group in groups)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildSupplierGroup(group, tasa),
                      ),
                  ];
                  final showSuggestions =
                      _loadingSuggestions || _suggestions.isNotEmpty;
                  final suggestions = !showSuggestions
                      ? null
                      : CartSuggestionsSection(
                          suggestions: _suggestions,
                          loading: _loadingSuggestions,
                          confirmingIds: _confirmingSuggestionIds,
                          bcvRate: pagaBolivares ? tasa : null,
                          autoPlay: widget.suggestionAutoPlay,
                          onAdd: _submitting || !_cart.canEdit
                              ? null
                              : _addSuggestion,
                        );
                  final body = Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: wide ? 1280 : 720),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                            wide ? 28 : 16, wide ? 24 : 16, wide ? 28 : 16, 0),
                        child: wide
                            ? Builder(builder: (context) {
                                WidgetsBinding.instance
                                    .addPostFrameCallback((_) {
                                  if (mounted) _syncSummaryHeight();
                                });
                                return SingleChildScrollView(
                                  padding: EdgeInsets.only(
                                    bottom: 24 +
                                        MediaQuery.paddingOf(context).bottom,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      heading,
                                      const SizedBox(height: 12),
                                      currencyBlock,
                                      const SizedBox(height: 16),
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: SizedBox(
                                              height: _summaryHeight,
                                              child: ListView(
                                                primary: false,
                                                padding: EdgeInsets.zero,
                                                children: products,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 28),
                                          SizedBox(
                                            key: _summaryKey,
                                            width: 340,
                                            child: summary,
                                          ),
                                        ],
                                      ),
                                      if (suggestions != null) ...[
                                        const SizedBox(height: 28),
                                        suggestions,
                                      ],
                                    ],
                                  ),
                                );
                              })
                            : ListView(
                                padding: EdgeInsets.only(
                                    bottom: 16 +
                                        MediaQuery.paddingOf(context).bottom),
                                children: [
                                    heading,
                                    const SizedBox(height: 12),
                                    currencyBlock,
                                    const SizedBox(height: 14),
                                    ...products,
                                    const SizedBox(height: 8),
                                    summary,
                                    if (suggestions != null) ...[
                                      const SizedBox(height: 24),
                                      suggestions,
                                    ],
                                    const SizedBox(height: 12),
                                  ]),
                      ),
                    ),
                  );
                  if (wide) return body;
                  return Column(
                    children: [
                      Expanded(child: body),
                      checkoutBar,
                    ],
                  );
                }),
    );
  }
}

/// Compact product row; supplier identity belongs to its containing group.
class _CartLineCard extends StatelessWidget {
  const _CartLineCard(
      {required this.line,
      required this.modo,
      required this.tasa,
      required this.onRemove,
      required this.onQuantityChanged});
  final CartLine line;
  final _PagoMoneda modo;
  final double? tasa;
  final VoidCallback? onRemove;
  final ValueChanged<int>? onQuantityChanged;

  @override
  Widget build(BuildContext context) {
    final part = line.part;
    final cover = part.coverImageUrl?.trim();
    final sku = (part.sku ?? '').trim();
    // Solo-divisas: siempre precio/importe en USD, aunque el resumen esté en Bs.
    final displayModo = part.ownerPagoSoloDivisas ? _PagoMoneda.usd : modo;
    final unit = _cartUnitDollars(line, displayModo);
    final showUsd = displayModo == _PagoMoneda.usd;
    final usdDiscount = showUsd
        ? ProductCatalogPricing.directSaleDiscountChipEs(
            listPriceUsd: line.precioUnitarioAliadoRef, salePriceUsd: unit)
        : null;
    final campaignChip = ProductCatalogPricing.campaignDiscountChipEs(
        part.activeCampaignDiscountPercent,
        discountRules: part.discountRules,
        quantity: line.quantity);
    final unitLabel = showUsd
        ? '${formatRefAmount(unit)} USD'
        : '${formatRefAmount(unit)} REF';
    final lineTotalLabel = showUsd
        ? '${formatRefAmount(unit * line.quantity)} USD'
        : '${formatRefAmount(unit * line.quantity)} REF';
    final stockHint = part.hasSupplierMinOrderQty
        ? 'Mín. ${part.minOrderQtyEffective} • Disp. ${part.stockForSale}'
        : 'Disp. ${part.stockForSale}';
    final thumbnail = ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
            width: 64,
            height: 64,
            child: cover != null && cover.isNotEmpty
                ? Image.network(cover,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _thumbPlaceholder())
                : _thumbPlaceholder()));
    final details =
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(part.nombre,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              height: 1.25,
              color: AppColors.textPrimary)),
      if (sku.isNotEmpty) ...[
        const SizedBox(height: 3),
        Text(sku,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ],
      const SizedBox(height: 6),
      Wrap(
        spacing: 6,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            unitLabel,
            style: TextStyle(
              fontSize: 15,
              height: 1.2,
              fontWeight: FontWeight.w800,
              color: usdDiscount != null
                  ? AppColors.successGreen
                  : AppColors.textPrimary,
            ),
          ),
          if (usdDiscount != null)
            _CartOfferChip(
              label: usdDiscount,
              bg: const Color(0xFFE5F6EA),
              fg: const Color(0xFF1B7F3A),
              border: const Color(0xFFE5F6EA),
            ),
          if (campaignChip != null)
            _CartOfferChip(
              label: campaignChip,
              bg: AppColors.brandBlueContainer,
              fg: AppColors.brandLink,
              border: AppColors.divider,
            ),
        ],
      ),
    ]);
    final remove = IconButton(
        onPressed: onRemove,
        tooltip: 'Eliminar',
        style: IconButton.styleFrom(
            minimumSize: const Size(44, 44),
            padding: EdgeInsets.zero,
            foregroundColor: AppColors.textSecondary),
        icon: const LucideIcon(LucideGlyph.trash2, size: 18));
    final stockText = Text(stockHint,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary));
    final amountStyle = TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        fontFeatures: const [FontFeature.tabularFigures()],
        color: AppColors.textPrimary);
    final totalBar = DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceTinted,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Text('Total',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(width: 12),
            Expanded(
              child: _CartMoneyText(value: lineTotalLabel, style: amountStyle),
            ),
          ],
        ),
      ),
    );
    final quantityRow = Row(
      children: [
        _CartQuantityControl(line: line, onChanged: onQuantityChanged),
        const SizedBox(width: 10),
        Expanded(child: stockText),
      ],
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      child: LayoutBuilder(builder: (context, constraints) {
        final wide = constraints.maxWidth >= 720 &&
            MediaQuery.textScalerOf(context).scale(14) <= 18;
        if (wide) {
          return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            thumbnail,
            const SizedBox(width: 12),
            Expanded(child: details),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  quantityRow,
                  const SizedBox(height: 8),
                  totalBar,
                ],
              ),
            ),
            const SizedBox(width: 4),
            remove,
          ]);
        }
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                thumbnail,
                const SizedBox(width: 12),
                Expanded(child: details),
                remove,
              ]),
              const SizedBox(height: 12),
              quantityRow,
              const SizedBox(height: 10),
              totalBar,
            ]);
      }),
    );
  }

  Widget _thumbPlaceholder() => ColoredBox(
      color: AppColors.surfaceTinted,
      child: Icon(Icons.image_outlined, color: AppColors.textMuted, size: 24));
}

class _CartQuantityControl extends StatelessWidget {
  const _CartQuantityControl({required this.line, required this.onChanged});
  final CartLine line;
  final ValueChanged<int>? onChanged;
  @override
  Widget build(BuildContext context) {
    final canDec =
        onChanged != null && line.quantity > line.part.minOrderQtyEffective;
    final canInc = onChanged != null && line.quantity < line.part.stockForSale;
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: DecoratedBox(
          decoration: BoxDecoration(
              color: AppColors.white,
              border: Border.all(color: AppColors.borderSubtle),
              borderRadius: BorderRadius.circular(12)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            _QtyButton(
                icon: Icons.remove_rounded,
                enabled: canDec,
                onTap: canDec ? () => onChanged!(line.quantity - 1) : null),
            CartQuantityField(
                quantity: line.quantity,
                minimum: line.part.minOrderQtyEffective,
                maximum: line.part.stockForSale,
                onChanged: onChanged,
                embedded: true),
            _QtyButton(
                icon: Icons.add_rounded,
                enabled: canInc,
                onTap: canInc ? () => onChanged!(line.quantity + 1) : null),
          ])),
    );
  }
}

class _CartPanel extends StatelessWidget {
  const _CartPanel(
      {super.key, required this.child, this.padding = EdgeInsets.zero});
  final Widget child;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => Material(
      color: AppColors.card,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.divider)),
      clipBehavior: Clip.antiAlias,
      child: Padding(padding: padding, child: child));
}

class _CartSummaryRow extends StatelessWidget {
  const _CartSummaryRow(
      {super.key,
      required this.label,
      required this.value,
      this.prominent = false,
      this.valueColor});
  final String label;
  final String value;
  final bool prominent;
  final Color? valueColor;
  @override
  Widget build(BuildContext context) {
    final labelStyle = TextStyle(
        fontSize: 13.5,
        fontWeight: prominent ? FontWeight.w500 : FontWeight.w400,
        color: AppColors.textSecondary);
    final valueStyle = TextStyle(
        fontSize: prominent ? 22 : 14,
        height: prominent ? 1.15 : null,
        fontWeight: prominent ? FontWeight.w800 : FontWeight.w600,
        letterSpacing: prominent ? -0.5 : null,
        fontFeatures: const [FontFeature.tabularFigures()],
        color: valueColor ?? AppColors.textPrimary);
    final labelText = Text(label, style: labelStyle);
    if (value.isEmpty) return labelText;
    final amount = _CartMoneyText(value: value, style: valueStyle);
    return LayoutBuilder(builder: (context, constraints) {
      final needed = _cartTextWidth(context, label, labelStyle) +
          12 +
          _cartTextWidth(context, value, valueStyle);
      if (needed > constraints.maxWidth) {
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [labelText, const SizedBox(height: 6), amount]);
      }
      return Row(children: [
        labelText,
        const SizedBox(width: 12),
        Expanded(child: amount),
      ]);
    });
  }
}

double _cartTextWidth(BuildContext context, String value, TextStyle style) {
  final painter = TextPainter(
      text: TextSpan(
          text: value, style: DefaultTextStyle.of(context).style.merge(style)),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      locale: Localizations.maybeLocaleOf(context),
      maxLines: 1)
    ..layout();
  final width = painter.width.ceilToDouble();
  painter.dispose();
  return width;
}

/// Keep the currency and full value together, including unusually long totals.
class _CartMoneyText extends StatelessWidget {
  const _CartMoneyText({required this.value, required this.style});
  final String value;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerRight,
      child: Text(value,
          maxLines: 1,
          softWrap: false,
          textAlign: TextAlign.right,
          style: style));
}

class _CartBcvRate extends StatelessWidget {
  const _CartBcvRate({required this.tasa, this.effectiveDate});
  final double tasa;
  final DateTime? effectiveDate;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontSize: 12, color: AppColors.textSecondary);
    final date = effectiveDate;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(
        'Tasa BCV: ${formatBsLabel(tasa, fractionDigits: 3)} por REF',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style,
      ),
      if (date != null) ...[
        const SizedBox(height: 3),
        Text(
            'Vigencia BCV: ${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}',
            style: style),
      ],
    ]);
  }
}

class _CartCurrencySelector extends StatelessWidget {
  const _CartCurrencySelector(
      {required this.selected,
      required this.onSelected,
      this.labels = const ['REF / Bs', 'USD'],
      this.canPayBolivares = true});
  final int selected;
  final ValueChanged<int>? onSelected;
  final List<String> labels;
  final bool canPayBolivares;
  static const _active = Color(0xFF004BDD);
  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
            color: AppColors.surfaceTinted,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.borderSubtle)),
        child: Padding(
            padding: const EdgeInsets.all(4),
            child: Row(children: [
              for (var i = 0; i < 2; i++)
                Expanded(
                    child: Semantics(
                  selected: i == selected,
                  button: true,
                  enabled: onSelected != null && (i != 0 || canPayBolivares),
                  child: Material(
                    color: i == selected ? _active : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                    child: InkWell(
                      onTap: onSelected == null || (i == 0 && !canPayBolivares)
                          ? null
                          : () => onSelected!(i),
                      borderRadius: BorderRadius.circular(999),
                      child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 44),
                          child: Center(
                              child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4, vertical: 10),
                                  child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(labels[i],
                                          textAlign: TextAlign.center,
                                          maxLines: 1,
                                          style: TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w700,
                                              color: i == selected
                                                  ? AppColors.white
                                                  : (i == 0 && !canPayBolivares
                                                      ? AppColors.textMuted
                                                      : AppColors
                                                          .textPrimary))))))),
                    ),
                  ),
                )),
            ])),
      );
}

class _CartOfferChip extends StatelessWidget {
  const _CartOfferChip({
    required this.label,
    required this.bg,
    required this.fg,
    required this.border,
  });

  final String label;
  final Color bg;
  final Color fg;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: fg,
        ),
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  const _QtyButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
        button: true,
        enabled: enabled,
        label: icon == Icons.add_rounded
            ? 'Aumentar cantidad'
            : 'Reducir cantidad',
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(
                icon,
                size: 18,
                color: enabled
                    ? Theme.of(context).colorScheme.primary
                    : AppColors.textMuted,
              ),
            ),
          ),
        ));
  }
}

class _CreditToggle extends StatelessWidget {
  const _CreditToggle({
    required this.lines,
    required this.balance,
    required this.availableLabel,
    required this.appliedLabel,
    required this.optedOut,
    required this.onChanged,
  });

  final List<CartLine> lines;
  final ImporterCreditBalance? balance;
  final String availableLabel;
  final String appliedLabel;
  final bool optedOut;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final available = balance?.remaining ?? 0;
    if (lines.isEmpty || available <= 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.brandBlueContainer,
        borderRadius: BorderRadius.circular(12),
        child: CheckboxListTile(
          value: !optedOut,
          onChanged: (value) => onChanged(value ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          title: Text(
            optedOut
                ? 'Usar saldo a favor · $availableLabel'
                : 'Saldo a favor · −$appliedLabel',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: AppColors.textPrimary,
            ),
          ),
          subtitle: Text(
            'Se descuenta de este proveedor en el próximo pedido. El mínimo se calcula antes del saldo.',
            style: TextStyle(
              fontSize: 12,
              height: 1.3,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Cabecera azul del mock: back + avatar + «Tu bolsa» / B2B CONECTA.
class _BolsaAppBar extends StatefulWidget implements PreferredSizeWidget {
  const _BolsaAppBar({required this.profile});

  final ProfileModel profile;

  /// Más alto que [kToolbarHeight] para dejar aire bajo el status bar.
  static const double toolbarHeight = 68;

  @override
  Size get preferredSize => const Size.fromHeight(toolbarHeight);

  @override
  State<_BolsaAppBar> createState() => _BolsaAppBarState();
}

class _BolsaAppBarState extends State<_BolsaAppBar> {
  String? _signedLogoUrl;
  Object? _logoRequestKey;

  @override
  void initState() {
    super.initState();
    _resolveLogo(widget.profile.logoStoragePath?.trim());
  }

  @override
  void didUpdateWidget(covariant _BolsaAppBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final path = widget.profile.logoStoragePath?.trim();
    if (path != oldWidget.profile.logoStoragePath?.trim()) {
      _resolveLogo(path);
    }
  }

  void _resolveLogo(String? path) {
    final key = path ?? Object();
    _logoRequestKey = key;
    if (path == null || path.isEmpty) {
      setState(() => _signedLogoUrl = null);
      return;
    }
    SupabaseService.createSignedUrlForProfileLogo(path).then((url) {
      if (!mounted || _logoRequestKey != key) return;
      setState(() => _signedLogoUrl = url);
    }).catchError((_) {
      if (!mounted || _logoRequestKey != key) return;
      setState(() => _signedLogoUrl = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    const headerBlue = Color(0xFF004BDD);
    Widget logoFace({required Widget child}) => Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.white,
            border:
                Border.all(color: AppColors.white.withOpacity(0.9), width: 1.5),
          ),
          clipBehavior: Clip.antiAlias,
          child: child,
        );
    final logo = logoFace(
      child: _signedLogoUrl != null
          ? Image.network(
              _signedLogoUrl!,
              width: 40,
              height: 40,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Center(
                child: LucideIcon(
                  LucideGlyph.store,
                  size: 18,
                  color: headerBlue,
                ),
              ),
            )
          : const Center(
              child: LucideIcon(
                LucideGlyph.store,
                size: 18,
                color: headerBlue,
              ),
            ),
    );
    return AppBar(
      toolbarHeight: _BolsaAppBar.toolbarHeight,
      backgroundColor: headerBlue,
      foregroundColor: AppColors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      systemOverlayStyle: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(22)),
      ),
      leading: IconButton(
        tooltip: 'Volver',
        onPressed: () => Navigator.of(context).maybePop(),
        icon: const LucideIcon(LucideGlyph.arrowLeft, color: AppColors.white),
      ),
      titleSpacing: 0,
      title: Row(
        children: [
          logo,
          const SizedBox(width: 10),
          const Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: B2bHeaderTitle(
                title: Text(
                  'Tu bolsa',
                  style: TextStyle(
                    color: AppColors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                    height: 1.1,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Swipe-to-delete on narrow viewports; trash button remains for all sizes.
class _CartLineDismissible extends StatelessWidget {
  const _CartLineDismissible({
    required this.lineId,
    required this.enabled,
    required this.onDismissed,
    required this.child,
  });

  final String lineId;
  final bool enabled;
  final VoidCallback onDismissed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final swipe = enabled && MediaQuery.sizeOf(context).width < 768;
    if (!swipe) return KeyedSubtree(key: ValueKey(lineId), child: child);
    return Dismissible(
      key: ValueKey('dismiss-$lineId'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismissed(),
      background: Container(
        alignment: Alignment.centerRight,
        decoration: const BoxDecoration(
          color: Color(0xFFE11D48),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            LucideIcon(LucideGlyph.trash2, color: AppColors.white, size: 20),
            SizedBox(height: 6),
            Text(
              'Eliminar',
              style: TextStyle(
                color: AppColors.white,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
      child: ColoredBox(color: AppColors.card, child: child),
    );
  }
}
