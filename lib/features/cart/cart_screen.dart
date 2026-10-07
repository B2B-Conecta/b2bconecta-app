import 'package:flutter/material.dart';

import 'package:motolink_pro_app/features/profile/profile_location_exception.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';
import 'cart_service.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'package:motolink_pro_app/app/main_shell_tab.dart';
import 'package:motolink_pro_app/features/ads/meta_pixel.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/utils/ves_amount_format.dart';
import 'package:motolink_pro_app/features/catalog/product_catalog_pricing.dart';
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

class _CartScreenState extends State<CartScreen> {
  final _cart = CartService.instance;
  bool _submitting = false;
  double? _tasa;

  @override
  void initState() {
    super.initState();
    _tasa = widget.liveTasaBcv;
    _cart.addListener(_onCart);
    if (_tasa == null) {
      SupabaseService.fetchGlobalTasaBcv().then((v) {
        if (mounted) setState(() => _tasa = v);
      }).catchError((_) {});
    }
  }

  void _onCart() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _cart.removeListener(_onCart);
    super.dispose();
  }

  Future<void> _checkout() async {
    if (_cart.isEmpty || _submitting || !_cart.meetsAllImporterMinOrders) {
      return;
    }

    final result = await showDialog<_DestinoEntregaResult?>(
      context: context,
      builder: (ctx) => _DestinoEntregaDialog(profile: widget.profile),
    );

    if (result == null || !mounted) return;

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

      final orderId = await SupabaseService.checkoutMultiImportadorCart(
        lines: lines,
        destinoEntregaUsaPerfil: result.useProfile,
        destinoEntregaTexto: result.texto,
        destinoEntregaMapsUrl: result.mapsUrl,
        promoByImportador: _cart.promoAttributionPayloadForCheckout(),
      );
      final purchaseValue = _cart.totalRef();
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
        const SnackBar(
          content: Text(
            'Pedido registrado. Los importadores recibirán un aviso para confirmar stock.',
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

  bool _importerGroupHasPromo(List<CartLine> lines) {
    for (final line in lines) {
      if (_cart.importadorHasPromoAttribution(line.part.ownerId)) {
        return true;
      }
    }
    return false;
  }

  ImporterMinOrderProgress? _progressFor(List<CartLine> lines) {
    final name = lines.isEmpty
        ? ''
        : (lines.first.part.ownerBusinessName?.trim().isNotEmpty == true
            ? lines.first.part.ownerBusinessName!.trim()
            : 'Importador');
    final matches = _cart
        .importerMinOrderProgress()
        .where((e) => e.importerName == name);
    return matches.isEmpty ? null : matches.first;
  }

  @override
  Widget build(BuildContext context) {
    final tasa = _tasa;
    final totalRef = _cart.totalRef();
    final totalBs = tasa != null ? totalRef * tasa : null;
    final canConfirm = !_submitting && _cart.meetsAllImporterMinOrders;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Carrito',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: _cart.isEmpty
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
                    Text(
                      'Agregue repuestos desde el catálogo para armar el pedido.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.35,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    children: [
                      for (final entry
                          in _cart.linesGroupedByImporterName.entries) ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6, top: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  entry.key,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                    color: AppColors.brandBlue,
                                  ),
                                ),
                              ),
                              if (_importerGroupHasPromo(entry.value))
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.brand
                                        .withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'Bajo promoción',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.brand,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Builder(
                          builder: (context) {
                            final progress = _progressFor(entry.value);
                            if (progress == null || !progress.hasMinimum) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    progress.meets
                                        ? 'Pedido mínimo ${formatMinOrderAmount(progress.minRef, progress.currency)} cubierto'
                                        : 'Llevas ${formatMinOrderAmount(progress.currentRef, progress.currency)} de ${formatMinOrderAmount(progress.minRef, progress.currency)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: progress.meets
                                          ? Colors.green.shade800
                                          : AppColors.brandBlue,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: progress.fraction,
                                      minHeight: 6,
                                      backgroundColor: AppColors.borderSubtle,
                                      color: progress.meets
                                          ? Colors.green.shade600
                                          : AppColors.brandAccent,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        ...entry.value.map(
                          (line) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _CartLineCard(
                              line: line,
                              onRemove: () =>
                                  _cart.removeProduct(line.part.id),
                              onQuantityChanged: (q) =>
                                  _cart.setQuantity(line.part.id, q),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Material(
                  elevation: 8,
                  color: Colors.white,
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Total REF: ${formatRefAmount(totalRef)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          if (totalBs != null && tasa != null)
                            Text(
                              'Referencia en Bs (tasa ${formatTasaBcvDisplay(tasa, fractionDigits: 4)}): '
                              '${formatVesAmount(totalBs)}',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          if (!_cart.meetsAllImporterMinOrders) ...[
                            const SizedBox(height: 6),
                            Text(
                              'Complete el pedido mínimo de cada importador para confirmar.',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.brandBlue,
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          FilledButton(
                            onPressed: canConfirm ? _checkout : null,
                            child: _submitting
                                ? const SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Confirmar pedido'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

/// Fila de carrito: imagen, detalle, precios y cantidad.
class _CartLineCard extends StatelessWidget {
  const _CartLineCard({
    required this.line,
    required this.onRemove,
    required this.onQuantityChanged,
  });

  final CartLine line;
  final VoidCallback onRemove;
  final ValueChanged<int> onQuantityChanged;

  @override
  Widget build(BuildContext context) {
    final part = line.part;
    final cover = part.coverImageUrl?.trim();
    final sku = (part.sku ?? '').trim();
    final unit = line.precioUnitarioAliadoRef;
    final lineTotal = unit * line.quantity;
    final list = part.precio;
    final showStrike = unit < list - 0.0001;
    final minQty = part.minOrderQtyEffective;
    final maxQty = part.stock;
    final canDec = line.quantity > minQty;
    final canInc = line.quantity < maxQty;

    final promoChip = ProductCatalogPricing.campaignDiscountChipEs(
      part.activeCampaignDiscountPercent,
      discountRules: part.discountRules,
      quantity: line.quantity,
    );
    final volumeActive = ProductCatalogPricing.volumePathActive(
      part.discountRules,
      line.quantity,
    );
    final volumePct = volumeActive
        ? ProductCatalogPricing.volumeDiscountPercent(
            part.discountRules,
            line.quantity,
          )
        : 0.0;

    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 80,
                height: 80,
                child: cover != null && cover.isNotEmpty
                    ? Image.network(
                        cover,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _thumbPlaceholder(),
                      )
                    : _thumbPlaceholder(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          part.nombre,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14.5,
                            height: 1.25,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: onRemove,
                        tooltip: 'Quitar del carrito',
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                        icon: Icon(
                          Icons.delete_outline_rounded,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  if (sku.isNotEmpty)
                    Text(
                      'SKU $sku',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '${formatRefAmount(unit)} REF',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: AppColors.brandBlue,
                        ),
                      ),
                      Text(
                        ' / ud',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (showStrike) ...[
                        const SizedBox(width: 8),
                        Text(
                          formatRefAmount(list),
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Total línea ${formatRefAmount(lineTotal)} REF',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (promoChip != null || volumeActive) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (promoChip != null)
                          _CartOfferChip(
                            label: promoChip,
                            bg: const Color(0xFFFFF6E5),
                            fg: const Color(0xFF8A5A00),
                            border: const Color(0xFFE8A317).withOpacity(0.45),
                          ),
                        if (volumeActive)
                          _CartOfferChip(
                            label: volumePct == volumePct.roundToDouble()
                                ? 'Volumen −${volumePct.toStringAsFixed(0)}%'
                                : 'Volumen −${volumePct.toStringAsFixed(1)}%',
                            bg: AppColors.brandBlueContainer,
                            fg: AppColors.textPrimary,
                            border: AppColors.borderSubtle,
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _QtyButton(
                        icon: Icons.remove_rounded,
                        enabled: canDec,
                        onTap: canDec
                            ? () => onQuantityChanged(line.quantity - 1)
                            : null,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          '${line.quantity}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      _QtyButton(
                        icon: Icons.add_rounded,
                        enabled: canInc,
                        onTap: canInc
                            ? () => onQuantityChanged(line.quantity + 1)
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'uds',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (minQty > 1) ...[
                        const SizedBox(width: 8),
                        Text(
                          'mín. $minQty',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _thumbPlaceholder() {
    return ColoredBox(
      color: AppColors.fieldFill,
      child: Icon(
        Icons.precision_manufacturing_outlined,
        color: AppColors.textSecondary.withOpacity(0.55),
        size: 30,
      ),
    );
  }
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
    return Material(
      color: enabled ? AppColors.brandBlueContainer : AppColors.fieldFill,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 34,
          height: 34,
          child: Icon(
            icon,
            size: 18,
            color: enabled
                ? AppColors.brandBlue
                : AppColors.textMuted,
          ),
        ),
      ),
    );
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
  const _DestinoEntregaDialog({required this.profile});

  final ProfileModel profile;

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
    final maps = _usaPerfil
        ? null
        : _maps.text.trim();
    Navigator.of(context).pop(
      _DestinoEntregaResult(
        useProfile: _usaPerfil,
        texto: text,
        mapsUrl: maps,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Destino de entrega'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Usar dirección fiscal del perfil'),
              subtitle: Text(
                _usaPerfil
                    ? (widget.profile.hasFiscalMapsShareLink
                        ? 'El reparto usará su domicilio y el enlace Maps guardados en Mi perfil.'
                        : 'Debe completar el enlace de Google Maps en Mi perfil para usar esta opción.')
                    : 'Indique otra dirección y enlace Maps a continuación.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              value: _usaPerfil,
              onChanged: (v) => setState(() => _usaPerfil = v),
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
