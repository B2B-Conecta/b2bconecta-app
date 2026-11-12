import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'package:motolink_pro_app/core/layout/app_breakpoints.dart';
import 'package:motolink_pro_app/core/layout/b2b_data_table_shell.dart';
import 'package:motolink_pro_app/core/layout/list_page_bar.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';
import 'package:motolink_pro_app/features/orders/shared/admin_order_panel_utils.dart';
import 'package:motolink_pro_app/features/orders/shared/aliado_order_grouping.dart';
import 'package:motolink_pro_app/features/orders/shared/order_list_entry.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_model.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_status.dart';
import 'package:motolink_pro_app/features/payments/pago_metodo.dart';
import 'package:motolink_pro_app/features/payments/pago_revision_estado.dart';
import 'package:motolink_pro_app/features/profile/app_home_role.dart';

/// Tabla corporativa de pedidos admin (`OrdersModule` / bandeja Pedidos).
class OrdersDataTable extends StatefulWidget {
  const OrdersDataTable({
    super.key,
    required this.groups,
    required this.onOpen,
    this.selectedKey,
    this.loading = false,
    this.emptyMessage,
    this.onClearFilters,
    this.onRefresh,
    this.canCancel,
    this.onCancel,
    this.resetKey,
  });

  final List<List<TransactionRequestModel>> groups;
  final ValueChanged<List<TransactionRequestModel>> onOpen;
  final String? selectedKey;
  final bool loading;
  final String? emptyMessage;
  final VoidCallback? onClearFilters;
  final Future<void> Function()? onRefresh;
  final bool Function(List<TransactionRequestModel> group)? canCancel;
  final ValueChanged<List<TransactionRequestModel>>? onCancel;
  final Object? resetKey;

  @override
  State<OrdersDataTable> createState() => _OrdersDataTableState();
}

class _OrdersDataTableState extends State<OrdersDataTable> {
  int _pageIndex = 0;
  int _pageSize = listPageSizeOptions.first;
  Object? _lastReset;

  @override
  void didUpdateWidget(covariant OrdersDataTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.resetKey != _lastReset) {
      _lastReset = widget.resetKey;
      _pageIndex = 0;
    }
  }

  String _keyOf(List<TransactionRequestModel> g) => checkoutGroupExpandKey(g);

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final groups = widget.groups;
    final page = sliceListPage(
      items: groups,
      pageIndex: _pageIndex,
      pageSize: _pageSize,
    );

    final emptyBody = widget.loading && groups.isEmpty
        ? Padding(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Center(
              child: CircularProgressIndicator(color: theme.brand),
            ),
          )
        : groups.isEmpty
            ? Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
                child: Column(
                  children: [
                    LucideIcon(
                      LucideGlyph.searchX,
                      size: 28,
                      color: theme.textMuted,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.emptyMessage ??
                          'No encontramos pedidos con estos filtros.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: theme.textSecondary,
                      ),
                    ),
                    if (widget.onClearFilters != null) ...[
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: widget.onClearFilters,
                        child: const Text('Ver todos los pedidos'),
                      ),
                    ],
                  ],
                ),
              )
            : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final mobileCards =
            constraints.maxWidth < AppBreakpoints.mobileMenu;
        return B2bDataTableShell(
          padding: const EdgeInsets.all(12),
          header: mobileCards
              ? null
              : const B2bDataTableHeader(
                  cells: [
                    B2bDataTableHeaderCell(label: 'ID pedido', flex: 2),
                    B2bDataTableHeaderCell(label: 'Cliente / Taller', flex: 3),
                    B2bDataTableHeaderCell(
                        label: 'Producto y partidas', flex: 3),
                    B2bDataTableHeaderCell(label: 'Total REF / Bs', flex: 2),
                    B2bDataTableHeaderCell(label: 'Estado pago', flex: 2),
                    B2bDataTableHeaderCell(label: 'Encomienda', flex: 2),
                  ],
                ),
          empty: emptyBody,
          rows: [
            for (var i = 0; i < page.length; i++)
              _OrderGroupRow(
                group: page[i],
                zebra: i.isOdd,
                isLast: i == page.length - 1,
                selected: widget.selectedKey == _keyOf(page[i]),
                onOpen: () => widget.onOpen(page[i]),
                canCancel: widget.canCancel?.call(page[i]) ?? false,
                onCancel: widget.onCancel == null
                    ? null
                    : () => widget.onCancel!(page[i]),
                forceMobileCard: mobileCards,
              ),
          ],
          footer: ListPageBar(
            total: groups.length,
            pageIndex: _pageIndex,
            pageSize: _pageSize,
            alwaysShow: groups.isNotEmpty,
            entityLabel: 'pedidos',
            onPageIndex: (i) => setState(() => _pageIndex = i),
            onPageSize: (size) => setState(() {
              _pageSize = size;
              _pageIndex = 0;
            }),
          ),
        );
      },
    );
  }
}

class _OrderGroupRow extends StatefulWidget {
  const _OrderGroupRow({
    required this.group,
    required this.zebra,
    required this.isLast,
    required this.selected,
    required this.onOpen,
    required this.canCancel,
    this.onCancel,
    this.forceMobileCard = false,
  });

  final List<TransactionRequestModel> group;
  final bool zebra;
  final bool isLast;
  final bool selected;
  final VoidCallback onOpen;
  final bool canCancel;
  final VoidCallback? onCancel;
  final bool forceMobileCard;

  @override
  State<_OrderGroupRow> createState() => _OrderGroupRowState();
}

class _OrderGroupRowState extends State<_OrderGroupRow> {
  bool _hovered = false;

  TransactionRequestModel get _primary => widget.group.first;

  String get _shortId {
    final entry = OrderListEntry(
      widget.group,
      viewerRole: AppHomeRole.administrador,
    );
    return entry.reference;
  }

  String get _clientName {
    final n = _primary.aliadoBusinessName?.trim();
    if (n != null && n.isNotEmpty) return n;
    return 'Tienda sin nombre';
  }

  String get _clientMeta {
    final rif = _primary.aliadoRif?.trim();
    final locParts = <String>[
      if ((_primary.aliadoCiudad ?? '').trim().isNotEmpty)
        _primary.aliadoCiudad!.trim(),
      if ((_primary.aliadoEstado ?? '').trim().isNotEmpty)
        _primary.aliadoEstado!.trim(),
    ];
    final loc = locParts.join(', ');
    if (rif != null && rif.isNotEmpty && loc.isNotEmpty) return '$rif · $loc';
    if (rif != null && rif.isNotEmpty) return rif;
    if (loc.isNotEmpty) return loc;
    return 'Cliente B2B';
  }

  String _initials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final s = parts.first;
      return s.substring(0, s.length >= 2 ? 2 : 1).toUpperCase();
    }
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  String get _productsLabel {
    final names = widget.group
        .map((r) => (r.productName ?? '').trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (names.isEmpty) return 'Sin productos';
    if (names.length == 1) return names.first;
    return '${names.first} +${names.length - 1}';
  }

  String get _unitsLabel {
    final uds = adminCheckoutGroupTotalUds(widget.group);
    final lines = widget.group.length;
    if (lines > 1) {
      return '$lines partidas · $uds uds';
    }
    return '$uds ${uds == 1 ? 'unidad' : 'unidades'}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final entry = OrderListEntry(
      widget.group,
      viewerRole: AppHomeRole.administrador,
    );
    final highlight = _hovered || widget.selected;
    final base = widget.zebra ? theme.tableRowOdd : theme.tableRowEven;
    final bg = highlight ? theme.surfaceSubtle : base;

    final idCell = InkWell(
      onTap: widget.onOpen,
      borderRadius: BorderRadius.circular(6),
      child: Text(
        _shortId,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
          color: theme.brand,
          decoration: TextDecoration.underline,
          decorationColor: theme.brand.withOpacity(0.35),
        ),
      ),
    );

    final clientCell = Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: theme.brandContainer,
          child: Text(
            _initials(_clientName),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: theme.brand,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _clientName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: theme.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _clientMeta,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: theme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    final productCell = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _productsLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: theme.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          _unitsLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: theme.textSecondary,
          ),
        ),
      ],
    );

    final totalCell = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          entry.amount,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: theme.textPrimary,
          ),
        ),
        if (entry.bolivares != null) ...[
          const SizedBox(height: 2),
          Text(
            entry.bolivares!,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: theme.textSecondary,
            ),
          ),
        ] else if (orderAmountCurrency(widget.group) == 'REF') ...[
          const SizedBox(height: 2),
          Text(
            'Bs —',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: theme.textMuted,
            ),
          ),
        ],
      ],
    );

    final payment = _PaymentStatusBadge(group: widget.group);
    final fulfillment = _FulfillmentStatusBadge(group: widget.group);

    final actions = B2bDataRowActionsMenu(
      actions: [
        const B2bDataRowAction(
          id: 'view',
          label: 'Ver detalle',
          glyph: LucideGlyph.eye,
        ),
        const B2bDataRowAction(
          id: 'edit',
          label: 'Editar pedido',
          glyph: LucideGlyph.pencil,
        ),
        B2bDataRowAction(
          id: 'cancel',
          label: 'Cancelar / Suspender',
          glyph: LucideGlyph.circlePause,
          destructive: true,
          enabled: widget.canCancel && widget.onCancel != null,
        ),
      ],
      onSelected: (id) {
        switch (id) {
          case 'view':
          case 'edit':
            widget.onOpen();
          case 'cancel':
            widget.onCancel?.call();
        }
      },
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        color: bg,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onOpen,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
              decoration: BoxDecoration(
                border: widget.isLast
                    ? null
                    : Border(bottom: BorderSide(color: theme.borderSubtle)),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = widget.forceMobileCard ||
                      constraints.maxWidth < AppBreakpoints.mobileMenu;
                  if (compact) {
                    // Tarjeta ejecutiva móvil: ID+badges · taller/producto · monto.
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Flexible(child: idCell),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Wrap(
                                alignment: WrapAlignment.end,
                                spacing: 6,
                                runSpacing: 4,
                                children: [payment, fulfillment],
                              ),
                            ),
                            actions,
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _clientName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: theme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$_productsLabel · $_unitsLabel',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: theme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              entry.amount,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: theme.textPrimary,
                              ),
                            ),
                            if (entry.bolivares != null) ...[
                              const SizedBox(width: 8),
                              Text(
                                entry.bolivares!,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: theme.textSecondary,
                                ),
                              ),
                            ] else if (orderAmountCurrency(widget.group) ==
                                'REF') ...[
                              const SizedBox(width: 8),
                              Text(
                                'Bs —',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: theme.textMuted,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 2, child: idCell),
                      const SizedBox(width: 8),
                      Expanded(flex: 3, child: clientCell),
                      const SizedBox(width: 8),
                      Expanded(flex: 3, child: productCell),
                      const SizedBox(width: 8),
                      Expanded(flex: 2, child: totalCell),
                      const SizedBox(width: 8),
                      Expanded(flex: 2, child: Align(
                        alignment: Alignment.centerLeft,
                        child: payment,
                      )),
                      const SizedBox(width: 8),
                      Expanded(flex: 2, child: Align(
                        alignment: Alignment.centerLeft,
                        child: fulfillment,
                      )),
                      actions,
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PaymentStatusBadge extends StatelessWidget {
  const _PaymentStatusBadge({required this.group});

  final List<TransactionRequestModel> group;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final r = group.first;
    final pe = r.pagoEstadoRevisionEfectivo;
    final metodo = r.pagoMetodo?.trim();

    String label;
    Color fg;
    Color bg;

    if (group.any((l) => l.esPedidoMoroso)) {
      label = 'Pendiente';
      fg = theme.textPrimary;
      bg = theme.surfaceSubtle;
    } else if (pe == PagoRevisionEstado.aprobado ||
        group.every((l) => l.pedidoEntregadoYPagado)) {
      label = 'Aprobado';
      fg = theme.successFg;
      bg = theme.successBg;
    } else if (metodo == PagoMetodo.pagoMovil) {
      label = 'Pago Móvil';
      fg = theme.brand;
      bg = theme.brandContainer;
    } else if (PagoMetodo.qualifiesForUsdDiscount(metodo)) {
      label = 'Divisas';
      fg = theme.brand;
      bg = theme.brandContainer;
    } else if (pe == PagoRevisionEstado.enRevision) {
      label = 'En revisión';
      fg = theme.brand;
      bg = theme.brandContainer;
    } else if (pe == PagoRevisionEstado.rechazado) {
      label = 'Rechazado';
      fg = Theme.of(context).colorScheme.error;
      bg = theme.surfaceSubtle;
    } else {
      label = 'Pendiente';
      fg = theme.textSecondary;
      bg = theme.inputFill;
    }

    if (metodo != null &&
        metodo.isNotEmpty &&
        pe == PagoRevisionEstado.aprobado) {
      // keep Aprobado as primary when already paid
    } else if (metodo != null &&
        metodo.isNotEmpty &&
        pe != PagoRevisionEstado.aprobado &&
        !group.any((l) => l.esPedidoMoroso) &&
        pe != PagoRevisionEstado.enRevision &&
        pe != PagoRevisionEstado.rechazado) {
      if (metodo == PagoMetodo.pagoMovil) {
        label = 'Pago Móvil';
        fg = theme.brand;
        bg = theme.brandContainer;
      } else if (PagoMetodo.qualifiesForUsdDiscount(metodo)) {
        label = 'Divisas';
        fg = theme.brand;
        bg = theme.brandContainer;
      }
    }

    return B2bDataStatusBadge(
      label: label,
      foreground: fg,
      background: bg,
    );
  }
}

class _FulfillmentStatusBadge extends StatelessWidget {
  const _FulfillmentStatusBadge({required this.group});

  final List<TransactionRequestModel> group;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final statuses = group.map((r) => r.status).toSet();
    final status = statuses.length == 1
        ? statuses.first
        : group.map((r) => r.status).fold<String>(
              TransactionRequestStatus.pendiente,
              (worst, s) {
                final phase = orderShippingPhase(s);
                final worstPhase = orderShippingPhase(worst);
                if (phase < 0) return worst;
                if (worstPhase < 0) return s;
                return phase < worstPhase ? s : worst;
              },
            );

    late final String label;
    late final Color fg;
    late final Color bg;

    switch (status) {
      case TransactionRequestStatus.pendiente:
        label = 'Nuevo en revisión';
        fg = theme.brand;
        bg = theme.brandContainer;
      case TransactionRequestStatus.enPreparacion:
      case TransactionRequestStatus.pedidoListo:
      case TransactionRequestStatus.aprobadoAdmin:
        label = 'En preparación';
        fg = theme.brand;
        bg = theme.brandContainer;
      case TransactionRequestStatus.enTransito:
      case TransactionRequestStatus.enviado:
        label = 'En tránsito';
        fg = theme.textPrimary;
        bg = theme.surfaceSubtle;
      case TransactionRequestStatus.entregado:
        label = 'Entregado';
        fg = theme.successFg;
        bg = theme.successBg;
      case TransactionRequestStatus.rechazado:
        label = 'Cancelado';
        fg = Theme.of(context).colorScheme.error;
        bg = theme.surfaceSubtle;
      default:
        label = adminCheckoutGroupStatusLabel(group);
        fg = theme.textSecondary;
        bg = theme.inputFill;
    }

    return B2bDataStatusBadge(
      label: label,
      foreground: fg,
      background: bg,
    );
  }
}
