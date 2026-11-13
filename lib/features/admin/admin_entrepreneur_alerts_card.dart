import 'dart:async';

import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/main_shell_tab.dart';
import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'package:motolink_pro_app/core/layout/app_breakpoints.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';
import 'package:motolink_pro_app/features/admin/admin_users_hub_section.dart';
import 'package:motolink_pro_app/features/onboarding/entrepreneur_retailer.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';

/// Atajos gerenciales: sin compra / KYC caducado / reactivación.
class AdminEntrepreneurAlertsCard extends StatefulWidget {
  const AdminEntrepreneurAlertsCard({super.key});

  @override
  State<AdminEntrepreneurAlertsCard> createState() =>
      _AdminEntrepreneurAlertsCardState();
}

class _AdminEntrepreneurAlertsCardState
    extends State<AdminEntrepreneurAlertsCard> {
  List<ProfileModel> _rows = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await SupabaseService.adminListEntrepreneurAlerts();
      if (!mounted) return;
      setState(() {
        _rows = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _rows = const [];
        _loading = false;
      });
    }
  }

  int _count(String status) => _rows
      .where((p) => p.entrepreneurStatus?.trim().toLowerCase() == status)
      .length;

  void _open(String status) {
    // Legado + nuevo estado de advertencia comparten bandeja.
    final filter = status == EntrepreneurStatus.pendingWarningPeriod
        ? EntrepreneurStatus.pendingWarningPeriod
        : status;
    MainShellTabController.setPendingEntrepreneurAlertFilter(filter);
    MainShellTabController.navigateToAdminUsers(
      section: AdminUsersHubSection.cuentas,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final mobile =
        MediaQuery.sizeOf(context).width < AppBreakpoints.mobileMenu;
    final warning = _count(EntrepreneurStatus.pendingWarningPeriod) +
        _count(EntrepreneurStatus.pendingFirstPurchaseAlert);
    final caducado = _count(EntrepreneurStatus.expiredLocked);
    final reactivacion = _count(EntrepreneurStatus.reactivationRequested);
    final trialNear = _rows
        .where((p) =>
            p.entrepreneurStatus?.trim().toLowerCase() ==
                EntrepreneurStatus.activeTrial &&
            p.entrepreneurFirstPurchaseDayOfEight >= 4)
        .length;
    final total = warning + caducado + reactivacion + trialNear;

    final tiles = [
      _AlertTile(
        title: 'Cuenta regresiva (3 días)',
        count: warning,
        icon: LucideGlyph.triangleAlert,
        onTap: () => _open(EntrepreneurStatus.pendingWarningPeriod),
      ),
      _AlertTile(
        title: 'Plazo caducado / bloqueados',
        count: caducado,
        icon: LucideGlyph.shieldAlert,
        onTap: () => _open(EntrepreneurStatus.expiredLocked),
      ),
      _AlertTile(
        title: 'Solicitud de reactivación',
        count: reactivacion,
        icon: LucideGlyph.headset,
        onTap: () => _open(EntrepreneurStatus.reactivationRequested),
      ),
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: theme.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              LucideIcon(LucideGlyph.sparkles, size: 18, color: theme.warningFg),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Alertas Minorista-Emprendedor',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: theme.textPrimary,
                  ),
                ),
              ),
              if (_loading)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.brand,
                  ),
                )
              else
                Text(
                  '$total',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: theme.warningFg,
                  ),
                ),
              IconButton(
                tooltip: 'Actualizar',
                onPressed: _load,
                icon: LucideIcon(
                  LucideGlyph.refreshCw,
                  size: 16,
                  color: theme.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Atención comercial y cumplimiento documental.',
            style: TextStyle(
              fontSize: 12.5,
              color: theme.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          if (mobile)
            Column(
              children: [
                for (var i = 0; i < tiles.length; i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  tiles[i],
                ],
              ],
            )
          else
            Row(
              children: [
                for (var i = 0; i < tiles.length; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(child: tiles[i]),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _AlertTile extends StatelessWidget {
  const _AlertTile({
    required this.title,
    required this.count,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final int count;
  final LucideGlyph icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final hot = count > 0;
    return Material(
      color: hot ? theme.warningBg.withOpacity(0.65) : theme.surfaceSubtle,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: theme.surfaceCard,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: theme.borderSubtle),
                ),
                child: LucideIcon(
                  icon,
                  size: 18,
                  color: hot ? theme.warningFg : theme.textSecondary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: theme.textPrimary,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      count == 1 ? '1 cuenta' : '$count cuentas',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: hot ? theme.warningFg : theme.textMuted,
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
    );
  }
}
