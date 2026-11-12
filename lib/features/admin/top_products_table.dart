import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:motolink_pro_app/core/utils/ves_amount_format.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';
import 'package:motolink_pro_app/features/admin/admin_top_products_week.dart';
import 'package:motolink_pro_app/features/admin/admin_users_chrome.dart';
import 'package:motolink_pro_app/app/theme/app_dark_tokens.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';

/// Mini-tabla «Productos más vendidos de la semana» del dashboard admin.
class TopProductsTable extends StatelessWidget {
  const TopProductsTable({
    super.key,
    required this.controller,
  });

  final AdminTopProductsWeek controller;

  static Color get _border => AdminUsersChrome.border;
  static Color get _title => AdminUsersChrome.titleColor;
  static Color get _muted => AdminUsersChrome.muted;
  static Color get _zebra => AdminUsersChrome.zebra;
  static Color get _brand => AdminUsersChrome.brand;
  static Color get _up => AppColors.brightness == Brightness.dark
      ? AppDarkTokens.successFg
      : const Color(0xFF16A34A);
  static Color get _down => AppColors.brightness == Brightness.dark
      ? AppDarkTokens.dangerFg
      : const Color(0xFFEF4444);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final snap = controller.snapshot;
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: AdminUsersChrome.card(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Productos más vendidos de la semana',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _title,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Top 5 artículos ordenados por ingresos generados',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: _muted,
                ),
              ),
              if (snap.isFallback) ...[
                const SizedBox(height: 6),
                Text(
                  'Mostrando proyección ilustrativa (sin ventas recientes).',
                  style: TextStyle(
                    fontSize: 11,
                    color: _muted.withOpacity(0.95),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              if (controller.loading && snap.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    ),
                  ),
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 720;
                    return Column(
                      children: [
                        if (!compact) const _HeaderRow(),
                        for (var i = 0; i < snap.rows.length; i++)
                          _ProductRow(
                            row: snap.rows[i],
                            index: i,
                            bcvRate: snap.bcvRate,
                            compact: compact,
                          ),
                      ],
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  static String formatUsd(double value) {
    final s = value.toStringAsFixed(2);
    final dot = s.indexOf('.');
    final intPart = dot >= 0 ? s.substring(0, dot) : s;
    final dec = dot >= 0 ? s.substring(dot + 1) : '00';
    final buf = StringBuffer();
    for (var i = 0; i < intPart.length; i++) {
      final fromEnd = intPart.length - i;
      if (i > 0 && fromEnd % 3 == 0) buf.write(',');
      buf.write(intPart[i]);
    }
    return '\$$buf.$dec';
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: TopProductsTable._border),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              'Producto',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: TopProductsTable._muted,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Unidades',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: TopProductsTable._muted,
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Padding(
              padding: EdgeInsets.only(left: 16),
              child: Text(
                'Ingresos',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: TopProductsTable._muted,
                ),
              ),
            ),
          ),
          SizedBox(
            width: 120,
            child: Text(
              'Tendencia',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: TopProductsTable._muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({
    required this.row,
    required this.index,
    required this.compact,
    this.bcvRate,
  });

  final TopProductWeekRow row;
  final int index;
  final bool compact;
  final double? bcvRate;

  @override
  Widget build(BuildContext context) {
    final zebra = index.isOdd;
    final up = row.trendPct >= 0;
    final trendColor =
        up ? TopProductsTable._up : TopProductsTable._down;
    final bs = (bcvRate != null && bcvRate! > 0)
        ? formatBsLabel(row.revenueUsd * bcvRate!, fractionDigits: 2)
        : null;

    final product = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          row.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: TopProductsTable._title,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          row.subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: TopProductsTable._muted,
          ),
        ),
      ],
    );

    final units = Text(
      '${row.unitsSold}',
      textAlign: TextAlign.right,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: TopProductsTable._title,
      ),
    );

    final revenue = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${TopProductsTable.formatUsd(row.revenueUsd)} USD',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: TopProductsTable._title,
          ),
        ),
        if (bs != null) ...[
          const SizedBox(height: 2),
          Text(
            bs,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: TopProductsTable._muted,
            ),
          ),
        ],
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: row.monthProgress.clamp(0.0, 1.0),
            minHeight: 5,
            backgroundColor: AdminUsersChrome.border,
            color: TopProductsTable._brand,
          ),
        ),
      ],
    );

    final trend = FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerRight,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 40,
            height: 20,
            child: _Sparkline(
              points: row.spark,
              color: trendColor,
            ),
          ),
          const SizedBox(width: 4),
          LucideIcon(
            up ? LucideGlyph.trendingUp : LucideGlyph.trendingDown,
            size: 14,
            color: trendColor,
          ),
          const SizedBox(width: 2),
          Text(
            '${up ? '+' : ''}${formatVesAmount(row.trendPct, fractionDigits: 1)}%',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: trendColor,
            ),
          ),
        ],
      ),
    );

    if (compact) {
      return Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        color: zebra ? TopProductsTable._zebra : AdminUsersChrome.cardColor,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            product,
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  '${row.unitsSold} uds',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: TopProductsTable._title,
                  ),
                ),
                const Spacer(),
                trend,
              ],
            ),
            const SizedBox(height: 8),
            revenue,
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      color: zebra ? TopProductsTable._zebra : AdminUsersChrome.cardColor,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(flex: 4, child: product),
          Expanded(flex: 2, child: units),
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: revenue,
            ),
          ),
          SizedBox(width: 120, child: trend),
        ],
      ),
    );
  }
}

class _Sparkline extends StatelessWidget {
  const _Sparkline({
    required this.points,
    required this.color,
  });

  final List<double> points;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SparklinePainter(points: points, color: color),
      size: const Size(44, 22),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({
    required this.points,
    required this.color,
  });

  final List<double> points;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final maxV = points.reduce(math.max);
    final minV = points.reduce(math.min);
    final span = (maxV - minV).abs() < 0.001 ? 1.0 : (maxV - minV);
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final x = points.length == 1
          ? size.width / 2
          : i * size.width / (points.length - 1);
      final y = size.height -
          ((points[i] - minV) / span) * (size.height - 2) -
          1;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.color != color;
  }
}
