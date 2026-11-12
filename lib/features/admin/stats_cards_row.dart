import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/app_dark_tokens.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'package:motolink_pro_app/core/utils/ves_amount_format.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';
import 'package:motolink_pro_app/features/admin/admin_dashboard_stats.dart';
import 'package:motolink_pro_app/features/admin/admin_users_chrome.dart';

/// Fila superior de métricas clave del dashboard admin.
class StatsCardsRow extends StatelessWidget {
  const StatsCardsRow({
    super.key,
    required this.stats,
    this.padding = const EdgeInsets.fromLTRB(0, 0, 0, 16),
  });

  final AdminDashboardStats stats;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: stats,
      builder: (context, _) {
        final s = stats.snapshot;
        return Padding(
          padding: padding,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              // Desktop: 4 en fila; <1100 (tablet/móvil): grid 2×2 compacto.
              final cols = w > 1100 ? 4 : 2;
              const gap = 12.0;

              final theme = B2BThemeExtension.of(context);
              final dark = AppColors.isDarkOf(context);
              final cards = [
                AdminStatCard(
                  label: 'Usuarios / talleres activos',
                  value: _formatInt(s.activeUsers),
                  icon: LucideGlyph.users,
                  iconBg: theme.brandContainer,
                  iconFg: theme.brand,
                  deltaPct: s.activeUsersDeltaPct,
                  loading: stats.loading && s.activeUsers == 0,
                ),
                AdminStatCard(
                  label: 'Pedidos activos',
                  value: _formatInt(s.activeOrders),
                  icon: LucideGlyph.package,
                  iconBg: dark
                      ? const Color(0x264F46E5)
                      : const Color(0xFFEEF2FF),
                  iconFg: dark
                      ? const Color(0xFFA5B4FC)
                      : const Color(0xFF4F46E5),
                  deltaPct: s.activeOrdersDeltaPct,
                  loading: stats.loading && s.activeOrders == 0,
                ),
                AdminStatCard(
                  label: 'Ingresos totales',
                  value: '${_formatMoney(s.revenueUsd)} USD',
                  subtitle: s.revenueBs != null
                      ? formatBsLabel(s.revenueBs!, fractionDigits: 2)
                      : 'BCV —',
                  icon: LucideGlyph.dollarSign,
                  iconBg: theme.successBg,
                  iconFg: theme.successFg,
                  deltaPct: s.revenueDeltaPct,
                  loading: stats.loading && s.revenueUsd == 0,
                ),
                AdminStatCard(
                  label: 'Tasa de conversión / cierre',
                  value: '${_formatPct(s.conversionPct)}%',
                  icon: LucideGlyph.trendingUp,
                  iconBg: dark
                      ? AppDarkTokens.warningPill
                      : const Color(0xFFFFFBEB),
                  iconFg: dark
                      ? AppDarkTokens.warningFg
                      : const Color(0xFFD97706),
                  deltaPct: s.conversionDeltaPct,
                  loading: stats.loading && s.conversionPct == 0,
                ),
              ];

              if (cols == 4) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < cards.length; i++) ...[
                      if (i > 0) const SizedBox(width: gap),
                      Expanded(
                        child: KeyedSubtree(
                          key: ValueKey<String>('admin-stat-card-slot-$i'),
                          child: cards[i],
                        ),
                      ),
                    ],
                  ],
                );
              }

              final cardW = (w - gap * (cols - 1)) / cols;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (var i = 0; i < cards.length; i++)
                    SizedBox(
                      key: ValueKey<String>('admin-stat-card-slot-$i'),
                      width: cardW,
                      child: AspectRatio(
                        aspectRatio: w < 640 ? 1.35 : 1.55,
                        child: cards[i],
                      ),
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  static String _formatInt(int value) {
    final negative = value < 0;
    final digits = value.abs().toString();
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      final fromEnd = digits.length - i;
      if (i > 0 && fromEnd % 3 == 0) buf.write('.');
      buf.write(digits[i]);
    }
    return negative ? '-$buf' : buf.toString();
  }

  static String _formatMoney(double value) {
    return formatVesAmount(value, fractionDigits: 2);
  }

  static String _formatPct(double value) {
    return formatVesAmount(value, fractionDigits: 1);
  }
}

/// Tarjeta individual de métrica del dashboard.
class AdminStatCard extends StatelessWidget {
  const AdminStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.iconBg,
    required this.iconFg,
    required this.deltaPct,
    this.subtitle,
    this.loading = false,
  });

  final String label;
  final String value;
  final String? subtitle;
  final LucideGlyph icon;
  final Color iconBg;
  final Color iconFg;
  final double deltaPct;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final dark = AppColors.isDarkOf(context);
    final labelColor = AdminUsersChrome.muted;
    final valueColor = AdminUsersChrome.titleColor;
    final up = deltaPct >= 0;
    final deltaColor = up
        ? theme.successFg
        : (dark ? AppDarkTokens.dangerFg : const Color(0xFFEF4444));
    final deltaLabel =
        '${up ? '+' : ''}${formatVesAmount(deltaPct, fractionDigits: 1)}%';

    return Container(
      constraints: const BoxConstraints(minHeight: 112),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: AdminUsersChrome.card(),
      child: LayoutBuilder(
        builder: (context, c) {
          final compact = c.maxWidth < 220 ||
              (c.hasBoundedHeight && c.maxHeight < 140);
          final boundedH = c.hasBoundedHeight && c.maxHeight.isFinite;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: boundedH ? MainAxisSize.max : MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: compact ? 11 : 12,
                        fontWeight: FontWeight.w500,
                        color: labelColor,
                        height: 1.25,
                      ),
                    ),
                  ),
                  Container(
                    width: compact ? 30 : 36,
                    height: compact ? 30 : 36,
                    decoration: BoxDecoration(
                      color: iconBg,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: LucideIcon(
                      icon,
                      size: compact ? 16 : 20,
                      color: iconFg,
                    ),
                  ),
                ],
              ),
              if (boundedH)
                const Spacer()
              else
                const SizedBox(height: 12),
              if (loading)
                const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                )
              else
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: compact ? 20 : 24,
                    fontWeight: FontWeight.w800,
                    color: valueColor,
                    height: 1.15,
                    letterSpacing: -0.3,
                  ),
                ),
              if (subtitle != null && !loading) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: labelColor,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: deltaColor.withOpacity(dark ? 0.18 : 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LucideIcon(
                      up ? LucideGlyph.trendingUp : LucideGlyph.trendingDown,
                      size: 12,
                      color: deltaColor,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      deltaLabel,
                      style: TextStyle(
                        fontSize: compact ? 11 : 12,
                        fontWeight: FontWeight.w700,
                        color: deltaColor,
                      ),
                    ),
                    if (!compact) ...[
                      const SizedBox(width: 4),
                      Text(
                        'vs. mes ant.',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: labelColor.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
