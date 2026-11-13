import 'dart:async';

import 'package:flutter/material.dart';

import 'package:motolink_pro_app/features/admin/admin_dashboard_stats.dart';
import 'package:motolink_pro_app/features/admin/admin_entrepreneur_alerts_card.dart';
import 'package:motolink_pro_app/features/admin/admin_recent_activity.dart';
import 'package:motolink_pro_app/features/admin/admin_revenue_over_time.dart';
import 'package:motolink_pro_app/features/admin/admin_top_products_week.dart';
import 'package:motolink_pro_app/features/admin/quick_actions_card.dart';
import 'package:motolink_pro_app/features/admin/recent_activity_feed.dart';
import 'package:motolink_pro_app/features/admin/revenue_over_time_chart.dart';
import 'package:motolink_pro_app/features/admin/stats_cards_row.dart';
import 'package:motolink_pro_app/features/admin/top_products_table.dart';

/// Vista principal «Inicio» del panel admin: métricas, ingresos y actividad.
class AdminDashboardPanel extends StatefulWidget {
  const AdminDashboardPanel({
    super.key,
    this.allowAdminRole = false,
  });

  /// Alta de otra cuenta admin (solo propietario).
  final bool allowAdminRole;

  @override
  State<AdminDashboardPanel> createState() => _AdminDashboardPanelState();
}

class _AdminDashboardPanelState extends State<AdminDashboardPanel> {
  late final AdminDashboardStats _stats;
  late final AdminRevenueOverTime _revenue;
  late final AdminRecentActivity _activity;
  late final AdminTopProductsWeek _topProducts;

  @override
  void initState() {
    super.initState();
    _stats = AdminDashboardStats();
    _revenue = AdminRevenueOverTime();
    _activity = AdminRecentActivity();
    _topProducts = AdminTopProductsWeek();
    unawaited(_stats.start());
    unawaited(_revenue.start());
    unawaited(_activity.start());
    unawaited(_topProducts.start());
  }

  @override
  void dispose() {
    _stats.dispose();
    _revenue.dispose();
    _activity.dispose();
    _topProducts.dispose();
    super.dispose();
  }

  Future<void> _refreshAll() async {
    await Future.wait([
      _stats.refresh(),
      _revenue.refresh(),
      _activity.refresh(),
      _topProducts.refresh(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refreshAll,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth > 1024;
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  StatsCardsRow(stats: _stats),
                  const AdminEntrepreneurAlertsCard(),
                  QuickActionsCard(allowAdminRole: widget.allowAdminRole),
                  const SizedBox(height: 16),
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: SizedBox(
                            height: RecentActivityFeed.preferredHeight,
                            child: RevenueOverTimeChart(
                              series: _revenue,
                              fillHeight: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 1,
                          child: SizedBox(
                            height: RecentActivityFeed.preferredHeight,
                            child: RecentActivityFeed(activity: _activity),
                          ),
                        ),
                      ],
                    )
                  else ...[
                    RevenueOverTimeChart(series: _revenue),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: RecentActivityFeed.preferredHeight,
                      width: double.infinity,
                      child: RecentActivityFeed(activity: _activity),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TopProductsTable(controller: _topProducts),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
