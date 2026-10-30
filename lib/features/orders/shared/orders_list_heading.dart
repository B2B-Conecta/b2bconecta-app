import 'package:flutter/material.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/layout/app_breakpoints.dart';

/// A quiet, consistent entry point for the three order workspaces.
class OrdersListHeading extends StatelessWidget {
  const OrdersListHeading(
      {super.key, required this.count, this.description = ''});
  final int count;
  final String description;

  @override
  Widget build(BuildContext context) {
    final countLabel = Text('$count ${count == 1 ? 'pedido' : 'pedidos'}',
        style: TextStyle(fontSize: 13, color: AppColors.textSecondary));
    // The desktop shell already provides the page title.
    if (MediaQuery.sizeOf(context).width >= AppBreakpoints.b2bDesktop) {
      return Padding(
          padding: const EdgeInsets.only(bottom: 8), child: countLabel);
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 14, 0, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Expanded(
              child: Text('Pedidos',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.5))),
          countLabel,
        ]),
        if (description.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(description,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        ],
      ]),
    );
  }
}
