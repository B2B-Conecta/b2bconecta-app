part of 'cart_screen.dart';

/// Bolsa de escritorio. La rama móvil de [CartScreen.build] no pasa por aquí.
Widget _buildDesktopCartScreen(_CartScreenState state) {
  final context = state.context;
  final theme = B2BThemeExtension.of(context);
  final cart = state._cart;
  final tasa = state._tasa;
  final totals = state._mobileTotals;
  final groups = cart.supplierGroups.entries.toList();
  final unitsReady = state._meetsSupplierMinimumUnits;
  final amountReady = state._meetsSupplierMinimumAmounts;
  final canConfirm = cart.canEdit &&
      !state._submitting &&
      !state._choosingDelivery &&
      state._meetsSupplierMinimums;
  return Scaffold(
    backgroundColor: theme.background,
    body: cart.restoring || (cart.isEmpty && !cart.canEdit)
        ? _DesktopCartMessage(
            loading: cart.restoring,
            message: cart.storageMessage ?? 'Recuperando tu bolsa…',
            action: cart.restoring
                ? null
                : cart.invalidDraft
                    ? ('Iniciar bolsa nueva', cart.discardInvalidDraft)
                    : ('Reintentar', cart.retryRestore),
          )
        : cart.isEmpty
            ? const _DesktopCartEmpty()
            : LayoutBuilder(builder: (context, constraints) {
                final sideBySide = constraints.maxWidth >= 980 &&
                    constraints.maxHeight >= 520 &&
                    MediaQuery.textScalerOf(context).scale(14) <= 21;
                final warning = cart.restoreMessage ?? cart.storageMessage;
                final products = <Widget>[
                  if (warning != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(warning,
                          style: TextStyle(color: theme.textSecondary)),
                    ),
                  for (final group in groups)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _DesktopSupplierGroup(state: state, entry: group),
                    ),
                ];
                final summary = _DesktopCartSummary(
                  state: state,
                  totals: totals,
                  canConfirm: canConfirm,
                  unitsReady: unitsReady,
                  amountReady: amountReady,
                );
                final suggestions =
                    !state._loadingSuggestions && state._suggestions.isEmpty
                        ? null
                        : _DesktopCartSuggestions(
                            suggestions: state._suggestions,
                            loading: state._loadingSuggestions,
                            bcvRate: tasa,
                            autoPlay: state.widget.suggestionAutoPlay,
                            onAdd: state._submitting || !cart.canEdit
                                ? null
                                : state._addSuggestion,
                          );
                final header = _DesktopCartHeader(
                    state: state, groups: groups.length);
                final bottom = 36 + MediaQuery.paddingOf(context).bottom;
                final following = <Widget>[
                    if (suggestions != null) ...[
                      const SizedBox(height: 28),
                      suggestions,
                    ],
                ];
                if (sideBySide) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(28, 20, 28, 0),
                    child: Column(children: [
                      header,
                      const SizedBox(height: 18),
                      Expanded(
                        child: ListView(
                          padding: EdgeInsets.only(bottom: bottom),
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: Column(children: products)),
                                const SizedBox(width: 24),
                                SizedBox(width: 340, child: summary),
                              ],
                            ),
                            ...following,
                          ],
                        ),
                      ),
                    ]),
                  );
                }
                return ListView(
                  padding: EdgeInsets.fromLTRB(20, 20, 20, bottom),
                  children: [
                    header,
                    const SizedBox(height: 18),
                    ...products,
                    summary,
                    ...following,
                  ],
                );
              }),
  );
}

String _desktopCount(int count, String one, String many) =>
    '$count ${count == 1 ? one : many}';

void _closeDesktopCart(BuildContext context) {
  final navigator = Navigator.of(context);
  if (navigator.canPop()) {
    navigator.pop();
    return;
  }
  MainShellTabController.navigateToAliadoCatalog();
}

void _exploreFromEmptyCart(BuildContext context) {
  MainShellTabController.navigateToAliadoCatalog();
  final navigator = Navigator.of(context);
  if (navigator.canPop()) navigator.pop();
}

class _DesktopCartHeader extends StatelessWidget {
  const _DesktopCartHeader({required this.state, required this.groups});

  final _CartScreenState state;
  final int groups;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final cart = state._cart;
    final stats =
        '${_desktopCount(cart.lines.length, 'repuesto', 'repuestos')} · ${_desktopCount(cart.itemCount, 'unidad', 'unidades')} · ${_desktopCount(groups, 'proveedor', 'proveedores')}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton.icon(
          onPressed: state._submitting ? null : () => _closeDesktopCart(context),
          style: TextButton.styleFrom(
            foregroundColor: theme.textSecondary,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            minimumSize: const Size(0, 36),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          icon: const LucideIcon(LucideGlyph.arrowLeft, size: 16),
          label: const Text('Seguir comprando'),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tu bolsa',
                    style: TextStyle(
                      fontSize: 28,
                      height: 1.1,
                      fontWeight: FontWeight.w700,
                      color: theme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    stats,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: theme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            const _DesktopCartSteps(),
          ],
        ),
      ],
    );
  }
}

class _DesktopCartSteps extends StatelessWidget {
  const _DesktopCartSteps();

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _DesktopStep(index: '1', label: 'Bolsa', active: true),
        Container(
          width: 28,
          height: 1,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          color: theme.borderSubtle,
        ),
        const _DesktopStep(index: '2', label: 'Entrega y pago', active: false),
      ],
    );
  }
}

class _DesktopStep extends StatelessWidget {
  const _DesktopStep({
    required this.index,
    required this.label,
    required this.active,
  });

  final String index;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final color = active ? B2BBrandHero.start : theme.textMuted;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? B2BBrandHero.start : theme.surfaceCard,
            shape: BoxShape.circle,
            border: Border.all(color: active ? B2BBrandHero.start : theme.border),
          ),
          child: Text(
            index,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: active ? B2BBrandHero.foreground : theme.textMuted,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }
}

double _cartGroupUsd(List<CartLine> lines) {
  var sum = 0.0;
  for (final line in lines) {
    sum += ProductCatalogPricing.aliadoUnitUsdPaymentLine(
          refUnitUsd: line.precioUnitarioAliadoRef,
          salePriceUsd: line.part.salePriceUsd,
          discountRules: line.part.discountRules,
          ownerPagoSoloDivisas: line.part.ownerPagoSoloDivisas,
        ) *
        line.quantity;
  }
  return sum;
}

class _CartShippingCoverage extends StatelessWidget {
  const _CartShippingCoverage({
    required this.part,
    required this.estado,
    required this.subtotalUsd,
  });

  final PartModel part;
  final String? estado;
  final double subtotalUsd;

  @override
  Widget build(BuildContext context) {
    final ficha = EnvioPolitica.evaluarCobertura(
      tipo: part.ownerEnvioTipo,
      minimoGratis: part.ownerEnvioGratisMinimo,
      gratisTodos: part.ownerEnvioGratisTodos,
      gratisEstados: part.ownerEnvioGratisEstados,
      estadoComprador: estado,
      subtotalUsd: subtotalUsd,
    );
    switch (ficha.vista) {
      case EnvioCoberturaVista.gratisAqui:
      case EnvioCoberturaVista.costoAdicional:
      case EnvioCoberturaVista.sinUbicacion:
        break;
      case EnvioCoberturaVista.sinPolitica:
      case EnvioCoberturaVista.politica:
        return const SizedBox.shrink();
    }
    final theme = B2BThemeExtension.of(context);
    final extra = ficha.vista == EnvioCoberturaVista.costoAdicional;
    final ok = ficha.vista == EnvioCoberturaVista.gratisAqui;
    final bg = extra
        ? theme.warningBg
        : ok
            ? theme.successBg
            : theme.surfaceSubtle;
    final fg = extra
        ? theme.warningFg
        : ok
            ? theme.successFg
            : theme.textPrimary;
    final border = extra || ok ? fg.withOpacity(0.35) : theme.borderSubtle;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: theme.surfaceCard,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: fg.withOpacity(0.4)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                child: Text(
                  ficha.etiqueta,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: fg,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                ficha.texto,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DesktopSupplierGroup extends StatelessWidget {
  const _DesktopSupplierGroup({required this.state, required this.entry});

  final _CartScreenState state;
  final MapEntry<String, List<CartLine>> entry;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final cart = state._cart;
    final lines = entry.value;
    final units = SupplierOrderMinUnits.selected(lines);
    final unitsMinimum = SupplierOrderMinUnits.definedMinimum(lines);
    final unitsMet = unitsMinimum == null || units >= unitsMinimum;
    final missing = SupplierOrderMinUnits.missing(lines);
    final amount = SupplierUsdMinOrder.of(lines);
    final ownerId = lines.first.part.ownerId?.trim() ?? '';
    final tasa = state._tasa;
    final mode = state._modeFor(lines);
    final quote = MobileSupplierTotals(
      lines: lines,
      payUsd: mode == _PagoMoneda.usd,
      availableCredit: state._creditFor(lines),
    );
    return Material(
      color: theme.surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.borderSubtle),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(children: [
              LucideIcon(LucideGlyph.store, size: 18, color: B2BBrandHero.start),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cart.importadorDisplayName(entry.key),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: theme.textPrimary,
                      ),
                    ),
                    if (unitsMinimum != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        unitsMet
                            ? '$units / $unitsMinimum unidades mínimas'
                            : 'Faltan $missing · $units / $unitsMinimum unidades',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: unitsMet ? theme.successFg : theme.textPrimary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (lines.any((line) => line.part.ownerPagoSoloDivisas)) ...[
                const SizedBox(width: 8),
                _CartOfferChip(
                  label: 'Solo divisas',
                  bg: theme.brandContainer,
                  fg: B2BBrandHero.start,
                  border: theme.borderSubtle,
                ),
              ],
              if (state._importerGroupHasPromo(lines)) ...[
                const SizedBox(width: 8),
                _CartOfferChip(
                  label: 'Promoción',
                  bg: theme.brandContainer,
                  fg: B2BBrandHero.start,
                  border: theme.borderSubtle,
                ),
              ],
            ]),
          ),
          Divider(height: 1, color: theme.borderSubtle),
          RetailerTourTarget(
            topic: RetailerCartTopic.minimums,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (unitsMinimum != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: unitsMet ? theme.successBg : theme.surfaceSubtle,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: unitsMet
                              ? theme.successFg.withOpacity(0.35)
                              : theme.borderSubtle,
                        ),
                      ),
                      child: Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Text(
                          unitsMet
                              ? 'Este proveedor ya cumple su mínimo de $unitsMinimum unidades.'
                              : 'A este proveedor le faltan $missing unidades para llegar a $unitsMinimum.',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                            color: unitsMet ? theme.successFg : theme.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (amount.hasMinimum)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: amount.meets ? theme.successBg : theme.surfaceSubtle,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: amount.meets
                              ? theme.successFg.withOpacity(0.35)
                              : theme.borderSubtle,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              amount.meets
                                  ? 'Monto mínimo ${formatMinOrderAmount(amount.minimum, amount.currency)} cubierto'
                                  : 'Llevas ${formatMinOrderAmount(amount.current, amount.currency)} de ${formatMinOrderAmount(amount.minimum, amount.currency)}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color:
                                    amount.meets ? theme.successFg : theme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: amount.fraction,
                                minHeight: 4,
                                backgroundColor: theme.borderSubtle,
                                color: amount.meets
                                    ? theme.successFg
                                    : B2BBrandHero.start,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          RetailerTourTarget(
            topic: RetailerCartTopic.shipping,
            child: _CartShippingCoverage(
              part: lines.first.part,
              estado: state.widget.profile.estado,
              subtotalUsd: _cartGroupUsd(lines),
            ),
          ),
          if ((state._credits[ownerId]?.remaining ?? 0) > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: _CreditToggle(
                lines: lines,
                balance: state._credits[ownerId],
                availableLabel: _cartMoney(
                  state._credits[ownerId]?.remaining ?? 0,
                  mode,
                  tasa,
                ),
                appliedLabel: _cartMoney(
                  state._creditFor(lines),
                  mode,
                  tasa,
                ),
                optedOut: state._creditOptOut.contains(ownerId),
                onChanged: (useCredit) =>
                    state._setDesktopCredit(ownerId, useCredit),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            key: ValueKey('supplier-currency-$ownerId'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Moneda de pago',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                _CartCurrencySelector(
                  labels: const ['Bolívares', 'USD'],
                  selected: mode.index,
                  canPayBolivares: (tasa ?? 0) > 0 &&
                      !lines.any((line) => line.part.ownerPagoSoloDivisas),
                  onSelected: state._submitting ||
                          state._choosingDelivery ||
                          !cart.canEdit
                      ? null
                      : (index) => cart.setSupplierCurrencies(
                          {ownerId: index == _PagoMoneda.usd.index}),
                ),
                if ((tasa ?? 0) <= 0 &&
                    !lines.any((line) => line.part.ownerPagoSoloDivisas))
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('No hay tasa BCV vigente para cobrar en bolívares.',
                        style: TextStyle(color: theme.textSecondary)),
                  ),
                if (quote.usdSavings > 0.009)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(quote.payUsd
                        ? 'Ahorro aplicado: ${formatRefAmount(quote.usdSavings)} USD'
                        : 'Ahorra ${formatRefAmount(quote.usdSavings)} USD si pagas en divisas'),
                  ),
              ],
            ),
          ),
          RetailerTourTarget(
            topic: RetailerCartTopic.minimums,
            child: state._combinedMinimumProgress(lines),
          ),
          for (var i = 0; i < lines.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Divider(height: 1, color: theme.borderSubtle),
              ),
            _DesktopCartLine(
              line: lines[i],
              modo: mode,
              tasa: tasa,
              onRemove: state._submitting || !cart.canEdit
                  ? null
                  : () => state._removeLine(lines[i]),
              onQuantityChanged: state._submitting || !cart.canEdit
                  ? null
                  : (qty) => cart.setQuantity(lines[i].part.id, qty),
            ),
          ],
        ],
      ),
    );
  }
}

class _DesktopCartLine extends StatelessWidget {
  const _DesktopCartLine({
    required this.line,
    required this.modo,
    required this.tasa,
    required this.onRemove,
    required this.onQuantityChanged,
  });

  final CartLine line;
  final _PagoMoneda modo;
  final double? tasa;
  final VoidCallback? onRemove;
  final ValueChanged<int>? onQuantityChanged;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final part = line.part;
    final cover = part.coverImageUrl?.trim();
    final sku = (part.sku ?? '').trim();
    final displayModo = part.ownerPagoSoloDivisas ? _PagoMoneda.usd : modo;
    final unit = _cartUnitDollars(line, displayModo);
    final showUsd = displayModo == _PagoMoneda.usd;
    final currency = showUsd ? 'USD' : 'REF';
    final unitLabel = '${formatRefAmount(unit)} $currency';
    final totalLabel = '${formatRefAmount(unit * line.quantity)} $currency';
    final showBs = !showUsd && tasa != null && tasa! > 0;
    final unitBs = showBs ? formatBsLabel(unit * tasa!) : null;
    final totalBs = showBs ? formatBsLabel(unit * line.quantity * tasa!) : null;
    final usdDiscount = showUsd
        ? ProductCatalogPricing.directSaleDiscountChipEs(
            listPriceUsd: line.precioUnitarioAliadoRef,
            salePriceUsd: unit,
          )
        : null;
    final campaignChip = ProductCatalogPricing.campaignDiscountChipEs(
      part.activeCampaignDiscountPercent,
      discountRules: part.discountRules,
      quantity: line.quantity,
    );
    final stockHint = part.hasSupplierMinOrderQty
        ? '${part.minOrderQtyLabelEs} • Disp. ${part.stockForSale}'
        : 'Disp. ${part.stockForSale}';
    final priceColor =
        usdDiscount != null ? theme.successFg : theme.textPrimary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: ColoredBox(
              color: theme.inputFill,
              child: SizedBox(
                width: 72,
                height: 72,
                child: cover != null && cover.isNotEmpty
                    ? Image.network(
                        cover,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => LucideIcon(
                          LucideGlyph.image,
                          color: theme.textMuted,
                          size: 22,
                        ),
                      )
                    : LucideIcon(LucideGlyph.image, color: theme.textMuted, size: 22),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  part.nombre,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    height: 1.25,
                    color: theme.textPrimary,
                  ),
                ),
                if (sku.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    sku,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: theme.textSecondary),
                  ),
                ],
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      unitLabel,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: priceColor,
                      ),
                    ),
                    if (unitBs != null)
                      Text(
                        unitBs,
                        style: TextStyle(fontSize: 12, color: theme.textSecondary),
                      ),
                    if (usdDiscount != null)
                      _CartOfferChip(
                        label: usdDiscount,
                        bg: theme.successBg,
                        fg: theme.successFg,
                        border: theme.successBg,
                      ),
                    if (campaignChip != null)
                      _CartOfferChip(
                        label: campaignChip,
                        bg: theme.brandContainer,
                        fg: B2BBrandHero.start,
                        border: theme.borderSubtle,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 148,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _DesktopQuantity(
                  line: line,
                  onChanged: onQuantityChanged,
                ),
                const SizedBox(height: 6),
                Text(
                  stockHint,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: theme.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 108,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _CartMoneyText(
                  value: totalLabel,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: theme.textPrimary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                if (totalBs != null) ...[
                  const SizedBox(height: 2),
                  _CartMoneyText(
                    value: totalBs,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: theme.textSecondary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ],
            ),
          ),
          _DesktopRemoveButton(onPressed: onRemove),
        ],
      ),
    );
  }
}

class _DesktopQuantity extends StatelessWidget {
  const _DesktopQuantity({required this.line, required this.onChanged});

  final CartLine line;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final canDec =
        onChanged != null && line.quantity > line.part.minOrderQtyEffective;
    final canInc = onChanged != null && line.quantity < line.part.stockForSale;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.inputFill,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.borderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _DesktopQtyButton(
            glyph: LucideGlyph.minus,
            label: 'Reducir cantidad',
            enabled: canDec,
            onTap: canDec ? () => onChanged!(line.quantity - 1) : null,
          ),
          CartQuantityField(
            quantity: line.quantity,
            minimum: line.part.minOrderQtyEffective,
            maximum: line.part.stockForSale,
            onChanged: onChanged,
            embedded: true,
          ),
          _DesktopQtyButton(
            glyph: LucideGlyph.plus,
            label: 'Aumentar cantidad',
            enabled: canInc,
            onTap: canInc ? () => onChanged!(line.quantity + 1) : null,
          ),
        ],
      ),
    );
  }
}

class _DesktopQtyButton extends StatelessWidget {
  const _DesktopQtyButton({
    required this.glyph,
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final LucideGlyph glyph;
  final String label;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 32,
          height: 44,
          child: LucideIcon(
            glyph,
            size: 14,
            color: enabled ? B2BBrandHero.start : theme.textMuted,
          ),
        ),
      ),
    );
  }
}

class _DesktopRemoveButton extends StatefulWidget {
  const _DesktopRemoveButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  State<_DesktopRemoveButton> createState() => _DesktopRemoveButtonState();
}

class _DesktopRemoveButtonState extends State<_DesktopRemoveButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final enabled = widget.onPressed != null;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: IconButton(
        onPressed: widget.onPressed,
        tooltip: 'Eliminar',
        style: IconButton.styleFrom(
          minimumSize: const Size(36, 36),
          backgroundColor: _hover && enabled
              ? theme.textPrimary.withOpacity(0.06)
              : Colors.transparent,
          foregroundColor: _hover && enabled ? theme.textPrimary : theme.textMuted,
        ),
        icon: const LucideIcon(LucideGlyph.trash2, size: 16),
      ),
    );
  }
}

class _DesktopCartSummary extends StatelessWidget {
  const _DesktopCartSummary(
      {required this.state,
      required this.totals,
      required this.canConfirm,
      required this.unitsReady,
      required this.amountReady});

  final _CartScreenState state;
  final MobileCheckoutTotals totals;
  final bool canConfirm, unitsReady, amountReady;
  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final cart = state._cart;
    final tasa = state._tasa;
    final rate = tasa ?? 0;
    return Material(
      color: theme.surfaceCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Resumen de tu compra',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: theme.textPrimary,
              ),
            ),
            const SizedBox(height: 14),
            for (final entry in totals.suppliers.entries) ...[
              _summaryLine(theme, cart.importadorDisplayName(entry.key),
                  '${formatRefAmount(entry.value.net)} ${entry.value.payUsd ? 'USD' : 'REF'}'),
              const SizedBox(height: 10),
            ],
            Divider(color: theme.borderSubtle),
            if (totals.suppliers.values.any((quote) => quote.payUsd))
              _summaryLine(theme, 'Subtotal USD',
                  '${formatRefAmount(totals.netUsd)} USD',
                  prominent: true),
            if (totals.suppliers.values.any((quote) => !quote.payUsd)) ...[
              _summaryLine(theme, 'Subtotal REF',
                  '${formatRefAmount(totals.netRef)} REF'),
              if (rate > 0) ...[
                _summaryLine(theme, 'Equivalente en Bs',
                    formatBsLabel(totals.netRef * rate),
                    prominent: true),
                _CartBcvRate(
                    tasa: rate, effectiveDate: state._tasaEffectiveDate),
              ],
            ],
            if (!amountReady)
              const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text('Completa el monto mínimo de cada proveedor.')),
            if (!state._meetsCombinedMinimums)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Completa los mínimos combinables para continuar.'),
              ),
            if (!unitsReady) ...[
              const SizedBox(height: 12),
              Text(
                'Completa las unidades mínimas que definió cada proveedor.',
                style: TextStyle(
                    fontSize: 12, height: 1.4, color: theme.textPrimary),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LucideIcon(LucideGlyph.truck, size: 16, color: B2BBrandHero.start),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'El envío se revisa en el siguiente paso.',
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.35,
                      color: theme.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            RetailerTourTarget(
              topic: RetailerCartTopic.delivery,
              child: FilledButton(
                onPressed: state._cart.pendingCheckoutAttempt != null &&
                        !state._submitting
                    ? state._recoverPendingCheckout
                    : canConfirm
                        ? state._checkout
                        : null,
                style: FilledButton.styleFrom(
                  backgroundColor: B2BBrandHero.start,
                  foregroundColor: B2BBrandHero.foreground,
                  disabledBackgroundColor: B2BBrandHero.start.withOpacity(0.35),
                  disabledForegroundColor: B2BBrandHero.foreground,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                child: state._submitting
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: B2BBrandHero.foreground,
                        ),
                      )
                    : Text(state._cart.pendingCheckoutAttempt != null
                        ? 'Recuperar pedido'
                        : 'Continuar con la entrega →'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryLine(
    B2BThemeExtension theme,
    String label,
    String value, {
    bool prominent = false,
    Color? valueColor,
  }) {
    final valueStyle = TextStyle(
      fontSize: prominent ? 22 : 14,
      height: prominent ? 1.15 : null,
      fontWeight: prominent ? FontWeight.w800 : FontWeight.w600,
      letterSpacing: prominent ? -0.4 : null,
      fontFeatures: const [FontFeature.tabularFigures()],
      color: valueColor ?? theme.textPrimary,
    );
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: prominent ? 14 : 13,
              fontWeight: prominent ? FontWeight.w600 : FontWeight.w500,
              color: theme.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: _CartMoneyText(value: value, style: valueStyle)),
      ],
    );
  }
}

class _DesktopCartSuggestions extends StatefulWidget {
  const _DesktopCartSuggestions({
    required this.suggestions,
    required this.loading,
    required this.onAdd,
    required this.autoPlay,
    this.bcvRate,
  });

  final List<CartSuggestion> suggestions;
  final bool loading;
  final ValueChanged<CartSuggestion>? onAdd;
  final bool autoPlay;
  final double? bcvRate;

  @override
  State<_DesktopCartSuggestions> createState() => _DesktopCartSuggestionsState();
}

class _DesktopCartSuggestionsState extends State<_DesktopCartSuggestions> {
  static const _cardWidth = 220.0;
  static const _gap = 12.0;
  static const _cardHeight = 392.0;

  final _scroll = ScrollController();
  Timer? _timer;
  bool _hovering = false;
  bool _interacting = false;

  bool get _sameSupplier =>
      widget.suggestions.isNotEmpty &&
      widget.suggestions.every((item) => !item.differentSupplier);

  @override
  void initState() {
    super.initState();
    _arm();
  }

  @override
  void didUpdateWidget(covariant _DesktopCartSuggestions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.autoPlay != widget.autoPlay ||
        oldWidget.suggestions.length != widget.suggestions.length) {
      _arm();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  void _arm() {
    _timer?.cancel();
    if (!widget.autoPlay || _hovering || _interacting) return;
    if (widget.suggestions.length < 2) return;
    _timer = Timer(const Duration(milliseconds: 3800), _advance);
  }

  Future<void> _advance() async {
    if (!mounted || !_scroll.hasClients || _hovering || _interacting) return;
    final max = _scroll.position.maxScrollExtent;
    if (max < 8) return;
    final step = _cardWidth + _gap;
    final next = _scroll.offset + step;
    final target = next >= max - 1 ? 0.0 : next;
    await _scroll.animateTo(
      target,
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeInOut,
    );
    _arm();
  }

  void _nudge(int direction) {
    if (!_scroll.hasClients) return;
    _timer?.cancel();
    final step = _cardWidth + _gap;
    final max = _scroll.position.maxScrollExtent;
    _scroll.animateTo(
      (_scroll.offset + direction * step).clamp(0.0, max),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
    _arm();
  }

  void _setHover(bool value) {
    _hovering = value;
    if (value) {
      _timer?.cancel();
    } else if (!_interacting) {
      _arm();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final subtitle = _sameSupplier
        ? 'Del mismo proveedor de tu compra.'
        : 'También te puede interesar.';
    return MouseRegion(
      onEnter: (_) => _setHover(true),
      onExit: (_) => _setHover(false),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Completa tu compra',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: theme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 13, color: theme.textSecondary),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Productos anteriores',
              onPressed: widget.suggestions.length < 2 ? null : () => _nudge(-1),
              icon: const LucideIcon(LucideGlyph.chevronLeft, size: 18),
            ),
            IconButton(
              tooltip: 'Más productos',
              onPressed: widget.suggestions.length < 2 ? null : () => _nudge(1),
              icon: const LucideIcon(LucideGlyph.chevronRight, size: 18),
            ),
          ]),
          const SizedBox(height: 12),
          if (widget.loading && widget.suggestions.isEmpty)
            const SizedBox(
              height: 120,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            SizedBox(
              height: _cardHeight,
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(
                  dragDevices: const {
                    PointerDeviceKind.touch,
                    PointerDeviceKind.mouse,
                    PointerDeviceKind.trackpad,
                    PointerDeviceKind.stylus,
                  },
                ),
                child: NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (notification is ScrollStartNotification &&
                        notification.dragDetails != null) {
                      _interacting = true;
                      _timer?.cancel();
                    } else if (notification is ScrollEndNotification) {
                      _interacting = false;
                      if (!_hovering) _arm();
                    }
                    return false;
                  },
                  child: Listener(
                    onPointerSignal: (event) {
                      if (event is! PointerScrollEvent || !_scroll.hasClients) {
                        return;
                      }
                      final delta = event.scrollDelta.dx != 0
                          ? event.scrollDelta.dx
                          : event.scrollDelta.dy;
                      if (delta == 0) return;
                      _timer?.cancel();
                      final max = _scroll.position.maxScrollExtent;
                      _scroll.jumpTo((_scroll.offset + delta).clamp(0.0, max));
                      if (!_hovering && !_interacting) _arm();
                    },
                    child: ListView.separated(
                      controller: _scroll,
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 8),
                      itemCount: widget.suggestions.length,
                      separatorBuilder: (_, __) => const SizedBox(width: _gap),
                      itemBuilder: (context, index) {
                        final suggestion = widget.suggestions[index];
                        return SizedBox(
                          width: _cardWidth,
                          child: _DesktopSuggestionCard(
                            suggestion: suggestion,
                            bcvRate: widget.bcvRate,
                            onAdd: widget.onAdd == null
                                ? null
                                : () => widget.onAdd!(suggestion),
                          ),
                        );
                      },
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

class _DesktopSuggestionCard extends StatelessWidget {
  const _DesktopSuggestionCard({
    required this.suggestion,
    required this.bcvRate,
    required this.onAdd,
  });

  final CartSuggestion suggestion;
  final double? bcvRate;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final part = suggestion.part;
    final supplier = (part.ownerBusinessName ?? '').trim();
    final cover = part.coverImageUrl?.trim();
    return Material(
      color: theme.surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: theme.borderSubtle),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
              child: ColoredBox(
                color: theme.inputFill,
                child: SizedBox(
                  height: 132,
                  child: cover != null && cover.isNotEmpty
                      ? Image.network(
                          cover,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => LucideIcon(
                            LucideGlyph.image,
                            color: theme.textMuted,
                          ),
                        )
                      : LucideIcon(LucideGlyph.image, color: theme.textMuted),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              part.nombre,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                height: 1.25,
                fontWeight: FontWeight.w700,
                color: theme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Row(children: [
              ImporterCatalogLogo(
                storagePath: part.ownerLogoStoragePath,
                size: 14,
                fallback: LucideIcon(
                  LucideGlyph.store,
                  size: 12,
                  color: theme.textSecondary,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  supplier.isEmpty ? 'Proveedor' : supplier,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: theme.textSecondary),
                ),
              ),
            ]),
            const SizedBox(height: 6),
            Expanded(
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: CatalogCartPrice(
                  part: part,
                  compact: true,
                  prominent: false,
                  catalogGrid: true,
                  bcvRate: bcvRate,
                ),
              ),
            ),
            Text(
              part.minOrderQtyLabelEs,
              style: TextStyle(fontSize: 11, color: theme.textMuted),
            ),
            const SizedBox(height: 8),
            _DesktopSuggestButton(
              enabled: onAdd != null,
              onPressed: onAdd,
              productName: part.nombre,
            ),
          ],
        ),
      ),
    );
  }
}

class _DesktopSuggestButton extends StatelessWidget {
  const _DesktopSuggestButton({
    required this.enabled,
    required this.onPressed,
    required this.productName,
  });

  final bool enabled;
  final VoidCallback? onPressed;
  final String productName;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Añadir al pedido $productName',
      child: FilledButton.icon(
        onPressed: enabled ? onPressed : null,
        style: FilledButton.styleFrom(
          backgroundColor: B2BBrandHero.start,
          foregroundColor: B2BBrandHero.foreground,
          disabledBackgroundColor: B2BBrandHero.start.withOpacity(0.35),
          disabledForegroundColor: B2BBrandHero.foreground,
          minimumSize: const Size(double.infinity, 36),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
        icon: const LucideIcon(
          LucideGlyph.plus,
          size: 16,
          color: B2BBrandHero.foreground,
        ),
        label: const Text('Agregar'),
      ),
    );
  }
}

class _DesktopCartEmpty extends StatelessWidget {
  const _DesktopCartEmpty();

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _DesktopCartBack(),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LucideIcon(LucideGlyph.handbag, size: 48, color: theme.textMuted),
                  const SizedBox(height: 12),
                  Text(
                    'Tu bolsa está vacía',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: theme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Encuentra los repuestos que necesitas y agrégalos aquí.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.35,
                      color: theme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => _exploreFromEmptyCart(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: B2BBrandHero.start,
                      foregroundColor: B2BBrandHero.foreground,
                    ),
                    icon: const LucideIcon(
                      LucideGlyph.search,
                      size: 16,
                      color: B2BBrandHero.foreground,
                    ),
                    label: const Text('Explorar catálogo'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DesktopCartBack extends StatelessWidget {
  const _DesktopCartBack();

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: TextButton.icon(
          onPressed: () => _closeDesktopCart(context),
          style: TextButton.styleFrom(
            foregroundColor: theme.textSecondary,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            minimumSize: const Size(0, 36),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          icon: const LucideIcon(LucideGlyph.arrowLeft, size: 16),
          label: const Text('Seguir comprando'),
        ),
      ),
    );
  }
}

class _DesktopCartMessage extends StatelessWidget {
  const _DesktopCartMessage({
    required this.loading,
    required this.message,
    required this.action,
  });

  final bool loading;
  final String message;
  final (String, VoidCallback)? action;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _DesktopCartBack(),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (loading) const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: theme.textPrimary),
                  ),
                  if (action != null)
                    TextButton(onPressed: action!.$2, child: Text(action!.$1)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
