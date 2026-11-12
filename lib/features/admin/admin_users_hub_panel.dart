import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/main_shell_tab.dart';
import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'package:motolink_pro_app/core/layout/app_breakpoints.dart';
import 'package:motolink_pro_app/core/layout/segmented_filter_bar.dart';
import 'package:motolink_pro_app/features/admin/admin_account_management_panel.dart';
import 'package:motolink_pro_app/features/admin/admin_catalog_seals_panel.dart';
import 'package:motolink_pro_app/features/admin/admin_users_activity_log_panel.dart';
import 'package:motolink_pro_app/features/admin/admin_users_hub_section.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';

/// Hub unificado: Cuentas + Actividad + Sellos y Vitrina.
class AdminUsersHubPanel extends StatefulWidget {
  const AdminUsersHubPanel({
    super.key,
    required this.viewer,
    this.section,
    this.onSectionChanged,
  });

  final ProfileModel viewer;

  /// Sección controlada (p. ej. desde el rail anidado de escritorio).
  final AdminUsersHubSection? section;
  final ValueChanged<AdminUsersHubSection>? onSectionChanged;

  @override
  State<AdminUsersHubPanel> createState() => _AdminUsersHubPanelState();
}

class _AdminUsersHubPanelState extends State<AdminUsersHubPanel> {
  late AdminUsersHubSection _section;
  final Set<AdminUsersHubSection> _visited = {
    AdminUsersHubSection.cuentas,
  };
  int _presenceTick = 0;

  bool get _controlled => widget.section != null;

  @override
  void initState() {
    super.initState();
    _section = widget.section ?? AdminUsersHubSection.cuentas;
    _visited.add(_section);
    MainShellTabController.registerAdminUsersHubDeepLink(_applyDeepLink);
    MainShellTabController.adminPresenceRequest.addListener(_onPresenceRequest);
    _applyDeepLink();
  }

  @override
  void didUpdateWidget(covariant AdminUsersHubPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final external = widget.section;
    if (external != null && external != _section) {
      _section = external;
      _visited.add(external);
    }
  }

  @override
  void dispose() {
    MainShellTabController.adminPresenceRequest.removeListener(_onPresenceRequest);
    MainShellTabController.registerAdminUsersHubDeepLink(null);
    super.dispose();
  }

  void _selectSection(AdminUsersHubSection section) {
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

  void _onPresenceRequest() {
    if (!mounted) return;
    _selectSection(AdminUsersHubSection.actividad);
    setState(() {
      _presenceTick = MainShellTabController.adminPresenceRequest.value;
    });
  }

  void _applyDeepLink() {
    final section = MainShellTabController.consumePendingAdminUsersSection();
    if (section != null && mounted) {
      _selectSection(section);
    } else if ((MainShellTabController.peekPendingAccountProfileId() != null ||
            MainShellTabController.peekPendingKycProfileId() != null) &&
        mounted) {
      _selectSection(AdminUsersHubSection.cuentas);
    }
  }

  AdminUsersHubSection get _activeSection => widget.section ?? _section;

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
                    for (final s in AdminUsersHubSectionLabel.mobileSegments)
                      s.labelEs,
                  ],
                  selectedIndex: () {
                    const mobile = AdminUsersHubSectionLabel.mobileSegments;
                    final i = mobile.indexOf(section);
                    return i < 0 ? 0 : i;
                  }(),
                  onSelected: (i) => _selectSection(
                    AdminUsersHubSectionLabel.mobileSegments[i],
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
            index: AdminUsersHubSection.values.indexOf(section),
            children: [
              for (final s in AdminUsersHubSection.values)
                if (_visited.contains(s))
                  switch (s) {
                    AdminUsersHubSection.cuentas => AdminAccountManagementPanel(
                        viewer: widget.viewer,
                        embeddedInHub: true,
                      ),
                    AdminUsersHubSection.actividad => AdminUsersActivityLogPanel(
                        presenceRequest: _presenceTick,
                      ),
                    AdminUsersHubSection.sellosYVitrina =>
                      const AdminCatalogSealsPanel(),
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
