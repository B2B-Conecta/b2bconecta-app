import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/main_shell_tab.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
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
  final Set<AdminUsersHubSection> _visited = {
    AdminUsersHubSection.verificacion,
  };
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

  void _selectSection(AdminUsersHubSection section) {
    setState(() {
      _section = section;
      _visited.add(section);
    });
  }

  void _onPresenceRequest() {
    if (!mounted) return;
    setState(() {
      _section = AdminUsersHubSection.actividad;
      _visited.add(AdminUsersHubSection.actividad);
      _presenceTick = MainShellTabController.adminPresenceRequest.value;
    });
  }

  void _applyDeepLink() {
    final section = MainShellTabController.consumePendingAdminUsersSection();
    if (section != null && mounted) {
      _selectSection(section);
    } else if (MainShellTabController.peekPendingKycProfileId() != null &&
        mounted) {
      _selectSection(AdminUsersHubSection.verificacion);
    } else if (MainShellTabController.peekPendingAccountProfileId() != null &&
        mounted) {
      _selectSection(AdminUsersHubSection.cuentas);
    }
  }

  String get _sectionHint => switch (_section) {
        AdminUsersHubSection.verificacion =>
          'KYC, documentos y habilitación de acceso.',
        AdminUsersHubSection.cuentas =>
          'Datos fiscales, corrección de rol, alta y baja.',
        AdminUsersHubSection.actividad =>
          'Presencia e ingresos recientes a la plataforma.',
      };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedFilterBar(
                labels: [
                  for (final s in AdminUsersHubSection.values) s.labelEs,
                ],
                selectedIndex: AdminUsersHubSection.values.indexOf(_section),
                onSelected: (i) =>
                    _selectSection(AdminUsersHubSection.values[i]),
              ),
              Text(
                _sectionHint,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.35,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: AdminUsersHubSection.values.indexOf(_section),
            children: [
              for (final section in AdminUsersHubSection.values)
                if (_visited.contains(section))
                  switch (section) {
                    AdminUsersHubSection.verificacion => AdminKycReviewPanel(
                        viewerId: widget.viewer.id,
                        viewerRole: widget.viewer.role,
                        viewerIsOwner: widget.viewer.isOwner,
                        embeddedInHub: true,
                      ),
                    AdminUsersHubSection.cuentas => AdminAccountManagementPanel(
                        viewer: widget.viewer,
                        embeddedInHub: true,
                      ),
                    AdminUsersHubSection.actividad => AdminUserMonitoringPanel(
                        presenceRequest: _presenceTick,
                      ),
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
