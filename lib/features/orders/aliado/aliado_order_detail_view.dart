import '../shared/order_detail_layout.dart';
export '../shared/order_detail_layout.dart';
import 'package:flutter/material.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';
import 'package:motolink_pro_app/features/catalog/importer_catalog_logo.dart';
import 'package:motolink_pro_app/features/catalog/importer_store_profile_screen.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';
import 'package:motolink_pro_app/features/payments/motolink_volume_discount.dart';
import 'package:motolink_pro_app/features/profile/app_home_role.dart';
import 'package:url_launcher/url_launcher.dart';
import '../shared/order_list_colors.dart';
import '../shared/order_list_entry.dart';
import '../shared/order_delivery_stepper.dart';
import '../shared/aliado_order_grouping.dart';
import '../shared/courier_timeline_widget.dart';
import '../shared/moroso_order_visual.dart';
import '../shared/transaction_request_model.dart';
import '../importador/importer_aliado_solicitud_section.dart';
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
    this.onOpenPayment,
  });
  final Widget payment;
  final String paymentStatus;
  final bool paymentOpen;
  final Widget? attention;
  final Widget? receipt;
  final Widget? deliveryActions;
  final Widget? afterSales;
  final VoidCallback? onOpenPayment;
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
    this.compact = false,
    this.viewerProfile,
    this.onMessageProvider,
    this.summaryBuilder,
  });
  final List<TransactionRequestModel> lines;
  final Widget summary;

  /// Receives the selected supplier so its actions never target other suppliers.
  final Widget Function(
          BuildContext context, List<TransactionRequestModel> selected)?
      summaryBuilder;
  final AliadoDetailSectionsBuilder sectionsBuilder;
  final bool compact;
  final ProfileModel? viewerProfile;
  final ValueChanged<List<TransactionRequestModel>>? onMessageProvider;

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
    final volumeDiscount = computeVolumeDiscountForLines(chunk);
    final compact = widget.compact;
    final gap = compact ? 10.0 : 16.0;

    final history = Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        key: PageStorageKey('history-${request.id}'),
        dense: compact,
        tilePadding: compact
            ? const EdgeInsets.symmetric(horizontal: 10)
            : EdgeInsets.zero,
        childrenPadding:
            EdgeInsets.fromLTRB(compact ? 10 : 0, 4, compact ? 10 : 0, 6),
        leading: compact ? const Icon(Icons.schedule_outlined, size: 19) : null,
        title: Text(compact ? 'Historial del pedido' : 'Historial del envío',
            style: TextStyle(
                fontSize: 13, fontWeight: compact ? FontWeight.w700 : null)),
        children: [
          for (final line in sameShipping ? [request] : chunk)
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (!sameShipping) ...[
                Text(line.etiquetaProductoAliado,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                AliadoTransitEtaBanner(request: line),
              ],
              CourierTimelineWidget(
                  request: line,
                  compact: true,
                  viewerRole: AppHomeRole.aliado,
                  showHeading: false,
                  embedded: true),
            ]),
        ],
      ),
    );
    final tracking = OrderDetailSection(
      title: 'Seguimiento',
      icon: Icons.local_shipping_outlined,
      tonal: true,
      compact: compact,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        OrderDeliveryStepper(lines: chunk, horizontalCompact: compact),
        if (sameShipping && AliadoTransitEtaBanner.shouldShow(request))
          AliadoTransitEtaBanner(request: request),
        if (sections.receipt != null) sections.receipt!,
        if (chunk.any((l) => l.esPedidoMoroso))
          MorosoOrderCardNotice(
            request: chunk.firstWhere((l) => l.esPedidoMoroso),
            expanded: true,
            aliadoViewer: true,
          ),
        if (!compact) history,
      ]),
    );
    final products = OrderDetailSection(
      title: 'Productos',
      compact: compact,
      icon: Icons.shopping_bag_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TransactionRequestProductosDesgloseSection(
            lines: chunk,
            compact: compact,
            retailerDetail: compact,
            viewer: PedidoDesgloseViewer.aliado,
            hideSectionTitle: true,
            showPrecioHelp: false,
            showImporterGroupHeaders: false,
          ),
          if (volumeDiscount != null) ...[
            const SizedBox(height: 12),
            Text(
              volumeDiscount.resumenEs,
              style: TextStyle(fontSize: 12, color: colors.accent),
            ),
          ],
        ],
      ),
    );
    final deliveryLabel = request.customerPickup
        ? 'Retiro en tienda · ${request.customerDeliverySnapshot['label'] ?? 'Proveedor'}'
        : request.destinoEntregaUsaPerfil
            ? 'Dirección de tu tienda'
            : 'Dirección alterna';
    final deliveryAddress = request.checkoutDeliveryAddress.isNotEmpty
        ? request.checkoutDeliveryAddress
        : request.destinoEntregaUsaPerfil
            ? request.aliadoDireccionFiscalMultilineaEs ??
                'Dirección de la tienda aún no disponible.'
            : request.destinoEntregaTexto?.trim().isNotEmpty == true
                ? request.destinoEntregaTexto!.trim()
                : 'Otro destino (sin texto guardado)';
    final delivery = OrderDetailSection(
      title: 'Entrega',
      compact: compact,
      icon: Icons.location_on_outlined,
      flat: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (compact)
          _DetailInset(
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: colors.accent.withOpacity(.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.location_on_outlined,
                    size: 22, color: colors.accent),
              ),
              const SizedBox(width: 9),
              Expanded(
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(deliveryLabel,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: colors.ink)),
                  const SizedBox(height: 2),
                  Text(deliveryAddress,
                      style: TextStyle(
                          fontSize: 12, height: 1.25, color: colors.secondary)),
                ],
              )),
            ]),
          )
        else ...[
          Text(deliveryLabel,
              style: TextStyle(fontSize: 12, color: colors.secondary)),
          const SizedBox(height: 6),
          Text(deliveryAddress,
              style: TextStyle(fontSize: 13, height: 1.5, color: colors.ink)),
        ],
        if (request.customerPickup) ...[
          const Text('Retiro sin costo',
              style: TextStyle(fontWeight: FontWeight.w600)),
          if ((request.customerDeliverySnapshot['instructions'] as String? ??
                  '')
              .isNotEmpty)
            Text(request.customerDeliverySnapshot['instructions'] as String),
        ],
        if (request.customerDeliverySnapshot['maps_url'] case final String maps)
          Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                  icon: const Icon(Icons.location_on_outlined, size: 18),
                  label: const Text('Ver ubicación de entrega'),
                  onPressed: () async {
                    final uri = Uri.tryParse(maps);
                    if (uri != null &&
                        ['https', 'http'].contains(uri.scheme) &&
                        uri.host.isNotEmpty) {
                      await launchUrl(uri,
                          mode: LaunchMode.externalApplication);
                    }
                  })),
        if (sections.deliveryActions != null && !request.customerPickup) ...[
          const SizedBox(height: 12),
          sections.deliveryActions!,
        ],
      ]),
    );
    final payment = compact
        ? _DetailTile(
            child: sections.onOpenPayment != null
                ? ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                    leading: const Icon(Icons.receipt_long_outlined, size: 19),
                    title: Text('Pago y factura',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, color: colors.ink)),
                    subtitle: Text(sections.paymentStatus,
                        style:
                            TextStyle(fontSize: 12, color: colors.secondary)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: sections.onOpenPayment,
                  )
                : ExpansionTile(
                    key: PageStorageKey('payment-${request.id}'),
                    initiallyExpanded: sections.paymentOpen,
                    maintainState: true,
                    dense: true,
                    tilePadding: const EdgeInsets.symmetric(horizontal: 10),
                    childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                    leading: const Icon(Icons.receipt_long_outlined, size: 19),
                    title: Text('Pago y factura',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, color: colors.ink)),
                    subtitle: Text(sections.paymentStatus,
                        style:
                            TextStyle(fontSize: 12, color: colors.secondary)),
                    children: [sections.payment],
                  ),
          )
        : OrderDetailSection(
            title: 'Pago y factura',
            icon: Icons.account_balance_wallet_outlined,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(sections.paymentStatus,
                      style: TextStyle(
                          fontSize: 13, height: 1.4, color: colors.secondary)),
                  if (sections.onOpenPayment case final openPayment?)
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton.icon(
                        onPressed: openPayment,
                        icon: const Icon(Icons.receipt_long_outlined, size: 18),
                        label: const Text('Ver factura y opciones'),
                      ),
                    )
                  else
                    Theme(
                      data: Theme.of(context)
                          .copyWith(dividerColor: Colors.transparent),
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
      title: compact ? 'Contacto del proveedor' : 'Contacto',
      compact: compact,
      icon: Icons.storefront_outlined,
      flat: true,
      child: _SupplierContact(
          request: request,
          compact: compact,
          viewerProfile: widget.viewerProfile,
          onMessage: widget.onMessageProvider == null
              ? null
              : () => widget.onMessageProvider!(chunk)),
    );
    final primary = [tracking, products, payment];
    final secondary = [delivery, supplier];

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      widget.summaryBuilder?.call(context, chunk) ?? widget.summary,
      SizedBox(height: gap),
      if (providers.length > 1) ...[
        _ProviderSelector(
            providers: providers,
            selectedOwner: request.ownerId,
            onSelected: (owner) => setState(() => _owner = owner)),
        SizedBox(height: gap),
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
              compact: compact,
              mobileOrder: [
                tracking,
                if (compact) _DetailTile(child: history),
                products,
                delivery,
                payment,
                supplier,
              ]),
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

class _DetailTile extends StatelessWidget {
  const _DetailTile({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Material(
        color: OrderListColors.of(context).detailSurface,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: child,
        ),
      );
}

class _DetailInset extends StatelessWidget {
  const _DetailInset({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(11),
        ),
        child: child,
      );
}

class _SupplierContact extends StatelessWidget {
  const _SupplierContact({
    required this.request,
    required this.compact,
    this.viewerProfile,
    this.onMessage,
  });
  final TransactionRequestModel request;
  final bool compact;
  final ProfileModel? viewerProfile;
  final VoidCallback? onMessage;

  Future<void> _launch(BuildContext context, Uri uri, String error) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Widget _compactContact(BuildContext context, String address, Uri? map) {
    final colors = OrderListColors.of(context);
    final name = request.ownerBusinessName?.trim();
    final rif = request.ownerRif?.trim() ?? '';
    final phone = request.ownerPhone?.trim() ?? '';
    final profile = viewerProfile;
    final meta = TextStyle(fontSize: 12, color: colors.secondary);
    Widget detail(IconData icon, Widget value) => Column(children: [
          Divider(height: 12, color: colors.border),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 17, color: colors.ink),
            const SizedBox(width: 9),
            Expanded(child: value),
          ]),
        ]);
    return _DetailInset(
        child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          ClipOval(
              child: ImporterCatalogLogo(
                  storagePath: request.ownerLogoStoragePath, size: 54)),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name == null || name.isEmpty ? 'Proveedor' : name,
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: colors.ink)),
              if (name != null && name.isNotEmpty)
                Text('Proveedor', style: meta),
            ],
          )),
        ]),
        if (rif.isNotEmpty)
          detail(Icons.badge_outlined, Text('RIF · $rif', style: meta)),
        if (phone.isNotEmpty)
          detail(Icons.phone_outlined, SelectableText(phone, style: meta)),
        if (address.isNotEmpty)
          detail(
              Icons.location_on_outlined,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Dirección fiscal',
                      style: meta.copyWith(fontWeight: FontWeight.w700)),
                  Text(address, style: meta),
                ],
              )),
        if (onMessage != null || map != null) ...[
          const SizedBox(height: 7),
          Wrap(spacing: 7, runSpacing: 4, children: [
            if (onMessage != null)
              OutlinedButton.icon(
                onPressed: onMessage,
                icon: const LucideIcon(LucideGlyph.messageCircle, size: 17),
                label: const Text('Mensaje'),
              ),
            if (map != null)
              TextButton.icon(
                onPressed: () =>
                    _launch(context, map, 'No se pudo abrir la ubicación.'),
                icon: const Icon(Icons.location_on_outlined, size: 16),
                label: const Text('Ver ubicación'),
              ),
          ]),
        ],
        if (profile != null && request.ownerId.trim().isNotEmpty) ...[
          Divider(height: 10, color: colors.border),
          Center(
              child: TextButton(
            onPressed: () => Navigator.of(context).push<void>(MaterialPageRoute(
              builder: (_) => ImporterStoreProfileScreen(
                  importerId: request.ownerId, viewer: profile),
            )),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Text('Ver tienda'),
              SizedBox(width: 5),
              Icon(Icons.arrow_forward, size: 16),
            ]),
          )),
        ],
      ],
    ));
  }

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
    if (compact) {
      final validMap = map != null &&
          (map.scheme == 'http' || map.scheme == 'https') &&
          map.hasAuthority;
      return _compactContact(context, address, validMap ? map : null);
    }
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
