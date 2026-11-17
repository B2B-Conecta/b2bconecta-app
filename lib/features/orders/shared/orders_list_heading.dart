import 'package:flutter/material.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/layout/app_breakpoints.dart';
import 'package:motolink_pro_app/core/layout/scroll_compact_layout.dart';

/// A quiet, consistent entry point for the three order workspaces.
class OrdersListHeading extends StatelessWidget {
  const OrdersListHeading(
      {super.key,
      required this.count,
      this.description = '',
      this.mobileTitle});
  final int count;
  final String description;
  final String? mobileTitle;

  @override
  Widget build(BuildContext context) {
    final compact = ScrollCompactState.of(context);
    final progress = ScrollCompactState.progressOf(context);
    final useScrollFade = mobileTitle != null &&
        progress != null &&
        MediaQuery.sizeOf(context).width < AppBreakpoints.b2bDesktop;
    if (!useScrollFade && ScrollCompactState.hideHeadingOf(context)) {
      return const SizedBox.shrink();
    }
    final countLabel = Text('$count ${count == 1 ? 'pedido' : 'pedidos'}',
        style: TextStyle(fontSize: 13, color: AppColors.textSecondary));
    // The desktop shell already provides the page title.
    if (MediaQuery.sizeOf(context).width >= AppBreakpoints.b2bDesktop) {
      return Padding(
          padding: const EdgeInsets.only(bottom: 8), child: countLabel);
    }
    if (mobileTitle case final title?) {
      final heading = Padding(
        padding: const EdgeInsets.only(top: 2, bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700, letterSpacing: -0.5)),
            ),
            const SizedBox(height: 2),
            countLabel,
          ],
        ),
      );
      if (progress == null) return heading;
      return ValueListenableBuilder<double>(
        valueListenable: progress,
        child: heading,
        builder: (context, value, child) =>
            ScrollFadeHeading(progress: value, child: child),
      );
    }
    return Padding(
      padding: EdgeInsets.fromLTRB(0, compact ? 2 : 14, 0, compact ? 6 : 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Expanded(
              child: Text('Pedidos',
                  style: TextStyle(
                      fontSize: compact ? 20 : 24,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.5))),
          countLabel,
        ]),
        if (!compact && description.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(description,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        ],
      ]),
    );
  }
}
