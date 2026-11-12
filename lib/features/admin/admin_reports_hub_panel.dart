import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/main_shell_tab.dart';
import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'package:motolink_pro_app/core/layout/app_breakpoints.dart';
import 'package:motolink_pro_app/core/layout/segmented_filter_bar.dart';
import 'package:motolink_pro_app/features/admin/admin_encomiendas_report_panel.dart';
import 'package:motolink_pro_app/features/admin/admin_promo_campaigns_panel.dart';
import 'package:motolink_pro_app/features/admin/admin_reports_hub_section.dart';
import 'package:motolink_pro_app/features/admin/admin_returns_report_panel.dart';
import 'package:motolink_pro_app/features/referrals/admin_referrals_panel.dart';

/// Hub Reportes: Encomiendas · Promos · Referidos · Devoluciones.
class AdminReportsHubPanel extends StatefulWidget {
  const AdminReportsHubPanel({
    super.key,
    this.section,
    this.onSectionChanged,
  });

  final AdminReportsHubSection? section;
  final ValueChanged<AdminReportsHubSection>? onSectionChanged;

  @override
  State<AdminReportsHubPanel> createState() => _AdminReportsHubPanelState();
}

class _AdminReportsHubPanelState extends State<AdminReportsHubPanel> {
  late AdminReportsHubSection _section;
  final Set<AdminReportsHubSection> _visited = {
    AdminReportsHubSection.encomiendas,
  };

  bool get _controlled => widget.section != null;

  @override
  void initState() {
    super.initState();
    _section = widget.section ?? AdminReportsHubSection.encomiendas;
    _visited.add(_section);
    MainShellTabController.registerAdminReportsHubDeepLink(_applyDeepLink);
  }

  @override
  void dispose() {
    MainShellTabController.registerAdminReportsHubDeepLink(null);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant AdminReportsHubPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final external = widget.section;
    if (external != null && external != _section) {
      _section = external;
      _visited.add(external);
    }
  }

  void _applyDeepLink() {
    final section = MainShellTabController.consumePendingAdminReportsSection();
    if (section != null && mounted) {
      _selectSection(section);
    }
  }

  void _selectSection(AdminReportsHubSection section) {
    if (_controlled) {
      widget.onSectionChanged?.call(section);
      setState(() => _visited.add(section));
      return;
    }
    setState(() {
      _section = section;
      _visited.add(section);
    });
    widget.onSectionChanged?.call(section);
  }

  AdminReportsHubSection get _activeSection => widget.section ?? _section;

  @override
  Widget build(BuildContext context) {
    final section = _activeSection;
    final wide =
        MediaQuery.sizeOf(context).width >= AppBreakpoints.adminDesktop;
    final showSegments = !wide;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showSegments)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedFilterBar(
                  labels: [
                    for (final s in AdminReportsHubSectionLabel.mobileSegments)
                      s.labelEs,
                  ],
                  selectedIndex: () {
                    const mobile = AdminReportsHubSectionLabel.mobileSegments;
                    final i = mobile.indexOf(section);
                    return i < 0 ? 0 : i;
                  }(),
                  onSelected: (i) => _selectSection(
                    AdminReportsHubSectionLabel.mobileSegments[i],
                  ),
                ),
                Text(
                  section.hintEs,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.35,
                    color: B2BThemeExtension.of(context).textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        Expanded(
          child: IndexedStack(
            index: AdminReportsHubSection.values.indexOf(section),
            children: [
              for (final s in AdminReportsHubSection.values)
                if (_visited.contains(s))
                  switch (s) {
                    AdminReportsHubSection.encomiendas =>
                      const AdminEncomiendasReportPanel(embeddedInHub: true),
                    AdminReportsHubSection.promos =>
                      const AdminPromoCampaignsPanel(),
                    AdminReportsHubSection.referidos =>
                      const AdminReferralsPanel(),
                    AdminReportsHubSection.devoluciones =>
                      const AdminReturnsReportPanel(),
                  }
                else
                  const SizedBox.shrink(),
            ],
          ),
        ),
      ],
    );
  }
}
