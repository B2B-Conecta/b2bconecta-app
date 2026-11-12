import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/main_shell_tab.dart';
import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';
import 'package:motolink_pro_app/features/admin/admin_reports_hub_section.dart';
import 'package:motolink_pro_app/features/admin/admin_users_chrome.dart';
import 'package:motolink_pro_app/features/admin/admin_users_hub_section.dart';
import 'package:motolink_pro_app/features/admin/add_user_modal.dart';

/// Alias semántico del bloque de accesos operativos del dashboard.
typedef QuickActionsWidget = QuickActionsCard;

/// Accesos directos operativos del dashboard admin (barra full-width).
class QuickActionsCard extends StatelessWidget {
  const QuickActionsCard({
    super.key,
    this.allowAdminRole = false,
    this.onInviteTaller,
    this.onReviewOrders,
    this.onOpenReports,
    this.onOpenSettings,
  });

  final bool allowAdminRole;

  /// Overrides (tests / demos).
  final VoidCallback? onInviteTaller;
  final VoidCallback? onReviewOrders;
  final VoidCallback? onOpenReports;
  final VoidCallback? onOpenSettings;

  Future<void> _invite(BuildContext context) async {
    if (onInviteTaller != null) {
      onInviteTaller!();
      return;
    }
    MainShellTabController.navigateToAdminUsers(
      section: AdminUsersHubSection.cuentas,
    );
    await AddUserModal.open(
      context,
      allowAdminRole: allowAdminRole,
    );
  }

  void _reviewOrders() {
    if (onReviewOrders != null) {
      onReviewOrders!();
      return;
    }
    MainShellTabController.navigateToAdminActivosForNotification();
  }

  void _openReports() {
    if (onOpenReports != null) {
      onOpenReports!();
      return;
    }
    MainShellTabController.navigateToAdminReportes(
      section: AdminReportsHubSection.encomiendas,
    );
  }

  void _openSettings() {
    if (onOpenSettings != null) {
      onOpenSettings!();
      return;
    }
    MainShellTabController.navigateToAdminProfileTab();
  }

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final actions = [
      _QuickAction(
        label: 'Invitar / Nuevo Taller',
        hint: 'Cuentas',
        icon: LucideGlyph.userPlus,
        bg: theme.brandContainer,
        fg: theme.brand,
        onTap: () => _invite(context),
      ),
      _QuickAction(
        label: 'Revisar Pedidos',
        hint: 'Operaciones',
        icon: LucideGlyph.packageCheck,
        bg: theme.successBg,
        fg: theme.successFg,
        onTap: _reviewOrders,
      ),
      _QuickAction(
        label: 'Ver Reportes',
        hint: 'Encomiendas',
        icon: LucideGlyph.barChart3,
        bg: theme.surfaceSubtle,
        fg: theme.brand,
        onTap: _openReports,
      ),
      _QuickAction(
        label: 'Ajustes del Sistema',
        hint: 'Perfil',
        icon: LucideGlyph.settings,
        bg: theme.inputFill,
        fg: theme.textSecondary,
        onTap: _openSettings,
      ),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: AdminUsersChrome.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Accesos Directos Operativos',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: theme.textPrimary,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Atajos a las operaciones más frecuentes del panel.',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: theme.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              const gap = 10.0;
              final wide = constraints.maxWidth >= 900;
              // Móvil/tablet: grid 2×2 compacto (icono arriba, título abajo).
              final cols = wide ? 4 : 2;
              final compactTiles = !wide;
              final tileW = (constraints.maxWidth - gap * (cols - 1)) / cols;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final action in actions)
                    SizedBox(
                      width: tileW,
                      child: _QuickActionTile(
                        action: action,
                        compact: compactTiles,
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _QuickAction {
  const _QuickAction({
    required this.label,
    required this.hint,
    required this.icon,
    required this.bg,
    required this.fg,
    required this.onTap,
  });

  final String label;
  final String hint;
  final LucideGlyph icon;
  final Color bg;
  final Color fg;
  final VoidCallback onTap;
}

class _QuickActionTile extends StatefulWidget {
  const _QuickActionTile({required this.action, this.compact = false});

  final _QuickAction action;
  final bool compact;

  @override
  State<_QuickActionTile> createState() => _QuickActionTileState();
}

class _QuickActionTileState extends State<_QuickActionTile> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final a = widget.action;
    final scale = _pressed ? 0.98 : (_hovered ? 1.015 : 1.0);
    final compact = widget.compact;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
      }),
      child: AnimatedScale(
        scale: scale,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        child: Material(
          color: theme.surfaceCard,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: a.onTap,
            onHighlightChanged: (v) => setState(() => _pressed = v),
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              constraints: BoxConstraints(minHeight: compact ? 88 : 72),
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 10 : 14,
                vertical: compact ? 12 : 12,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _hovered || _pressed
                      ? a.fg.withOpacity(0.45)
                      : theme.borderSubtle,
                ),
              ),
              child: compact
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: a.bg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: LucideIcon(a.icon, size: 20, color: a.fg),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          a.label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: theme.textPrimary,
                            height: 1.2,
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: a.bg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: LucideIcon(a.icon, size: 22, color: a.fg),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                a.label,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: theme.textPrimary,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                a.hint,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: theme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        LucideIcon(
                          LucideGlyph.chevronRight,
                          size: 16,
                          color: theme.textMuted,
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
