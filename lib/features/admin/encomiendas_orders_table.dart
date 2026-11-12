import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'package:motolink_pro_app/core/layout/list_page_bar.dart';
import 'package:motolink_pro_app/core/utils/app_date_format.dart';
import 'package:motolink_pro_app/core/utils/ves_amount_format.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';
import 'package:motolink_pro_app/features/admin/accounts_table_skeleton.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_model.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_status.dart';
import 'package:motolink_pro_app/features/payments/document_type_preference.dart';
import 'package:motolink_pro_app/features/payments/pago_metodo.dart';
import 'package:motolink_pro_app/features/payments/pago_revision_estado.dart';
import 'package:motolink_pro_app/features/admin/encomiendas_order_detail_view.dart';

enum EncomiendasTableSort { product, date, amount, status }

/// Tabla profesional de pedidos/encomiendas (mismo lenguaje visual que Cuentas).
class EncomiendasOrdersTable extends StatefulWidget {
  const EncomiendasOrdersTable({
    super.key,
    required this.orders,
    this.loading = false,
    this.errorMessage,
    this.onRetry,
    this.onRefresh,
    this.pageSize = 10,
  });

  final List<TransactionRequestModel> orders;
  final bool loading;
  final String? errorMessage;
  final Future<void> Function()? onRetry;
  final Future<void> Function()? onRefresh;
  final int pageSize;

  @override
  State<EncomiendasOrdersTable> createState() => _EncomiendasOrdersTableState();
}

class _EncomiendasOrdersTableState extends State<EncomiendasOrdersTable> {
  int _pageIndex = 0;
  late int _pageSize;
  EncomiendasTableSort _sort = EncomiendasTableSort.date;
  bool _sortAsc = false;

  @override
  void initState() {
    super.initState();
    _pageSize = widget.pageSize.clamp(1, 50);
    if (!listPageSizeOptions.contains(_pageSize)) {
      _pageSize = listPageSizeOptions.first;
    }
  }

  List<TransactionRequestModel> get _sorted {
    final list = List<TransactionRequestModel>.from(widget.orders);
    int cmp(TransactionRequestModel a, TransactionRequestModel b) {
      switch (_sort) {
        case EncomiendasTableSort.product:
          return (a.productName ?? '')
              .toLowerCase()
              .compareTo((b.productName ?? '').toLowerCase());
        case EncomiendasTableSort.date:
          final ad = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bd = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return ad.compareTo(bd);
        case EncomiendasTableSort.amount:
          return a.precioTotal.compareTo(b.precioTotal);
        case EncomiendasTableSort.status:
          return TransactionRequestStatus.labelEs(a.status)
              .compareTo(TransactionRequestStatus.labelEs(b.status));
      }
    }

    list.sort((a, b) => _sortAsc ? cmp(a, b) : cmp(b, a));
    return list;
  }

  void _toggleSort(EncomiendasTableSort col) {
    setState(() {
      if (_sort == col) {
        _sortAsc = !_sortAsc;
      } else {
        _sort = col;
        _sortAsc = col == EncomiendasTableSort.product;
      }
      _pageIndex = 0;
    });
  }

  Future<void> _openDetail(TransactionRequestModel r) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => OrderDetailView(requestId: r.id),
      ),
    );
  }

  Future<void> _copyId(TransactionRequestModel r) async {
    await Clipboard.setData(ClipboardData(text: r.id));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('ID del pedido copiado.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final sorted = _sorted;
    final page = sliceListPage(
      items: sorted,
      pageIndex: _pageIndex,
      pageSize: _pageSize,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.borderStrong),
        boxShadow: [
          BoxShadow(
            color: theme.textPrimary.withOpacity(
              Theme.of(context).brightness == Brightness.dark ? 0.35 : 0.04,
            ),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Toolbar(
            theme: theme,
            total: sorted.length,
            onRefresh: widget.onRefresh,
          ),
          const SizedBox(height: 12),
          if (widget.errorMessage != null && widget.orders.isEmpty) ...[
            _ErrorBanner(
              theme: theme,
              message: widget.errorMessage!,
              onRetry: widget.onRetry ?? widget.onRefresh,
            ),
            const SizedBox(height: 12),
          ],
          if (widget.loading)
            const AccountsTableSkeleton(compact: false)
          else ...[
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 860;
                return Column(
                  children: [
                    _StickyHeader(
                      theme: theme,
                      compact: compact,
                      sort: _sort,
                      sortAsc: _sortAsc,
                      onSort: _toggleSort,
                    ),
                    if (page.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 36),
                        child: Text(
                          'Sin pedidos en el periodo filtrado.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.textSecondary,
                          ),
                        ),
                      )
                    else
                      for (var i = 0; i < page.length; i++)
                        _OrderRow(
                          order: page[i],
                          theme: theme,
                          zebra: i.isOdd,
                          compact: compact,
                          onView: () => _openDetail(page[i]),
                          onCopyId: () => _copyId(page[i]),
                        ),
                    ListPageBar(
                      total: sorted.length,
                      pageIndex: _pageIndex,
                      pageSize: _pageSize,
                      alwaysShow: sorted.isNotEmpty,
                      onPageIndex: (index) =>
                          setState(() => _pageIndex = index),
                      onPageSize: (size) => setState(() {
                        _pageSize = size;
                        _pageIndex = 0;
                      }),
                    ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.theme,
    required this.total,
    this.onRefresh,
  });

  final B2BThemeExtension theme;
  final int total;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            '$total pedido${total == 1 ? '' : 's'}',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: theme.textSecondary,
            ),
          ),
        ),
        if (onRefresh != null)
          IconButton(
            tooltip: 'Actualizar',
            onPressed: () => onRefresh?.call(),
            icon: LucideIcon(
              LucideGlyph.refreshCw,
              size: 18,
              color: theme.textSecondary,
            ),
          ),
      ],
    );
  }
}

class _StickyHeader extends StatelessWidget {
  const _StickyHeader({
    required this.theme,
    required this.compact,
    required this.sort,
    required this.sortAsc,
    required this.onSort,
  });

  final B2BThemeExtension theme;
  final bool compact;
  final EncomiendasTableSort sort;
  final bool sortAsc;
  final ValueChanged<EncomiendasTableSort> onSort;

  @override
  Widget build(BuildContext context) {
    Widget head(String label, EncomiendasTableSort col, {int flex = 1}) {
      final active = sort == col;
      return Expanded(
        flex: flex,
        child: InkWell(
          onTap: () => onSort(col),
          child: Row(
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: active ? theme.brand : theme.textSecondary,
                  ),
                ),
              ),
              LucideIcon(
                active && sortAsc
                    ? LucideGlyph.trendingUp
                    : LucideGlyph.trendingDown,
                size: 12,
                color: active ? theme.brand : theme.textSecondary,
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
      decoration: BoxDecoration(
        color: theme.tableHeaderBg,
        border: Border(
          bottom: BorderSide(color: theme.borderSubtle),
          top: BorderSide(color: theme.borderSubtle),
        ),
      ),
      child: Row(
        children: [
          if (compact)
            head('Pedido', EncomiendasTableSort.product, flex: 3)
          else ...[
            head('Producto', EncomiendasTableSort.product, flex: 4),
            head('Fecha', EncomiendasTableSort.date, flex: 2),
            head('Monto', EncomiendasTableSort.amount, flex: 2),
            head('Estado', EncomiendasTableSort.status, flex: 2),
            const SizedBox(width: 48),
          ],
        ],
      ),
    );
  }
}

class _OrderRow extends StatelessWidget {
  const _OrderRow({
    required this.order,
    required this.theme,
    required this.zebra,
    required this.compact,
    required this.onView,
    required this.onCopyId,
  });

  final TransactionRequestModel order;
  final B2BThemeExtension theme;
  final bool zebra;
  final bool compact;
  final VoidCallback onView;
  final VoidCallback onCopyId;

  String? get _pagoLabel {
    final pe = order.pagoEstadoRevision?.trim();
    if (pe == null || pe.isEmpty) return null;
    switch (pe) {
      case PagoRevisionEstado.pendiente:
        return 'Pago pendiente';
      case PagoRevisionEstado.enRevision:
        return 'Pago en revisión';
      case PagoRevisionEstado.aprobado:
        return 'Pago aprobado';
      case PagoRevisionEstado.rechazado:
        return 'Pago rechazado';
      default:
        return pe;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sku = (order.productSku ?? '').trim();
    final name = (order.productName ?? '').trim().isEmpty
        ? 'Producto'
        : order.productName!.trim();
    final doc = order.documentTypePreference?.trim();
    final docLabel = doc == null || doc.isEmpty
        ? 'Pendiente'
        : (DocumentTypePreference.labelEs(doc) ?? doc);
    final metodo = order.pagoMetodo?.trim();
    final metodoLabel =
        (metodo == null || metodo.isEmpty) ? null : PagoMetodo.labelEs(metodo);
    final bs = order.precioTotalBsUi;
    final rate = order.tasaBcvAplicada ?? order.tasaBcvSnapshot;
    final hasRating = order.aliadoExperienceSubmittedAt != null;
    final stars = order.aliadoExperienceStars ?? 0;
    final comment = (order.aliadoExperienceComment ?? '').trim();

    final productCell = Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: theme.brandContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: LucideIcon(
            LucideGlyph.package,
            size: 18,
            color: theme.brand,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: theme.textPrimary,
                ),
              ),
              if (sku.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  sku,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                    color: theme.textSecondary,
                  ),
                ),
              ],
              if (compact) ...[
                const SizedBox(height: 4),
                Text(
                  '${formatEsShortDateTime(order.createdAt)} · ${order.cantidad} uds',
                  style: TextStyle(fontSize: 11.5, color: theme.textSecondary),
                ),
                Text(
                  _amountLine(bs: bs, rate: rate),
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: theme.textPrimary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );

    Widget softBadge(String label, {bool accent = false}) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: accent ? theme.brandContainer : theme.surfaceSubtle,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.borderSubtle),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: accent ? theme.brand : theme.textPrimary,
          ),
        ),
      );
    }

    final statusWrap = Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        softBadge(
          TransactionRequestStatus.labelEs(order.status),
          accent: true,
        ),
        softBadge(docLabel),
        if (order.hasProveedorFactura)
          softBadge('Factura importador', accent: true),
        if (_pagoLabel != null)
          softBadge(
            _pagoLabel!,
            accent: order.pagoEstadoRevision?.trim() ==
                PagoRevisionEstado.aprobado,
          ),
        if (metodoLabel != null) softBadge(metodoLabel),
        if (hasRating)
          Text(
            '★ $stars/5',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: theme.brand,
            ),
          ),
        if (comment.isNotEmpty)
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(
              '“$comment”',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: theme.textSecondary,
              ),
            ),
          ),
      ],
    );

    final menu = PopupMenuButton<_RowAction>(
      tooltip: 'Acciones',
      offset: const Offset(0, 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.borderStrong),
      ),
      color: theme.dialogSurface,
      onSelected: (a) {
        switch (a) {
          case _RowAction.view:
            onView();
          case _RowAction.copyId:
            onCopyId();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: _RowAction.view,
          child: _MenuTile(
            theme: theme,
            glyph: LucideGlyph.fileText,
            title: 'Ver detalle del pedido',
            subtitle: 'Abrir ficha operativa',
          ),
        ),
        PopupMenuItem(
          value: _RowAction.copyId,
          child: _MenuTile(
            theme: theme,
            glyph: LucideGlyph.copy,
            title: 'Copiar ID',
            subtitle: 'Identificador interno',
          ),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: LucideIcon(
          LucideGlyph.slidersHorizontal,
          size: 18,
          color: theme.textSecondary,
        ),
      ),
    );

    final bg = zebra ? theme.tableRowOdd : theme.tableRowEven;

    if (compact) {
      return ColoredBox(
        color: bg,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 12, 4, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    productCell,
                    const SizedBox(height: 8),
                    statusWrap,
                  ],
                ),
              ),
              menu,
            ],
          ),
        ),
      );
    }

    return ColoredBox(
      color: bg,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          children: [
            Expanded(flex: 4, child: productCell),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formatEsShortDateTime(order.createdAt),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: theme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${order.cantidad} uds',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: theme.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                _amountLine(bs: bs, rate: rate),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: theme.textPrimary,
                  height: 1.35,
                ),
              ),
            ),
            Expanded(flex: 2, child: statusWrap),
            SizedBox(width: 48, child: menu),
          ],
        ),
      ),
    );
  }

  String _amountLine({required double? bs, required double? rate}) {
    final ref =
        '${order.precioTotal.toStringAsFixed(2)} REF / USD';
    if (bs != null) {
      final rateLabel =
          rate == null ? '' : ' · BCV ${rate.toStringAsFixed(2)}';
      return '$ref\n${formatVesAmount(bs)}$rateLabel';
    }
    return ref;
  }
}

enum _RowAction { view, copyId }

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.theme,
    required this.glyph,
    required this.title,
    required this.subtitle,
  });

  final B2BThemeExtension theme;
  final LucideGlyph glyph;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        LucideIcon(glyph, size: 18, color: theme.textSecondary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: theme.textPrimary,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(fontSize: 11.5, color: theme.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({
    required this.theme,
    required this.message,
    this.onRetry,
  });

  final B2BThemeExtension theme;
  final String message;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.brandContainer,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.borderSubtle),
      ),
      child: Row(
        children: [
          LucideIcon(
            LucideGlyph.circleAlert,
            size: 18,
            color: theme.brand,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 13, color: theme.textPrimary),
            ),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: () => onRetry?.call(),
              child: const Text('Reintentar'),
            ),
        ],
      ),
    );
  }
}
