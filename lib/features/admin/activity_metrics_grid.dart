import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'package:motolink_pro_app/core/utils/ves_amount_format.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';

/// Filtro activo de las métricas de Actividad › Presencia.
enum ActivityMetricFocus {
  none,
  users,
  withLogins,
  withOrders,
  withDelivered,
  withVolume,
  catalogs,
}

/// Grid decorativo e interactivo de KPIs (modelo dashboard).
class ActivityMetricsGrid extends StatefulWidget {
  const ActivityMetricsGrid({
    super.key,
    required this.users,
    required this.logins,
    required this.orders,
    required this.delivered,
    required this.volumeUsd,
    required this.periodLabel,
    required this.focus,
    required this.onFocusChanged,
    this.catalogsCount,
    this.catalogsLoading = false,
    this.showCatalogs = true,
  });

  final int users;
  final int logins;
  final int orders;
  final int delivered;
  final double volumeUsd;
  final String periodLabel;
  final ActivityMetricFocus focus;
  final ValueChanged<ActivityMetricFocus> onFocusChanged;
  final int? catalogsCount;
  final bool catalogsLoading;
  final bool showCatalogs;

  @override
  State<ActivityMetricsGrid> createState() => _ActivityMetricsGridState();
}

class _ActivityMetricsGridState extends State<ActivityMetricsGrid> {
  double? _bcvRate;

  @override
  void initState() {
    super.initState();
    _loadBcv();
  }

  Future<void> _loadBcv() async {
    try {
      final rate = await SupabaseService.fetchGlobalTasaBcv();
      if (!mounted) return;
      setState(() => _bcvRate = rate);
    } catch (_) {
      // Subtítulo BCV queda en «—».
    }
  }

  void _toggle(ActivityMetricFocus next) {
    widget.onFocusChanged(
      widget.focus == next ? ActivityMetricFocus.none : next,
    );
  }

  String get _focusLabel {
    switch (widget.focus) {
      case ActivityMetricFocus.users:
        return 'Usuarios';
      case ActivityMetricFocus.withLogins:
        return 'Ingresos (${widget.periodLabel})';
      case ActivityMetricFocus.withOrders:
        return 'Pedidos (${widget.periodLabel})';
      case ActivityMetricFocus.withDelivered:
        return 'Entregados';
      case ActivityMetricFocus.withVolume:
        return 'Vol. USD entregado';
      case ActivityMetricFocus.catalogs:
        return 'Catálogos publicados';
      case ActivityMetricFocus.none:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accents = _MetricAccents.resolve(theme, dark);

    final volumeSubtitle = _bcvRate == null || _bcvRate! <= 0
        ? 'BCV —'
        : formatBsLabel(widget.volumeUsd * _bcvRate!, fractionDigits: 0);

    final cards = <_MetricSpec>[
      _MetricSpec(
        focus: ActivityMetricFocus.users,
        label: 'Usuarios',
        value: '${widget.users}',
        glyph: LucideGlyph.users,
        accent: accents.users,
      ),
      _MetricSpec(
        focus: ActivityMetricFocus.withLogins,
        label: 'Ingresos (${widget.periodLabel})',
        value: '${widget.logins}',
        glyph: LucideGlyph.activity,
        accent: accents.logins,
      ),
      _MetricSpec(
        focus: ActivityMetricFocus.withOrders,
        label: 'Pedidos (${widget.periodLabel})',
        value: '${widget.orders}',
        glyph: LucideGlyph.shoppingCart,
        accent: accents.orders,
      ),
      _MetricSpec(
        focus: ActivityMetricFocus.withDelivered,
        label: 'Entregados',
        value: '${widget.delivered}',
        glyph: LucideGlyph.packageCheck,
        accent: accents.delivered,
      ),
      _MetricSpec(
        focus: ActivityMetricFocus.withVolume,
        label: 'Vol. USD entregado',
        value: '\$${widget.volumeUsd.toStringAsFixed(0)}',
        subtitle: volumeSubtitle,
        glyph: LucideGlyph.dollarSign,
        accent: accents.volume,
      ),
      if (widget.showCatalogs)
        _MetricSpec(
          focus: ActivityMetricFocus.catalogs,
          label: 'Catálogos publicados',
          value: widget.catalogsLoading
              ? '…'
              : '${widget.catalogsCount ?? '—'}',
          subtitle: 'Ver lista',
          glyph: LucideGlyph.store,
          accent: accents.catalogs,
          debugKey: const Key('admin-published-catalogs-stat'),
        ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final catalogOn = widget.showCatalogs;
        final cols = constraints.maxWidth >= 1100
            ? (catalogOn ? 6 : 5)
            : constraints.maxWidth >= 900
                ? 3
                : constraints.maxWidth >= 560
                    ? 2
                    : 1;
        const gap = 10.0;
        final width = (constraints.maxWidth - gap * (cols - 1)) / cols;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final spec in cards)
                  SizedBox(
                    key: spec.debugKey,
                    width: width,
                    child: _ActivityMetricCard(
                      spec: spec,
                      selected: widget.focus == spec.focus,
                      onTap: () => _toggle(spec.focus),
                    ),
                  ),
              ],
            ),
            if (widget.focus != ActivityMetricFocus.none) ...[
              const SizedBox(height: 10),
              _ActiveFilterBanner(
                label: _focusLabel,
                onClear: () =>
                    widget.onFocusChanged(ActivityMetricFocus.none),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _MetricSpec {
  const _MetricSpec({
    required this.focus,
    required this.label,
    required this.value,
    required this.glyph,
    required this.accent,
    this.subtitle,
    this.debugKey,
  });

  final ActivityMetricFocus focus;
  final String label;
  final String value;
  final String? subtitle;
  final LucideGlyph glyph;
  final _Accent accent;
  final Key? debugKey;
}

class _Accent {
  const _Accent({required this.bg, required this.fg});
  final Color bg;
  final Color fg;
}

class _MetricAccents {
  const _MetricAccents({
    required this.users,
    required this.logins,
    required this.orders,
    required this.delivered,
    required this.volume,
    required this.catalogs,
  });

  final _Accent users;
  final _Accent logins;
  final _Accent orders;
  final _Accent delivered;
  final _Accent volume;
  final _Accent catalogs;

  static _MetricAccents resolve(B2BThemeExtension theme, bool dark) {
    return _MetricAccents(
      users: _Accent(bg: theme.brandContainer, fg: theme.brand),
      logins: _Accent(
        bg: dark ? const Color(0x2606B6D4) : const Color(0xFFECFEFF),
        fg: dark ? const Color(0xFF22D3EE) : const Color(0xFF0891B2),
      ),
      orders: _Accent(
        bg: dark ? const Color(0x264F46E5) : const Color(0xFFEEF2FF),
        fg: dark ? const Color(0xFFA5B4FC) : const Color(0xFF4F46E5),
      ),
      delivered: _Accent(bg: theme.successBg, fg: theme.successFg),
      volume: _Accent(bg: theme.successBg, fg: theme.successFg),
      catalogs: _Accent(
        bg: dark ? const Color(0x267C3AED) : const Color(0xFFF5F3FF),
        fg: dark ? const Color(0xFFC4B5FD) : const Color(0xFF7C3AED),
      ),
    );
  }
}

class _ActivityMetricCard extends StatelessWidget {
  const _ActivityMetricCard({
    required this.spec,
    required this.selected,
    required this.onTap,
  });

  final _MetricSpec spec;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final border = selected ? theme.brand : theme.borderSubtle;
    final fill = selected ? theme.brandContainer : theme.surfaceCard;

    return Material(
      color: fill,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border, width: selected ? 1.6 : 1),
            boxShadow: [
              BoxShadow(
                color: theme.textPrimary.withOpacity(selected ? 0.10 : 0.04),
                blurRadius: selected ? 14 : 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: spec.accent.bg,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: LucideIcon(
                      spec.glyph,
                      size: 18,
                      color: spec.accent.fg,
                    ),
                  ),
                  const Spacer(),
                  if (selected)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: theme.brand,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Activo',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: theme.surfaceCard,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                spec.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: theme.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                spec.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                  color: theme.textPrimary,
                ),
              ),
              if (spec.subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  spec.subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: selected ? theme.brand : theme.textMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ActiveFilterBanner extends StatelessWidget {
  const _ActiveFilterBanner({
    required this.label,
    required this.onClear,
  });

  final String label;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    return Material(
      color: theme.brandContainer,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
        child: Row(
          children: [
            LucideIcon(
              LucideGlyph.slidersHorizontal,
              size: 14,
              color: theme.brand,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Filtro activo: $label',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: theme.brand,
                ),
              ),
            ),
            TextButton(
              onPressed: onClear,
              style: TextButton.styleFrom(
                foregroundColor: theme.brand,
                visualDensity: VisualDensity.compact,
              ),
              child: const Text('Limpiar'),
            ),
          ],
        ),
      ),
    );
  }
}
