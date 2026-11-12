import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'package:motolink_pro_app/core/utils/bcv_base_price.dart';
import 'package:motolink_pro_app/features/commissions/commission_collected_income_period.dart';
import 'package:motolink_pro_app/features/commissions/commission_collected_income_report.dart';

/// Punto diario de ingresos (período actual + alineado del período previo).
@immutable
class RevenueDayPoint {
  const RevenueDayPoint({
    required this.date,
    required this.usd,
    required this.previousUsd,
  });

  final DateTime date;
  final double usd;
  final double previousUsd;

  double? get deltaPctVsPrevious {
    if (previousUsd <= 0) return usd > 0 ? 100.0 : null;
    return ((usd - previousUsd) / previousUsd) * 100;
  }
}

/// Snapshot de la serie «ingresos en el tiempo» (últimos 30 días).
@immutable
class AdminRevenueOverTimeSnapshot {
  const AdminRevenueOverTimeSnapshot({
    required this.points,
    required this.bcvRate,
    required this.from,
    required this.to,
    this.isFallback = false,
  });

  final List<RevenueDayPoint> points;
  final double? bcvRate;
  final DateTime from;
  final DateTime to;
  final bool isFallback;

  bool get isEmpty =>
      points.isEmpty || points.every((p) => p.usd <= 0 && p.previousUsd <= 0);

  double get maxUsd {
    var m = 0.0;
    for (final p in points) {
      m = math.max(m, math.max(p.usd, p.previousUsd));
    }
    return m;
  }

  static AdminRevenueOverTimeSnapshot empty() {
    final to = CommissionCollectedIncomePeriod.dateOnlyCaracas();
    final from = to.subtract(const Duration(days: 29));
    return AdminRevenueOverTimeSnapshot(
      points: [
        for (var i = 0; i < 30; i++)
          RevenueDayPoint(
            date: from.add(Duration(days: i)),
            usd: 0,
            previousUsd: 0,
          ),
      ],
      bcvRate: null,
      from: from,
      to: to,
    );
  }

  /// Serie sintética estructurada (demo / error de red).
  static AdminRevenueOverTimeSnapshot structuredFallback({
    double? bcvRate,
  }) {
    final to = CommissionCollectedIncomePeriod.dateOnlyCaracas();
    final from = to.subtract(const Duration(days: 29));
    final points = <RevenueDayPoint>[];
    for (var i = 0; i < 30; i++) {
      final wave = 900 + (i * 47) % 680 + math.sin(i / 4.2) * 220;
      final prev = 750 + (i * 39) % 520 + math.cos(i / 5.1) * 180;
      points.add(
        RevenueDayPoint(
          date: from.add(Duration(days: i)),
          usd: wave.clamp(0, 5000).toDouble(),
          previousUsd: prev.clamp(0, 5000).toDouble(),
        ),
      );
    }
    return AdminRevenueOverTimeSnapshot(
      points: points,
      bcvRate: bcvRate,
      from: from,
      to: to,
      isFallback: true,
    );
  }
}

/// Carga la serie diaria de comisión cobrada (últimos 30 días + previos).
class AdminRevenueOverTime extends ChangeNotifier {
  AdminRevenueOverTime({AdminRevenueOverTimeSnapshot? seed})
      : _snapshot = seed ?? AdminRevenueOverTimeSnapshot.empty();

  AdminRevenueOverTimeSnapshot _snapshot;
  bool _loading = false;
  bool _started = false;
  bool _disposed = false;
  bool _comparePrevious = false;
  Timer? _poll;

  AdminRevenueOverTimeSnapshot get snapshot => _snapshot;
  bool get loading => _loading;
  bool get comparePrevious => _comparePrevious;

  set comparePrevious(bool value) {
    if (_comparePrevious == value) return;
    _comparePrevious = value;
    notifyListeners();
  }

  @visibleForTesting
  void applySnapshot(
    AdminRevenueOverTimeSnapshot snapshot, {
    bool loading = false,
    bool? comparePrevious,
  }) {
    _snapshot = snapshot;
    _loading = loading;
    if (comparePrevious != null) _comparePrevious = comparePrevious;
    notifyListeners();
  }

  Future<void> start() async {
    if (_started || _disposed) return;
    _started = true;
    await refresh();
    if (_disposed) return;
    _poll = Timer.periodic(const Duration(seconds: 60), (_) {
      unawaited(refresh());
    });
  }

  Future<void> refresh() async {
    if (_loading || _disposed) return;
    _loading = true;
    notifyListeners();
    try {
      final to = CommissionCollectedIncomePeriod.dateOnlyCaracas();
      final from = to.subtract(const Duration(days: 29));
      final currentPeriod = CommissionCollectedIncomePeriod(
        from: from,
        to: to,
        preset: CommissionCollectedIncomePreset.custom,
      );
      final previousPeriod = currentPeriod.previousEquivalent;

      final results = await Future.wait<Object?>([
        SupabaseService.fetchCollectedCommissionReport(from: from, to: to),
        SupabaseService.fetchCollectedCommissionReport(
          from: previousPeriod.from,
          to: previousPeriod.to,
        ),
        BcvBasePrice.currentRate(),
      ]);

      if (_disposed) return;

      final current = results[0] as CommissionCollectedIncomeReport;
      final previous = results[1] as CommissionCollectedIncomeReport;
      final bcv = results[2] as double?;

      final points = _alignDailySeries(
        from: from,
        to: to,
        previousFrom: previousPeriod.from,
        current: current.series,
        previous: previous.series,
      );

      _snapshot = AdminRevenueOverTimeSnapshot(
        points: points,
        bcvRate: bcv,
        from: from,
        to: to,
        isFallback: false,
      );
    } catch (_) {
      if (_disposed) return;
      // Conserva datos reales previos; si nunca cargó, usa fallback estructurado.
      if (_snapshot.isEmpty || _snapshot.isFallback) {
        _snapshot = AdminRevenueOverTimeSnapshot.structuredFallback(
          bcvRate: _snapshot.bcvRate ?? BcvBasePrice.cachedRate,
        );
      }
    } finally {
      if (!_disposed) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  static List<RevenueDayPoint> _alignDailySeries({
    required DateTime from,
    required DateTime to,
    required DateTime previousFrom,
    required List<CommissionCollectedIncomeBucket> current,
    required List<CommissionCollectedIncomeBucket> previous,
  }) {
    String key(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';

    final curMap = <String, double>{
      for (final b in current) key(b.bucket): b.totalCollectedUsd,
    };
    final prevMap = <String, double>{
      for (final b in previous) key(b.bucket): b.totalCollectedUsd,
    };

    final points = <RevenueDayPoint>[];
    var i = 0;
    for (var d = from; !d.isAfter(to); d = d.add(const Duration(days: 1))) {
      final prevDate = previousFrom.add(Duration(days: i));
      points.add(
        RevenueDayPoint(
          date: DateTime(d.year, d.month, d.day),
          usd: curMap[key(d)] ?? 0,
          previousUsd: prevMap[key(prevDate)] ?? 0,
        ),
      );
      i++;
    }
    return points;
  }

  @override
  void dispose() {
    _disposed = true;
    _poll?.cancel();
    super.dispose();
  }
}
