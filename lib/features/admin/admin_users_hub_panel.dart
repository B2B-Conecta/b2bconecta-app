import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/main_shell_tab.dart';
import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'package:motolink_pro_app/core/layout/app_breakpoints.dart';
import 'package:motolink_pro_app/core/layout/segmented_filter_bar.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';
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

  Future<void> _openSectionSheet(AdminUsersHubSection current) async {
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
                  'Sección de Usuarios',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: theme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                for (final s in AdminUsersHubSectionLabel.mobileSegments)
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
                for (final s in AdminUsersHubSectionLabel.mobileSegments)
                  s.labelEs,
              ],
              selectedIndex: () {
                const mobileSegs = AdminUsersHubSectionLabel.mobileSegments;
                final i = mobileSegs.indexOf(section);
                return i < 0 ? 0 : i;
              }(),
              onSelected: (i) => _selectSection(
                AdminUsersHubSectionLabel.mobileSegments[i],
              ),
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
