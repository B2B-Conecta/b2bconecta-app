import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/app_dark_tokens.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'package:motolink_pro_app/core/utils/ves_amount_format.dart';
import 'package:motolink_pro_app/features/admin/admin_revenue_over_time.dart';
import 'package:motolink_pro_app/features/admin/admin_users_chrome.dart';

/// Gráfico de ingresos cobrados (últimos 30 días) para el dashboard admin.
class RevenueOverTimeChart extends StatelessWidget {
  const RevenueOverTimeChart({
    super.key,
    required this.series,
    this.fillHeight = false,
  });

  final AdminRevenueOverTime series;

  /// Cuando está en un [SizedBox]/[Expanded] con altura fija (fila del dashboard).
  final bool fillHeight;

  /// Altura alineada con [RecentActivityFeed.preferredHeight].
  static const preferredHeight = 380.0;

  static Color get _title => AdminUsersChrome.titleColor;
  static Color get _muted => AdminUsersChrome.muted;
  static Color get _brand => AdminUsersChrome.brand;
  static Color get _compare => AppColors.brightness == Brightness.dark
      ? AppDarkTokens.textMuted
      : const Color(0xFF94A3B8);
  static Color get _grid => AppColors.brightness == Brightness.dark
      ? AppDarkTokens.border
      : const Color(0xFFF1F5F9);

  static const _monthsEs = [
    'Ene',
    'Feb',
    'Mar',
    'Abr',
    'May',
    'Jun',
    'Jul',
    'Ago',
    'Sep',
    'Oct',
    'Nov',
    'Dic',
  ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: series,
      builder: (context, _) {
        final snap = series.snapshot;
        final compare = series.comparePrevious;
        final card = Container(
          padding: const EdgeInsets.all(20),
          decoration: AdminUsersChrome.card(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final stackedHeader = constraints.maxWidth < 520;
                  final titleBlock = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ingresos en el tiempo',
                        style: TextStyle(
                          fontSize: stackedHeader ? 15 : 16,
                          fontWeight: FontWeight.w700,
                          color: _title,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Últimos 30 días',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: _muted,
                        ),
                      ),
                    ],
                  );
                  final toggle = _CompareToggle(
                    value: compare,
                    onChanged: (v) => series.comparePrevious = v,
                    compact: stackedHeader,
                  );
                  if (stackedHeader) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        titleBlock,
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: toggle,
                        ),
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: titleBlock),
                      const SizedBox(width: 12),
                      toggle,
                    ],
                  );
                },
              ),
              if (snap.isFallback) ...[
                const SizedBox(height: 8),
                Text(
                  'Mostrando proyección ilustrativa (sin histórico reciente).',
                  style: TextStyle(
                    fontSize: 11,
                    color: _muted.withOpacity(0.95),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              if (fillHeight)
                Expanded(
                  child: series.loading && snap.isEmpty
                      ? const Center(
                          child: SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(strokeWidth: 2.4),
                          ),
                        )
                      : _ChartBody(
                          snapshot: snap,
                          comparePrevious: compare,
                        ),
                )
              else
                SizedBox(
                  height: MediaQuery.sizeOf(context).width < 768 ? 200 : 260,
                  child: series.loading && snap.isEmpty
                      ? const Center(
                          child: SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(strokeWidth: 2.4),
                          ),
                        )
                      : _ChartBody(
                          snapshot: snap,
                          comparePrevious: compare,
                        ),
                ),
            ],
          ),
        );
        return fillHeight ? SizedBox.expand(child: card) : card;
      },
    );
  }

  static String formatAxisUsd(double value) {
    if (value <= 0) return '\$0';
    if (value >= 1000) {
      final k = value / 1000;
      final label = k == k.roundToDouble()
          ? k.toStringAsFixed(0)
          : k.toStringAsFixed(1);
      return '\$${label}k';
    }
    return '\$${value.toStringAsFixed(0)}';
  }

  static String formatUsdMoney(double value) {
    final negative = value.isNegative;
    final abs = negative ? -value : value;
    final s = abs.toStringAsFixed(2);
    final dot = s.indexOf('.');
    final intPart = dot >= 0 ? s.substring(0, dot) : s;
    final dec = dot >= 0 ? s.substring(dot + 1) : '00';
    final buf = StringBuffer();
    for (var i = 0; i < intPart.length; i++) {
      final fromEnd = intPart.length - i;
      if (i > 0 && fromEnd % 3 == 0) buf.write(',');
      buf.write(intPart[i]);
    }
    final core = '\$$buf.$dec USD';
    return negative ? '-$core' : core;
  }

  static String formatDayLabel(DateTime d) =>
      '${d.day} ${_monthsEs[d.month - 1]}';
}

class _CompareToggle extends StatelessWidget {
  const _CompareToggle({
    required this.value,
    required this.onChanged,
    this.compact = false,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final bg = value
        ? theme.brandContainer
        : theme.inputFill;
    final border = value ? theme.brand.withOpacity(0.45) : theme.borderSubtle;
    final fg = value ? theme.brand : theme.textSecondary;
    final label = compact ? 'Comparar periodo anterior' : 'Comparar con los 30 días anteriores';
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: EdgeInsets.fromLTRB(compact ? 10 : 10, 6, 8, 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: compact ? 200 : 148),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                    color: fg,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                height: 28,
                width: 42,
                child: Transform.scale(
                  scale: 0.78,
                  child: Switch(
                    value: value,
                    onChanged: onChanged,
                    activeTrackColor: theme.brand,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChartBody extends StatelessWidget {
  const _ChartBody({
    required this.snapshot,
    required this.comparePrevious,
  });

  final AdminRevenueOverTimeSnapshot snapshot;
  final bool comparePrevious;

  @override
  Widget build(BuildContext context) {
    final points = snapshot.points;
    if (points.isEmpty) {
      return Center(
        child: Text(
          'Sin datos de ingresos',
          style: TextStyle(color: RevenueOverTimeChart._muted),
        ),
      );
    }

    final maxY = math.max(snapshot.maxUsd * 1.15, 1.0);
    final spots = <FlSpot>[
      for (var i = 0; i < points.length; i++)
        FlSpot(i.toDouble(), points[i].usd),
    ];
    final prevSpots = <FlSpot>[
      for (var i = 0; i < points.length; i++)
        FlSpot(i.toDouble(), points[i].previousUsd),
    ];

    final interval = _niceInterval(maxY);
    final theme = B2BThemeExtension.of(context);

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (points.length - 1).toDouble(),
        minY: 0,
        maxY: maxY,
        clipData: const FlClipData.all(),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: interval,
          getDrawingHorizontalLine: (value) => FlLine(
            color: RevenueOverTimeChart._grid,
            strokeWidth: 1,
            dashArray: [4, 4],
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 42,
              interval: interval,
              getTitlesWidget: (value, meta) {
                if (value < 0 || value > maxY * 1.01) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Text(
                    RevenueOverTimeChart.formatAxisUsd(value),
                    style: TextStyle(
                      fontSize: 11,
                      color: RevenueOverTimeChart._muted,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.right,
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final i = value.round();
                if (i < 0 || i >= points.length) {
                  return const SizedBox.shrink();
                }
                // Etiquetas cada ~5 días + extremos.
                final isEdge = i == 0 || i == points.length - 1;
                if (!isEdge && i % 5 != 0) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    RevenueOverTimeChart.formatDayLabel(points[i].date),
                    style: TextStyle(
                      fontSize: 11,
                      color: RevenueOverTimeChart._muted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          enabled: true,
          handleBuiltInTouches: true,
          touchSpotThreshold: 28,
          getTouchedSpotIndicator: (barData, spotIndexes) {
            return spotIndexes.map((index) {
              return TouchedSpotIndicatorData(
                FlLine(
                  color: RevenueOverTimeChart._brand.withOpacity(0.35),
                  strokeWidth: 1,
                  dashArray: [3, 3],
                ),
                FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, bar, i) => FlDotCirclePainter(
                    radius: 4.5,
                    color: AdminUsersChrome.cardColor,
                    strokeWidth: 2.5,
                    strokeColor: bar.color ?? RevenueOverTimeChart._brand,
                  ),
                ),
              );
            }).toList();
          },
          touchTooltipData: LineTouchTooltipData(
            maxContentWidth: 220,
            tooltipRoundedRadius: 10,
            tooltipPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipColor: (_) => theme.textPrimary,
            getTooltipItems: (touchedSpots) {
              if (touchedSpots.isEmpty) return [];
              // Un solo tooltip compuesto desde la serie principal.
              final main = touchedSpots.cast<LineBarSpot?>().firstWhere(
                    (s) => s?.barIndex == 0,
                    orElse: () => touchedSpots.first,
                  )!;
              final i = main.x.round().clamp(0, points.length - 1);
              final p = points[i];
              final lines = <String>[
                RevenueOverTimeChart.formatDayLabel(p.date),
                RevenueOverTimeChart.formatUsdMoney(p.usd),
              ];
              final rate = snapshot.bcvRate;
              if (rate != null && rate > 0) {
                lines.add(formatBsLabel(p.usd * rate, fractionDigits: 2));
              }
              if (comparePrevious) {
                final delta = p.deltaPctVsPrevious;
                if (delta != null) {
                  final sign = delta >= 0 ? '+' : '';
                  lines.add(
                    '$sign${formatVesAmount(delta, fractionDigits: 1)}% vs. prev.',
                  );
                }
              }
              return [
                for (var s = 0; s < touchedSpots.length; s++)
                  s == 0
                      ? LineTooltipItem(
                          lines.join('\n'),
                          TextStyle(
                            color: theme.surfaceCard,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                          ),
                        )
                      : null,
              ];
            },
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.28,
            preventCurveOverShooting: true,
            color: RevenueOverTimeChart._brand,
            barWidth: 3,
            isStrokeCapRound: true,
            isStrokeJoinRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                radius: 2.2,
                color: RevenueOverTimeChart._brand,
                strokeWidth: 0,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  RevenueOverTimeChart._brand.withOpacity(0.12),
                  RevenueOverTimeChart._brand.withOpacity(0.0),
                ],
              ),
            ),
          ),
          if (comparePrevious)
            LineChartBarData(
              spots: prevSpots,
              isCurved: true,
              curveSmoothness: 0.28,
              preventCurveOverShooting: true,
              color: RevenueOverTimeChart._compare,
              barWidth: 2,
              dashArray: const [6, 4],
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: false),
            ),
        ],
      ),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  static double _niceInterval(double maxY) {
    if (maxY <= 100) return 25;
    if (maxY <= 500) return 100;
    if (maxY <= 2000) return 500;
    if (maxY <= 10000) return 2000;
    if (maxY <= 50000) return 10000;
    return (maxY / 4).clamp(1000, double.infinity);
  }
}
