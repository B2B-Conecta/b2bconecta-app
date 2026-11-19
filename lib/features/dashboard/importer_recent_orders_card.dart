import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/main_shell_tab.dart';
import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'package:motolink_pro_app/core/layout/app_breakpoints.dart';
import 'package:motolink_pro_app/core/utils/ves_amount_format.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';
import 'package:motolink_pro_app/features/orders/shared/orders_service.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_model.dart';

/// Últimos pedidos del importador (máximo 5) para operar desde Inicio.
class ImporterRecentOrdersCard extends StatefulWidget {
  const ImporterRecentOrdersCard({super.key, this.reloadToken = 0});

  final int reloadToken;

  @override
  State<ImporterRecentOrdersCard> createState() =>
      _ImporterRecentOrdersCardState();
}

class _ImporterRecentOrdersCardState extends State<ImporterRecentOrdersCard> {
  late Future<List<TransactionRequestModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant ImporterRecentOrdersCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reloadToken != widget.reloadToken) {
      _future = _load();
    }
  }

  Future<List<TransactionRequestModel>> _load() async {
    try {
      final rows =
          await OrdersService.fetchUnifiedTransactionRequestsForImporter();
      if (rows.length <= 5) return rows;
      return rows.sublist(0, 5);
    } catch (_) {
      return const [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final mobile = MediaQuery.sizeOf(context).width < AppBreakpoints.mobileMenu;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            mobile
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Actividad reciente',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: theme.textPrimary,
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 36),
                          ),
                          onPressed:
                              MainShellTabController.navigateToPedidosTab,
                          child: const Text('Ver todos los pedidos'),
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Actividad reciente',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: theme.textPrimary,
                          ),
                        ),
                      ),
                      const TextButton(
                        onPressed: MainShellTabController.navigateToPedidosTab,
                        child: Text('Ver todos los pedidos'),
                      ),
                    ],
                  ),
            Text(
              'Últimos pedidos recibidos',
              style: TextStyle(fontSize: 12, color: theme.textSecondary),
            ),
            const SizedBox(height: 8),
            FutureBuilder<List<TransactionRequestModel>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    child: LinearProgressIndicator(
                      minHeight: 2,
                      color: theme.brand,
                      backgroundColor: theme.borderSubtle,
                    ),
                  );
                }
                final rows = snapshot.data ?? const [];
                if (rows.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'Aún no hay pedidos recientes.',
                      style:
                          TextStyle(fontSize: 12, color: theme.textSecondary),
                    ),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < rows.length; i++)
                      _RecentOrderRow(
                        order: rows[i],
                        zebra: i.isOdd,
                        stacked: mobile,
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentOrderRow extends StatelessWidget {
  const _RecentOrderRow({
    required this.order,
    required this.zebra,
    required this.stacked,
  });

  final TransactionRequestModel order;
  final bool zebra;
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final buyer = (order.aliadoBusinessName ?? '').trim().isEmpty
        ? 'Tienda'
        : order.aliadoBusinessName!.trim();
    final amount = order.totalRef ?? order.precioTotal;
    final status = order.statusLabelEs();
    final amountLabel = 'USD ${formatRefAmount(amount)}';
    return Material(
      color: zebra ? theme.tableRowOdd : theme.tableRowEven,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => MainShellTabController.openImporterOrder(order.id),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: stacked
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      buyer,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: theme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: _StatusChip(label: status),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          flex: 2,
                          child: Text(
                            amountLabel,
                            textAlign: TextAlign.end,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: theme.textPrimary,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Text(
                        buyer,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: theme.textPrimary,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: _StatusChip(label: status),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        amountLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: theme.textPrimary,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    LucideIcon(
                      LucideGlyph.chevronRight,
                      size: 16,
                      color: theme.textMuted,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: theme.brandContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: theme.brand,
        ),
      ),
    );
  }
}
