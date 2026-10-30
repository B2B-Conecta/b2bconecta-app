import 'package:flutter/material.dart';
import 'package:motolink_pro_app/core/utils/ves_amount_format.dart';
import 'package:motolink_pro_app/features/payments/motolink_volume_discount.dart';
import 'package:motolink_pro_app/features/profile/app_home_role.dart';
import 'package:url_launcher/url_launcher.dart';
import '../shared/order_list_colors.dart';
import '../shared/order_list_entry.dart';
import '../shared/order_delivery_stepper.dart';
import '../shared/order_card_direct_summary.dart';
import '../shared/aliado_order_grouping.dart';
import '../shared/courier_timeline_widget.dart';
import '../shared/moroso_order_visual.dart';
import '../shared/transaction_request_model.dart';
import 'aliado_transit_eta_banner.dart';

/// Operational widgets stay owned by the panel; the detail only arranges them.
class AliadoOrderDetailSections {
  const AliadoOrderDetailSections({
    required this.payment,
    required this.paymentStatus,
    this.paymentOpen = false,
    this.attention,
    this.receipt,
    this.deliveryActions,
    this.afterSales,
  });
  final Widget payment;
  final String paymentStatus;
  final bool paymentOpen;
  final Widget? attention;
  final Widget? receipt;
  final Widget? deliveryActions;
  final Widget? afterSales;
}

typedef AliadoDetailSectionsBuilder = AliadoOrderDetailSections Function(
    BuildContext context,
    List<TransactionRequestModel> lines,
    int index,
    int total);

/// A complete order page: one summary, then fulfilment, products and operations.
class AliadoOrderDetailView extends StatefulWidget {
  const AliadoOrderDetailView({
    super.key,
    required this.lines,
    required this.summary,
    required this.sectionsBuilder,
  });
  final List<TransactionRequestModel> lines;
  final Widget summary;
  final AliadoDetailSectionsBuilder sectionsBuilder;

  @override
  State<AliadoOrderDetailView> createState() => _AliadoOrderDetailViewState();
}

class _AliadoOrderDetailViewState extends State<AliadoOrderDetailView> {
  String? _owner;

  @override
  Widget build(BuildContext context) {
    final providers = groupCheckoutLinesByImportador(widget.lines);
    final selected = providers.indexWhere((g) => g.first.ownerId == _owner);
    final index = selected < 0 ? 0 : selected;
    final chunk = providers[index];
    final request = chunk.first;
    final sections =
        widget.sectionsBuilder(context, chunk, index + 1, providers.length);
    final sameShipping = checkoutGroupMismoEstadoEnvio(chunk);
    final colors = OrderListColors.of(context);

    final tracking = OrderDetailSection(
      title: 'Seguimiento',
      icon: Icons.local_shipping_outlined,
      tonal: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        OrderDeliveryStepper(lines: chunk),
        const SizedBox(height: 8),
        if (sameShipping && AliadoTransitEtaBanner.shouldShow(request))
          AliadoTransitEtaBanner(request: request),
        if (sections.receipt != null) sections.receipt!,
        if (chunk.any((l) => l.esPedidoMoroso))
          MorosoOrderCardNotice(
            request: chunk.firstWhere((l) => l.esPedidoMoroso),
            expanded: true,
            aliadoViewer: true,
          ),
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            key: PageStorageKey('history-${request.id}'),
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(top: 8),
            title: const Text('Historial del envío',
                style: TextStyle(fontSize: 13)),
            children: [
              for (final line in sameShipping ? [request] : chunk)
                Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!sameShipping) ...[
                        Text(line.etiquetaProductoAliado,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        AliadoTransitEtaBanner(request: line),
                      ],
                      CourierTimelineWidget(
                        request: line,
                        compact: true,
                        viewerRole: AppHomeRole.aliado,
                        showHeading: false,
                        embedded: true,
                      ),
                    ]),
            ],
          ),
        ),
      ]),
    );
    final products = OrderDetailSection(
      title: 'Productos',
      icon: Icons.shopping_bag_outlined,
      child: _OrderProducts(lines: chunk),
    );
    final delivery = OrderDetailSection(
      title: 'Entrega',
      icon: Icons.location_on_outlined,
      flat: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(
            request.destinoEntregaUsaPerfil
                ? 'Dirección de tu tienda'
                : 'Dirección alterna',
            style: TextStyle(fontSize: 12, color: colors.secondary)),
        const SizedBox(height: 6),
        Text(
            request.destinoEntregaUsaPerfil
                ? request.aliadoDireccionFiscalMultilineaEs ??
                    'Dirección de la tienda aún no disponible.'
                : request.destinoEntregaTexto?.trim().isNotEmpty == true
                    ? request.destinoEntregaTexto!.trim()
                    : 'Otro destino (sin texto guardado)',
            style: TextStyle(fontSize: 13, height: 1.5, color: colors.ink)),
        if (sections.deliveryActions != null) ...[
          const SizedBox(height: 12),
          sections.deliveryActions!,
        ],
      ]),
    );
    final payment = OrderDetailSection(
      title: 'Pago y factura',
      icon: Icons.account_balance_wallet_outlined,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(sections.paymentStatus,
            style:
                TextStyle(fontSize: 13, height: 1.4, color: colors.secondary)),
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            key: PageStorageKey('payment-${request.id}'),
            initiallyExpanded: sections.paymentOpen,
            maintainState: true,
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(top: 8),
            title: const Text('Ver factura y opciones',
                style: TextStyle(fontSize: 13)),
            children: [sections.payment],
          ),
        ),
      ]),
    );
    final supplier = OrderDetailSection(
      title: 'Contacto',
      icon: Icons.storefront_outlined,
      flat: true,
      child: _SupplierContact(request: request),
    );
    final primary = [tracking, products, payment];
    final secondary = [delivery, supplier];

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      widget.summary,
      const SizedBox(height: 16),
      if (providers.length > 1) ...[
        _ProviderSelector(
            providers: providers,
            selectedOwner: request.ownerId,
            onSelected: (owner) => setState(() => _owner = owner)),
        const SizedBox(height: 16),
      ],
      // Remount supplier-specific forms on selection; an ordinary data refresh
      // keeps their state because this key remains stable.
      KeyedSubtree(
        key: ValueKey('supplier-detail-${request.ownerId}'),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (sections.attention != null) ...[
            sections.attention!,
            const SizedBox(height: 16),
          ],
          OrderDetailColumns(
              primary: primary,
              secondary: secondary,
              mobileOrder: [tracking, products, delivery, payment, supplier]),
          if (sections.afterSales != null) ...[
            const SizedBox(height: 16),
            OrderDetailSection(
                title: 'Después de la entrega',
                icon: Icons.verified_outlined,
                child: sections.afterSales!),
          ],
        ]),
      ),
    ]);
  }
}

/// Two reading columns on desktop; a single natural order with large text/mobile.
class OrderDetailColumns extends StatelessWidget {
  const OrderDetailColumns(
      {super.key,
      required this.primary,
      required this.secondary,
      this.mobileOrder});
  final List<Widget> primary;
  final List<Widget> secondary;
  final List<Widget>? mobileOrder;

  Widget _stack(List<Widget> children) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 16),
            children[i],
          ]
        ],
      );

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        if (constraints.maxWidth < 900 ||
            MediaQuery.textScalerOf(context).scale(14) > 20) {
          return _stack(mobileOrder ?? [...primary, ...secondary]);
        }
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 3, child: _stack(primary)),
          const SizedBox(width: 16),
          Expanded(flex: 2, child: _stack(secondary)),
        ]);
      });
}

class _OrderProducts extends StatelessWidget {
  const _OrderProducts({required this.lines});
  final List<TransactionRequestModel> lines;

  @override
  Widget build(BuildContext context) {
    final colors = OrderListColors.of(context);
    final discount = computeVolumeDiscountForLines(lines);
    final products = [
      for (final line in lines)
        ...orderCardProductPeeks(lines: [line], importerUserId: line.ownerId)
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (var i = 0; i < products.length; i++) ...[
        if (i > 0)
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Divider(height: 1, color: colors.border)),
        _DetailProductRow(product: products[i]),
      ],
      if (discount != null) ...[
        const SizedBox(height: 12),
        Text(discount.resumenEs,
            style: TextStyle(fontSize: 12, color: colors.accent)),
      ],
    ]);
  }
}

class _DetailProductRow extends StatelessWidget {
  const _DetailProductRow({required this.product});
  final OrderCardProductPeek product;

  @override
  Widget build(BuildContext context) {
    final colors = OrderListColors.of(context);
    final image = product.imageUrl;
    Widget fallback() => ColoredBox(
        color: colors.soft,
        child:
            Icon(Icons.inventory_2_outlined, size: 27, color: colors.accent));
    final photo = ExcludeSemantics(
        child: Container(
            width: 64,
            height: 64,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
                color: colors.soft, borderRadius: BorderRadius.circular(10)),
            child: image == null
                ? fallback()
                : Image.network(image,
                    fit: BoxFit.contain,
                    cacheWidth: 160,
                    errorBuilder: (_, __, ___) => fallback())));
    final info =
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(product.name,
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: colors.ink,
              height: 1.35)),
      if (product.sku?.trim().isNotEmpty == true) ...[
        const SizedBox(height: 4),
        Text('SKU ${product.sku}',
            style: TextStyle(fontSize: 12, color: colors.secondary)),
      ],
      const SizedBox(height: 6),
      Text(
          '${product.quantity} ${product.quantity == 1 ? 'unidad' : 'unidades'}',
          style: TextStyle(fontSize: 12, color: colors.secondary)),
    ]);
    final amount = Text(
        '${formatRefAmount(product.lineTotalRef)} ${product.currencyLabel}',
        style: TextStyle(
            fontSize: 16, fontWeight: FontWeight.w700, color: colors.ink));
    return LayoutBuilder(builder: (context, constraints) {
      final compact = constraints.maxWidth < 460 ||
          MediaQuery.textScalerOf(context).scale(14) > 20;
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        photo,
        const SizedBox(width: 12),
        Expanded(
            child: compact
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [info, const SizedBox(height: 8), amount])
                : info),
        if (!compact) ...[
          const SizedBox(width: 16),
          Expanded(
              child: Align(alignment: Alignment.centerRight, child: amount))
        ],
      ]);
    });
  }
}

class _ProviderSelector extends StatelessWidget {
  const _ProviderSelector(
      {required this.providers,
      required this.selectedOwner,
      required this.onSelected});
  final List<List<TransactionRequestModel>> providers;
  final String selectedOwner;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = OrderListColors.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 10),
          child: Text('Proveedores de tu compra',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colors.ink))),
      SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (var i = 0; i < providers.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Builder(builder: (context) {
                final provider = providers[i];
                final entry = OrderListEntry(provider);
                final selected = provider.first.ownerId == selectedOwner;
                return Semantics(
                  button: true,
                  selected: selected,
                  child: Material(
                    color: selected ? colors.soft : colors.surface,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                            color: selected ? colors.accent : colors.border)),
                    child: InkWell(
                      onTap: () => onSelected(provider.first.ownerId),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 240,
                        padding: const EdgeInsets.all(12),
                        child: Row(children: [
                          Icon(
                              selected
                                  ? Icons.check_circle
                                  : Icons.storefront_outlined,
                              size: 20,
                              color: colors.accent),
                          const SizedBox(width: 10),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(
                                    provider.first.ownerBusinessName ??
                                        'Proveedor',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: colors.ink)),
                                const SizedBox(height: 4),
                                Text(entry.status,
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: entry.statusColor(context))),
                              ])),
                        ]),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ])),
    ]);
  }
}

class _SupplierContact extends StatelessWidget {
  const _SupplierContact({required this.request});
  final TransactionRequestModel request;

  @override
  Widget build(BuildContext context) {
    final colors = OrderListColors.of(context);
    final address = [
      request.ownerDireccion,
      request.ownerCiudad,
      request.ownerEstado
    ]
        .whereType<String>()
        .map((v) => v.trim())
        .where((v) => v.isNotEmpty)
        .join(', ');
    final map = Uri.tryParse(request.ownerFiscalMapsUrl?.trim() ?? '');
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(
          request.ownerBusinessName?.trim().isNotEmpty == true
              ? request.ownerBusinessName!.trim()
              : 'Proveedor',
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.4,
              color: colors.ink)),
      if (request.ownerRif?.trim().isNotEmpty == true) ...[
        const SizedBox(height: 5),
        Text('RIF ${request.ownerRif}',
            style: TextStyle(fontSize: 12, color: colors.secondary)),
      ],
      if (request.ownerPhone?.trim().isNotEmpty == true) ...[
        const SizedBox(height: 12),
        Row(children: [
          Icon(Icons.phone_outlined, size: 16, color: colors.accent),
          const SizedBox(width: 8),
          Expanded(
              child: SelectableText(request.ownerPhone!,
                  style: TextStyle(fontSize: 13, color: colors.ink)))
        ]),
      ],
      if (address.isNotEmpty) ...[
        const SizedBox(height: 12),
        Text('Dirección fiscal',
            style: TextStyle(fontSize: 12, color: colors.secondary)),
        const SizedBox(height: 4),
        Text(address,
            style: TextStyle(fontSize: 13, height: 1.5, color: colors.ink)),
      ],
      if (map != null && (map.scheme == 'http' || map.scheme == 'https')) ...[
        const SizedBox(height: 8),
        Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
                onPressed: () async {
                  final ok = await launchUrl(map,
                      mode: LaunchMode.externalApplication);
                  if (!ok && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('No se pudo abrir la ubicación.')));
                  }
                },
                icon: const Icon(Icons.map_outlined, size: 18),
                label: const Text('Ver ubicación'),
                style: TextButton.styleFrom(
                    foregroundColor: colors.accent, padding: EdgeInsets.zero))),
      ],
    ]);
  }
}

class OrderDetailSection extends StatelessWidget {
  const OrderDetailSection(
      {super.key,
      required this.title,
      required this.child,
      this.icon,
      this.tonal = false,
      this.flat = false});
  final String title;
  final Widget child;
  final IconData? icon;
  final bool tonal;
  final bool flat;

  @override
  Widget build(BuildContext context) {
    final colors = OrderListColors.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tonal ? colors.soft : colors.surface,
        border: flat || tonal ? null : Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          if (icon != null) ...[
            Icon(icon, size: 19, color: colors.accent),
            const SizedBox(width: 9)
          ],
          Expanded(
              child: Text(title,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: colors.ink))),
        ]),
        const SizedBox(height: 16),
        child,
      ]),
    );
  }
}
