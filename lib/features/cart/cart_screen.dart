import 'package:flutter/material.dart';

import 'package:motolink_pro_app/features/profile/profile_location_exception.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';
import 'cart_service.dart';
import 'cart_quantity_field.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'package:motolink_pro_app/app/main_shell_tab.dart';
import 'package:motolink_pro_app/features/ads/meta_pixel.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/utils/ves_amount_format.dart';
import 'package:motolink_pro_app/features/catalog/product_catalog_pricing.dart';
import 'package:motolink_pro_app/features/orders/shared/order_return_rules.dart';
import 'package:motolink_pro_app/features/logistics/envio_politica.dart';
import 'package:motolink_pro_app/features/logistics/envio_politica_badge.dart';
import 'package:motolink_pro_app/features/orders/shared/orders_service.dart';
import 'importer_min_order.dart';
import 'min_order_currency.dart';

/// Carrito multi-importador: agrupa por importador y confirma un solo pedido maestro.
class CartScreen extends StatefulWidget {
  const CartScreen({
    super.key,
    required this.profile,
    this.liveTasaBcv,
  });

  final ProfileModel profile;
  final double? liveTasaBcv;

  @override
  State<CartScreen> createState() => _CartScreenState();
}

enum _PagoMoneda { bolivares, usd }

/// Every display currency starts with the same effective price as checkout.
double _cartUnitDollars(CartLine line, _PagoMoneda modo) {
  switch (modo) {
    case _PagoMoneda.usd:
      return ProductCatalogPricing.aliadoUnitUsdPaymentLine(
          refUnitUsd: line.precioUnitarioAliadoRef,
          salePriceUsd: line.part.salePriceUsd,
          discountRules: line.part.discountRules,
          ownerPagoSoloDivisas: line.part.ownerPagoSoloDivisas);
    case _PagoMoneda.bolivares:
      return line.precioUnitarioAliadoRef;
  }
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

  @override
  void initState() {
    super.initState();
    _tasa = widget.liveTasaBcv;
    _cart.addListener(_onCart);
    _loadCredits();
    SupabaseService.fetchGlobalTasaBcvRecord().then((record) {
      if (!mounted || record == null) return;
      setState(() {
        _tasa = record.tasa;
        _tasaEffectiveDate = DateTime.tryParse(record.effectiveDate ?? '');
      });
    }).catchError((_) {});
  }

  void _onCart() {
    if (mounted) setState(() {});
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
            sum + _cartUnitDollars(line, _pagoMoneda) * line.quantity,
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
    _cart.removeListener(_onCart);
    super.dispose();
  }

  Future<void> _checkout() async {
    if (!_cart.canEdit ||
        _cart.isEmpty ||
        _submitting ||
        _choosingDelivery ||
        !_cart.meetsAllImporterMinOrders) {
      return;
    }

    final accountRevision = _cart.accountRevision;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _choosingDelivery = true);
    final result = await showDialog<_DestinoEntregaResult?>(
      context: context,
      builder: (ctx) => _DestinoEntregaDialog(
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
        !_cart.meetsAllImporterMinOrders) return;

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

  void _removeLine(CartLine line) {
    final accountRevision = _cart.accountRevision;
    final campaign = _cart.promoCampaignIdForImportador(line.part.ownerId);
    _cart.removeProduct(line.part.id);
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      content: Text('${line.part.nombre} eliminado del carrito.'),
      action: SnackBarAction(
          label: 'Deshacer',
          onPressed: () {
            if (!mounted ||
                _submitting ||
                accountRevision != _cart.accountRevision) return;
            if (_cart.lines.any((item) => item.part.id == line.part.id)) return;
            _cart.addOrIncrement(line.part,
                precioUnitarioAliadoRef: line.precioUnitarioAliadoRef,
                delta: line.quantity);
            if (campaign != null && line.part.ownerId != null) {
              _cart.setPromoAttribution(
                  importadorId: line.part.ownerId!, campaignId: campaign);
            }
          }),
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

  Widget _buildSupplierGroup(
      MapEntry<String, List<CartLine>> entry, double? tasa) {
    final progress = _progressFor(entry.value);
    final ownerId = entry.value.first.part.ownerId?.trim() ?? '';
    return _CartPanel(
        child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Row(children: [
            const Icon(Icons.storefront_outlined,
                size: 20, color: AppColors.brandBlue),
            const SizedBox(width: 10),
            Expanded(
                child: Text(_cart.importadorDisplayName(entry.key),
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppColors.textPrimary))),
            if (_importerGroupHasPromo(entry.value)) ...[
              const SizedBox(width: 8),
              _CartOfferChip(
                  label: 'Promoción',
                  bg: AppColors.brandBlueContainer,
                  fg: AppColors.brandBlue,
                  border: AppColors.divider),
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
                    _credits[ownerId]?.remaining ?? 0, _pagoMoneda, tasa),
                appliedLabel:
                    _cartMoney(_creditFor(entry.value), _pagoMoneda, tasa),
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
          _CartLineCard(
            key: ValueKey(entry.value[i].part.id),
            line: entry.value[i],
            modo: _pagoMoneda,
            tasa: tasa,
            onRemove: _submitting || !_cart.canEdit
                ? null
                : () => _removeLine(entry.value[i]),
            onQuantityChanged: _submitting || !_cart.canEdit
                ? null
                : (qty) => _cart.setQuantity(entry.value[i].part.id, qty),
          ),
        ],
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    final tasa = _tasa;
    final grossRef = _cart.totalRef();
    final appliedCredit = _appliedCredit;
    final totalRef = grossRef - appliedCredit;
    final totalBs = tasa != null && tasa > 0 ? totalRef * tasa : null;
    final displayGross = _cart.lines.fold<double>(
      0,
      (sum, line) => sum + _cartUnitDollars(line, _pagoMoneda) * line.quantity,
    );
    final displayNet = displayGross - appliedCredit;
    final pagaBolivares = _pagoMoneda != _PagoMoneda.usd;
    final currencyBlocked = pagaBolivares &&
        _cart.lines.any((line) => line.part.ownerPagoSoloDivisas);
    final canConfirm = _cart.canEdit &&
        !_submitting &&
        !_choosingDelivery &&
        !currencyBlocked &&
        _cart.meetsAllImporterMinOrders &&
        (!pagaBolivares || totalBs != null);

    return Scaffold(
      backgroundColor: AppColors.surfaceTinted,
      appBar: AppBar(
        title: const Text(
          'Carrito',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: _cart.restoring || (_cart.isEmpty && !_cart.canEdit)
          ? Center(
              child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    if (_cart.restoring) const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(_cart.storageMessage ?? 'Recuperando tu carrito…',
                        textAlign: TextAlign.center),
                    if (!_cart.restoring)
                      _cart.invalidDraft
                          ? TextButton(
                              onPressed: _cart.discardInvalidDraft,
                              child: const Text('Iniciar carrito nuevo'))
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
                        Icon(
                          Icons.shopping_cart_outlined,
                          size: 48,
                          color: AppColors.textSecondary.withOpacity(0.55),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Su carrito está vacío',
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
                  final heading = LayoutBuilder(builder: (context, box) {
                    final title = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Revisa tu compra',
                            style: TextStyle(
                                fontSize: 24,
                                height: 1.2,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary)),
                        const SizedBox(height: 6),
                        Text(
                            '${_cart.lines.length} ${_cart.lines.length == 1 ? 'repuesto' : 'repuestos'} · ${_cart.itemCount} unidades · ${groups.length} ${groups.length == 1 ? 'proveedor' : 'proveedores'}',
                            style: TextStyle(
                                fontSize: 13, color: AppColors.textSecondary)),
                      ],
                    );
                    final back = TextButton.icon(
                      onPressed: _submitting
                          ? null
                          : () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_rounded, size: 18),
                      label: const Text('Seguir comprando'),
                      style:
                          TextButton.styleFrom(minimumSize: const Size(0, 44)),
                    );
                    return box.maxWidth < 580
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [title, const SizedBox(height: 4), back])
                        : Row(children: [Expanded(child: title), back]);
                  });
                  final warning = _cart.restoreMessage ?? _cart.storageMessage;
                  final summary = _CartPanel(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Resumen del pedido',
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary)),
                          const SizedBox(height: 16),
                          _CartCurrencySelector(
                            selected: _pagoMoneda.index,
                            onSelected: _submitting
                                ? null
                                : (index) {
                                    setState(() => _pagoMoneda =
                                        _PagoMoneda.values[index]);
                                  },
                          ),
                          const SizedBox(height: 16),
                          if (pagaBolivares || appliedCredit > 0)
                            _CartSummaryRow(
                                label: pagaBolivares && appliedCredit <= 0
                                    ? 'Referencia'
                                    : 'Productos (${_cart.itemCount} uds)',
                                value: pagaBolivares
                                    ? '${formatRefAmount(displayGross)} REF'
                                    : _cartMoney(
                                        displayGross, _pagoMoneda, tasa)),
                          if (appliedCredit > 0) ...[
                            const SizedBox(height: 10),
                            _CartSummaryRow(
                                label: 'Saldo a favor',
                                value: pagaBolivares
                                    ? '−${formatRefAmount(appliedCredit)} REF'
                                    : '−${_cartMoney(appliedCredit, _pagoMoneda, tasa)}'),
                            if (pagaBolivares) ...[
                              const SizedBox(height: 10),
                              _CartSummaryRow(
                                  label: 'Referencia',
                                  value:
                                      '${formatRefAmount(displayNet < 0 ? 0 : displayNet)} REF'),
                            ],
                          ],
                          if (pagaBolivares || appliedCredit > 0) ...[
                            const SizedBox(height: 12),
                            Divider(height: 1, color: AppColors.divider),
                          ],
                          const SizedBox(height: 12),
                          _CartSummaryRow(
                              label: 'Subtotal',
                              value: _cartMoney(displayNet < 0 ? 0 : displayNet,
                                  _pagoMoneda, tasa),
                              prominent: true),
                          if (pagaBolivares && totalBs != null) ...[
                            const SizedBox(height: 8),
                            _CartBcvRate(
                                tasa: tasa!, effectiveDate: _tasaEffectiveDate),
                          ],
                          const SizedBox(height: 12),
                          Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.local_shipping_outlined,
                                    size: 18, color: AppColors.textSecondary),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: Text(
                                        'Revisa la entrega en el siguiente paso.',
                                        style: TextStyle(
                                            fontSize: 12,
                                            height: 1.4,
                                            color: AppColors.textSecondary))),
                              ]),
                          if (pagaBolivares && totalBs == null) ...[
                            const SizedBox(height: 12),
                            const Text(
                                'No hay tasa BCV vigente para cobrar en bolívares.',
                                style: TextStyle(
                                    fontSize: 12, color: AppColors.brandBlue)),
                          ],
                          if (currencyBlocked) ...[
                            const SizedBox(height: 12),
                            const Text(
                                'Un proveedor solo acepta divisas. Elige Divisas (USD) para continuar.'),
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
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: canConfirm ? _checkout : null,
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(double.infinity, 48),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              textStyle: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                            child: _submitting
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : const Text('Continuar con la entrega',
                                    textAlign: TextAlign.center),
                          ),
                        ]),
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
                  return Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: wide ? 1100 : 720),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                            wide ? 24 : 16, wide ? 28 : 20, wide ? 24 : 16, 0),
                        child: wide
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                    heading,
                                    const SizedBox(height: 24),
                                    Expanded(
                                        child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                          Expanded(
                                              child: ListView(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          bottom: 24),
                                                  children: products)),
                                          const SizedBox(width: 24),
                                          SizedBox(
                                              width: 312,
                                              child: SingleChildScrollView(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          bottom: 24),
                                                  child: summary)),
                                        ])),
                                  ])
                            : ListView(
                                padding: EdgeInsets.only(
                                    bottom: 24 +
                                        MediaQuery.paddingOf(context).bottom),
                                children: [
                                    heading,
                                    const SizedBox(height: 16),
                                    ...products,
                                    const SizedBox(height: 4),
                                    summary,
                                  ]),
                      ),
                    ),
                  );
                }),
    );
  }
}

/// Compact product row; supplier identity belongs to its containing group.
class _CartLineCard extends StatelessWidget {
  const _CartLineCard(
      {super.key,
      required this.line,
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
    final unit = _cartUnitDollars(line, modo);
    final promo = ProductCatalogPricing.campaignDiscountChipEs(
        part.activeCampaignDiscountPercent,
        discountRules: part.discountRules,
        quantity: line.quantity);
    final thumbnail = ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
            width: 56,
            height: 56,
            child: cover != null && cover.isNotEmpty
                ? Image.network(cover,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => _thumbPlaceholder())
                : _thumbPlaceholder()));
    final details =
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(part.nombre,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              height: 1.3,
              color: AppColors.textPrimary)),
      if (sku.isNotEmpty) ...[
        const SizedBox(height: 3),
        Text('SKU $sku',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ],
      const SizedBox(height: 4),
      Text(
          modo == _PagoMoneda.bolivares
              ? '${formatRefAmount(unit)} REF / ud'
              : '${_cartMoney(unit, modo, tasa)} / ud',
          style: TextStyle(
              fontSize: 12, height: 1.3, color: AppColors.textSecondary)),
      if (modo == _PagoMoneda.bolivares) ...[
        const SizedBox(height: 2),
        Text(_cartMoney(unit, modo, tasa),
            style: TextStyle(
                fontSize: 11, height: 1.3, color: AppColors.textSecondary)),
      ],
      if (promo != null ||
          (modo == _PagoMoneda.usd && part.tieneOfertaDirecta)) ...[
        const SizedBox(height: 6),
        _CartOfferChip(
            label: promo ?? 'Oferta aplicada',
            bg: AppColors.brandBlueContainer,
            fg: AppColors.brandBlue,
            border: AppColors.divider),
      ],
    ]);
    final remove = IconButton(
        onPressed: onRemove,
        tooltip: 'Quitar del carrito',
        style: IconButton.styleFrom(
            minimumSize: const Size(44, 44),
            padding: EdgeInsets.zero,
            foregroundColor: AppColors.textSecondary),
        icon: const Icon(Icons.close_rounded, size: 18));
    final quantity = Column(mainAxisSize: MainAxisSize.min, children: [
      _CartQuantityControl(line: line, onChanged: onQuantityChanged),
      const SizedBox(height: 5),
      Text('Mín. ${part.minOrderQtyEffective} · Disp. ${part.stockForSale}',
          style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
    ]);
    final amountValue = _cartMoney(unit * line.quantity, modo, tasa);
    final amountStyle = TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        fontFeatures: const [FontFeature.tabularFigures()],
        color: AppColors.textPrimary);
    final amountWidth = _cartTextWidth(context, amountValue, amountStyle)
        .clamp(104.0, double.infinity);
    final amount = Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Importe',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          const SizedBox(height: 3),
          if (modo == _PagoMoneda.bolivares) ...[
            _CartMoneyText(
                value: '${formatRefAmount(unit * line.quantity)} REF',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 2),
          ],
          _CartMoneyText(value: amountValue, style: amountStyle),
        ]);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(builder: (context, constraints) {
        final wide = constraints.maxWidth >= 640 &&
            amountWidth <= constraints.maxWidth - 520 &&
            MediaQuery.textScalerOf(context).scale(14) <= 18;
        if (wide) {
          return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            thumbnail,
            const SizedBox(width: 12),
            Expanded(child: details),
            const SizedBox(width: 12),
            quantity,
            const SizedBox(width: 16),
            SizedBox(width: amountWidth, child: amount),
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
              const SizedBox(height: 14),
              Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 12,
                  children: [quantity, amount]),
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
    return DecoratedBox(
        decoration: BoxDecoration(
            border: Border.all(color: AppColors.borderSubtle),
            borderRadius: BorderRadius.circular(10)),
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
        ]));
  }
}

class _CartPanel extends StatelessWidget {
  const _CartPanel({required this.child, this.padding = EdgeInsets.zero});
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
      {required this.label, required this.value, this.prominent = false});
  final String label;
  final String value;
  final bool prominent;
  @override
  Widget build(BuildContext context) {
    final labelStyle = TextStyle(
        fontSize: 13,
        fontWeight: prominent ? FontWeight.w500 : FontWeight.w400,
        color: AppColors.textSecondary);
    final valueStyle = TextStyle(
        fontSize: prominent ? 24 : 13,
        height: prominent ? 1.15 : null,
        fontWeight: prominent ? FontWeight.w700 : FontWeight.w600,
        letterSpacing: prominent ? -0.5 : null,
        fontFeatures: const [FontFeature.tabularFigures()],
        color: AppColors.textPrimary);
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
    final style = TextStyle(fontSize: 11, color: AppColors.textSecondary);
    final date = effectiveDate;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 4, runSpacing: 2, children: [
        Text('Tasa BCV: 1 REF =', style: style),
        Text(formatBsLabel(tasa, fractionDigits: 4),
            maxLines: 1, softWrap: false, style: style),
      ]),
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
      {required this.selected, required this.onSelected});
  final int selected;
  final ValueChanged<int>? onSelected;
  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
            color: AppColors.surfaceTinted,
            borderRadius: BorderRadius.circular(10)),
        child: Padding(
            padding: const EdgeInsets.all(4),
            child: Row(children: [
              for (var i = 0; i < 2; i++)
                Expanded(
                    child: Semantics(
                  selected: i == selected,
                  button: true,
                  child: Material(
                    color: i == selected
                        ? AppColors.brandBlue
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      onTap: onSelected == null ? null : () => onSelected!(i),
                      borderRadius: BorderRadius.circular(8),
                      child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 44),
                          child: Center(
                              child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4, vertical: 10),
                                  child: Text(
                                      const [
                                        'Bolívares (REF)',
                                        'Divisas (USD)'
                                      ][i],
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: i == selected
                                              ? AppColors.white
                                              : AppColors.textPrimary))))),
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

/// Resultado del diálogo de destino: se devuelve al confirmar (no al cancelar).
class _DestinoEntregaResult {
  const _DestinoEntregaResult({
    required this.useProfile,
    this.texto,
    this.mapsUrl,
  });

  final bool useProfile;
  final String? texto;
  final String? mapsUrl;
}

/// Destino: dirección fiscal del perfil, o formulario de ubicación alterna.
class _DestinoEntregaDialog extends StatefulWidget {
  const _DestinoEntregaDialog(
      {required this.profile, required this.paymentSummary});

  final ProfileModel profile;

  final String paymentSummary;

  @override
  State<_DestinoEntregaDialog> createState() => _DestinoEntregaDialogState();
}

class _DestinoEntregaDialogState extends State<_DestinoEntregaDialog> {
  bool _usaPerfil = true;
  final _estado = TextEditingController();
  final _ciudad = TextEditingController();
  final _domicilio = TextEditingController();
  final _maps = TextEditingController();

  @override
  void dispose() {
    _estado.dispose();
    _ciudad.dispose();
    _domicilio.dispose();
    _maps.dispose();
    super.dispose();
  }

  InputDecoration _field(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: AppColors.fieldFill,
      border: OutlineInputBorder(
        borderRadius: AppDecorations.radius12,
        borderSide: BorderSide.none,
      ),
    );
  }

  String _armarTextoEntrega() {
    final e = _estado.text.trim();
    final c = _ciudad.text.trim();
    final d = _domicilio.text.trim();
    return [
      if (e.isNotEmpty) 'Estado: $e',
      if (c.isNotEmpty) 'Ciudad: $c',
      if (d.isNotEmpty) 'Domicilio: $d',
    ].join('\n');
  }

  void _confirmar() {
    if (_usaPerfil) {
      if (!widget.profile.hasFiscalMapsShareLink) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Registre el enlace de Google Maps de su domicilio fiscal en Mi perfil.',
            ),
          ),
        );
        return;
      }
    } else {
      final e = _estado.text.trim();
      final c = _ciudad.text.trim();
      final d = _domicilio.text.trim();
      if (e.isEmpty || c.isEmpty || d.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Complete estado, ciudad y domicilio de la entrega alterna.',
            ),
          ),
        );
        return;
      }
      final m = _maps.text.trim();
      final u = Uri.tryParse(m);
      if (m.isEmpty ||
          u == null ||
          !u.hasScheme ||
          (u.scheme != 'http' && u.scheme != 'https')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Indique un enlace válido de Google Maps (http o https) para la entrega alterna.',
            ),
          ),
        );
        return;
      }
    }
    final text = _usaPerfil ? null : _armarTextoEntrega();
    final maps = _usaPerfil ? null : _maps.text.trim();
    Navigator.of(context).pop(
      _DestinoEntregaResult(
        useProfile: _usaPerfil,
        texto: text,
        mapsUrl: maps,
      ),
    );
  }

  List<String> _envioNotas() {
    final notes = <String>[];
    for (final entry in CartService.instance.supplierGroups.entries) {
      if (entry.value.isEmpty) continue;
      final line = entry.value.first;
      final note = EnvioPolitica.notaConfirmacion(
        tipo: line.part.ownerEnvioTipo,
        proveedor: CartService.instance.importadorDisplayName(entry.key),
        minimoGratis: line.part.ownerEnvioGratisMinimo,
      );
      if (note != null) notes.add(note);
    }
    return notes;
  }

  String get _fiscalSummary {
    final parts = <String>[
      if ((widget.profile.estado ?? '').trim().isNotEmpty)
        widget.profile.estado!.trim(),
      if ((widget.profile.ciudad ?? '').trim().isNotEmpty)
        widget.profile.ciudad!.trim(),
      if ((widget.profile.direccion ?? '').trim().isNotEmpty)
        widget.profile.direccion!.trim(),
    ];
    if (parts.isEmpty) {
      return 'Complete la dirección fiscal en Mi perfil.';
    }
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('¿Dónde entregamos el pedido?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.paymentSummary,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
              'La tienda recibe la mercancía en esta dirección. Puede usar la de su perfil u otra para este pedido.',
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            EnvioPoliticaNotas(notas: _envioNotas()),
            _LocationChoice(
              selected: _usaPerfil,
              icon: Icons.storefront_outlined,
              title: 'Dirección de mi perfil',
              body: widget.profile.hasFiscalMapsShareLink
                  ? _fiscalSummary
                  : 'Falta el enlace de Google Maps en Mi perfil.',
              onTap: () => setState(() => _usaPerfil = true),
            ),
            const SizedBox(height: 8),
            _LocationChoice(
              selected: !_usaPerfil,
              icon: Icons.edit_location_alt_outlined,
              title: 'Otra dirección',
              body: 'Solo para este pedido. El enlace de mapas es obligatorio.',
              onTap: () => setState(() => _usaPerfil = false),
            ),
            if (!_usaPerfil) ...[
              const SizedBox(height: 4),
              const Text(
                'Ubicación alterna de entrega',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.brandBlue,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Esta dirección sustituye a la fiscal para este pedido. '
                'El enlace de Google Maps es obligatorio para ubicar el sitio con precisión.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _estado,
                textCapitalization: TextCapitalization.words,
                decoration: _field('Estado'),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _ciudad,
                textCapitalization: TextCapitalization.words,
                decoration: _field('Ciudad'),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _domicilio,
                textCapitalization: TextCapitalization.sentences,
                minLines: 2,
                maxLines: 4,
                decoration: _field('Domicilio (calle, sector, ref.)'),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _maps,
                keyboardType: TextInputType.url,
                decoration: _field(
                  'URL de Google Maps',
                  hint: 'https://…',
                ),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _confirmar(),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _confirmar,
          child: const Text('Confirmar pedido'),
        ),
      ],
    );
  }
}

class _LocationChoice extends StatelessWidget {
  const _LocationChoice({
    required this.selected,
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.brandBlueContainer : AppColors.card,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.brand : AppColors.borderSubtle,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: AppColors.brand),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      body,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? AppColors.brand : AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
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
