import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/main_shell_tab.dart';
import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'package:motolink_pro_app/core/layout/app_breakpoints.dart';
import 'package:motolink_pro_app/core/layout/segmented_filter_bar.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';
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

  Future<void> _openSectionSheet(AdminReportsHubSection current) async {
    final theme = B2BThemeExtension.of(context);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: theme.dialogSurface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.borderSubtle,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Sección de Reportes',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: theme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                for (final s in AdminReportsHubSectionLabel.mobileSegments)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      s.labelEs,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: theme.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      s.hintEs,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.textSecondary,
                      ),
                    ),
                    trailing: s == current
                        ? LucideIcon(
                            LucideGlyph.check,
                            size: 18,
                            color: theme.brand,
                          )
                        : null,
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _selectSection(s);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final section = _activeSection;
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= AppBreakpoints.adminDesktop;
    final mobile = width < AppBreakpoints.mobileMenu;
    final showSegments = !wide && !mobile;
    final theme = B2BThemeExtension.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (mobile)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => _openSectionSheet(section),
                icon: LucideIcon(
                  LucideGlyph.layoutGrid,
                  size: 16,
                  color: theme.brand,
                ),
                label: Text(
                  section.labelEs,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: theme.brand,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.brand,
                  side: BorderSide(color: theme.borderSubtle),
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
              ),
            ),
          )
        else if (showSegments)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SegmentedFilterBar(
              labels: [
                for (final s in AdminReportsHubSectionLabel.mobileSegments)
                  s.labelEs,
              ],
              selectedIndex: () {
                const mobileSegs = AdminReportsHubSectionLabel.mobileSegments;
                final i = mobileSegs.indexOf(section);
                return i < 0 ? 0 : i;
              }(),
              onSelected: (i) => _selectSection(
                AdminReportsHubSectionLabel.mobileSegments[i],
              ),
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
