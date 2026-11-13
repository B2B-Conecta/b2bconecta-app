import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';
import 'package:motolink_pro_app/features/onboarding/entrepreneur_first_purchase_warning_banner.dart';
import 'package:motolink_pro_app/features/onboarding/entrepreneur_retailer.dart';
import 'package:motolink_pro_app/features/onboarding/entrepreneur_status_modal.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';

/// Resumen compacto de plazos Minorista-Emprendedor en el rail corporativo.
class EntrepreneurRailStatusCard extends StatelessWidget {
  const EntrepreneurRailStatusCard({
    super.key,
    required this.profile,
    required this.extended,
    this.onOpenProfile,
  });

  final ProfileModel profile;
  final bool extended;
  final VoidCallback? onOpenProfile;

  Future<void> _open(BuildContext context) {
    return showEntrepreneurStatusModal(context: context, profile: profile);
  }

  @override
  Widget build(BuildContext context) {
    if (!profile.isEntrepreneurRetailer) return const SizedBox.shrink();
    final theme = B2BThemeExtension.of(context);
    final summary = _summaryFor(profile);
    if (summary == null) return const SizedBox.shrink();

    if (!extended) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        child: Tooltip(
          message: summary.tooltip,
          child: Material(
            color: theme.surfaceSubtle,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: theme.borderSubtle),
            ),
            child: InkWell(
              onTap: () => _open(context),
              borderRadius: BorderRadius.circular(12),
              hoverColor: theme.brand.withOpacity(0.08),
              mouseCursor: SystemMouseCursors.click,
              child: SizedBox(
                width: 48,
                height: 48,
                child: Icon(
                  summary.icon,
                  size: 20,
                  color: theme.brand,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Material(
        color: theme.surfaceSubtle,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: theme.borderSubtle),
        ),
        child: InkWell(
          onTap: () => _open(context),
          borderRadius: BorderRadius.circular(12),
          hoverColor: theme.brand.withOpacity(0.08),
          mouseCursor: SystemMouseCursors.click,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Icon(
                  summary.icon,
                  size: 18,
                  color: theme.brand,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        summary.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: theme.textPrimary,
                        ),
                      ),
                      if (summary.subtitle != null)
                        Text(
                          summary.subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
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
    );
  }

  /// Banner ancho para Inicio móvil (misma lógica que el rail).
  static Widget? homeBanner(ProfileModel profile) {
    if (!profile.isEntrepreneurRetailer) return null;
    final warning = EntrepreneurFirstPurchaseWarningBanner.maybe(profile);
    if (warning != null) return warning;
    final summary = _summaryFor(profile);
    if (summary == null) return null;
    return _EntrepreneurHomeBanner(profile: profile, summary: summary);
  }

  static _RailSummary? _summaryFor(ProfileModel profile) {
    final status = profile.entrepreneurStatus?.trim().toLowerCase();
    final now = DateTime.now();

    if (status == EntrepreneurStatus.expiredLocked) {
      return const _RailSummary(
        title: 'Periodo caducado',
        subtitle: 'Solicitar reactivación',
        tooltip:
            'Tu plazo de 8 semanas venció. Solicita reactivación o sube documentos.',
        icon: Icons.lock_outline,
      );
    }

    if (status == EntrepreneurStatus.reactivationRequested) {
      return const _RailSummary(
        title: 'Reactivación pedida',
        subtitle: 'Asesor en camino',
        tooltip:
            'Solicitud enviada. Puedes seguir cargando documentos en Perfil → KYC.',
        icon: Icons.support_agent_outlined,
      );
    }

    if (status == EntrepreneurStatus.verifiedStandard) {
      return const _RailSummary(
        title: 'Emprendedor verificado',
        subtitle: 'Cuenta estándar',
        tooltip: 'Completaste el flujo Minorista-Emprendedor.',
        icon: Icons.verified_outlined,
      );
    }

    if (EntrepreneurStatus.isFirstPurchaseWarning(status)) {
      final day = profile.entrepreneurFirstPurchaseDayOfEight;
      return _RailSummary(
        title: 'Quedan 3 días hábiles',
        subtitle: 'Día $day de 8 · primera compra',
        tooltip:
            'Te quedan 3 días hábiles para realizar tu primera compra. '
            'De lo contrario, tu cuenta será bloqueada temporalmente.',
        icon: Icons.warning_amber_rounded,
      );
    }

    if (status == EntrepreneurStatus.activeTrial) {
      final day = profile.entrepreneurFirstPurchaseDayOfEight;
      final purchase = profile.firstPurchaseDeadline;
      if (purchase != null) {
        final days = purchase.difference(now).inDays;
        return _RailSummary(
          title: 'Primera compra',
          subtitle: days <= 0
              ? 'Día $day de 8 · vence hoy'
              : 'Día $day de 8 · quedan ${days < 0 ? 0 : days} d',
          tooltip: 'Ventana de 8 días hábiles para tu primera compra',
          icon: Icons.shopping_bag_outlined,
        );
      }
      return _RailSummary(
        title: 'Primera compra',
        subtitle: 'Día $day de 8 hábiles',
        tooltip: 'Ventana de 8 días hábiles para tu primera compra',
        icon: Icons.shopping_bag_outlined,
      );
    }

    if (status == EntrepreneurStatus.kycInProgress) {
      final kyc = profile.kycCompletionDeadline;
      if (kyc != null) {
        final days = kyc.difference(now).inDays;
        return _RailSummary(
          title: 'Documentos comerciales',
          subtitle: days <= 0
              ? 'Vence hoy'
              : 'Quedan ${days < 0 ? 0 : days} días',
          tooltip: 'Sube los 4 documentos del expediente (8 semanas)',
          icon: Icons.folder_outlined,
        );
      }
      return const _RailSummary(
        title: 'Documentos comerciales',
        subtitle: '8 semanas',
        tooltip: 'Sube los 4 documentos del expediente (8 semanas)',
        icon: Icons.folder_outlined,
      );
    }

    final purchase = profile.firstPurchaseDeadline;
    if (purchase != null && purchase.isAfter(now)) {
      final days = purchase.difference(now).inDays;
      return _RailSummary(
        title: 'Primera compra',
        subtitle: days <= 0 ? 'Vence hoy' : 'Quedan $days días',
        tooltip: 'Ver plazos del programa Minorista-Emprendedor',
        icon: Icons.shopping_bag_outlined,
      );
    }

    final kyc = profile.kycCompletionDeadline;
    if (kyc != null && kyc.isAfter(now)) {
      final days = kyc.difference(now).inDays;
      return _RailSummary(
        title: 'Expediente KYC',
        subtitle: days <= 0 ? 'Vence hoy' : 'Quedan $days días',
        tooltip: 'Ver plazos del programa Minorista-Emprendedor',
        icon: Icons.folder_outlined,
      );
    }

    return const _RailSummary(
      title: 'Minorista-Emprendedor',
      subtitle: 'Ver plazos',
      tooltip: 'Ver plazos del programa Minorista-Emprendedor',
      icon: Icons.storefront_outlined,
    );
  }
}

class _RailSummary {
  const _RailSummary({
    required this.title,
    required this.subtitle,
    required this.tooltip,
    required this.icon,
  });

  final String title;
  final String? subtitle;
  final String tooltip;
  final IconData icon;
}

class _EntrepreneurHomeBanner extends StatelessWidget {
  const _EntrepreneurHomeBanner({
    required this.profile,
    required this.summary,
  });

  final ProfileModel profile;
  final _RailSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    return Material(
      color: theme.brandContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: theme.brand.withOpacity(0.22)),
      ),
      child: InkWell(
        onTap: () =>
            showEntrepreneurStatusModal(context: context, profile: profile),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: theme.surfaceCard,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(summary.icon, size: 20, color: theme.brand),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      summary.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: theme.textPrimary,
                      ),
                    ),
                    if (summary.subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        summary.subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: theme.brand,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              LucideIcon(
                LucideGlyph.chevronRight,
                size: 18,
                color: theme.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
