import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/main_shell_tab.dart';
import 'package:motolink_pro_app/core/layout/segmented_filter_bar.dart';
import 'package:motolink_pro_app/features/admin/admin_account_management_panel.dart';
import 'package:motolink_pro_app/features/admin/admin_user_monitoring_panel.dart';
import 'package:motolink_pro_app/features/admin/admin_users_hub_section.dart';
import 'package:motolink_pro_app/features/kyc/admin_kyc_review_panel.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';

/// Hub unificado: Verificación + Cuentas + Actividad (ex Reportes › Usuarios).
class AdminUsersHubPanel extends StatefulWidget {
  const AdminUsersHubPanel({
    super.key,
    required this.viewer,
  });

  final ProfileModel viewer;

  @override
  State<AdminUsersHubPanel> createState() => _AdminUsersHubPanelState();
}

class _AdminUsersHubPanelState extends State<AdminUsersHubPanel> {
  AdminUsersHubSection _section = AdminUsersHubSection.verificacion;
  int _presenceTick = 0;

  @override
  void initState() {
    super.initState();
    MainShellTabController.registerAdminUsersHubDeepLink(_applyDeepLink);
    MainShellTabController.adminPresenceRequest.addListener(_onPresenceRequest);
    _applyDeepLink();
  }

  @override
  void dispose() {
    MainShellTabController.adminPresenceRequest.removeListener(_onPresenceRequest);
    MainShellTabController.registerAdminUsersHubDeepLink(null);
    super.dispose();
  }

  void _onPresenceRequest() {
    if (!mounted) return;
    setState(() {
      _section = AdminUsersHubSection.actividad;
      _presenceTick = MainShellTabController.adminPresenceRequest.value;
    });
  }

  void _applyDeepLink() {
    final section = MainShellTabController.consumePendingAdminUsersSection();
    if (section != null && mounted) {
      setState(() => _section = section);
    } else if (MainShellTabController.peekPendingKycProfileId() != null &&
        mounted) {
      setState(() => _section = AdminUsersHubSection.verificacion);
    } else if (MainShellTabController.peekPendingAccountProfileId() != null &&
        mounted) {
      setState(() => _section = AdminUsersHubSection.cuentas);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: SegmentedFilterBar(
            labels: [
              for (final s in AdminUsersHubSection.values) s.labelEs,
            ],
            selectedIndex: AdminUsersHubSection.values.indexOf(_section),
            onSelected: (i) => setState(
              () => _section = AdminUsersHubSection.values[i],
            ),
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: AdminUsersHubSection.values.indexOf(_section),
            children: [
              AdminKycReviewPanel(
                viewerId: widget.viewer.id,
                viewerRole: widget.viewer.role,
                viewerIsOwner: widget.viewer.isOwner,
                embeddedInHub: true,
              ),
              AdminAccountManagementPanel(
                viewer: widget.viewer,
                embeddedInHub: true,
              ),
              AdminUserMonitoringPanel(
                presenceRequest: _presenceTick,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
