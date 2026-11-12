import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'package:motolink_pro_app/core/utils/bcv_base_price.dart';
import 'package:motolink_pro_app/features/admin/admin_product_sales_ranking.dart';
import 'package:motolink_pro_app/features/commissions/commission_collected_income_period.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_model.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_status.dart';

/// Fila del ranking semanal de productos.
@immutable
class TopProductWeekRow {
  const TopProductWeekRow({
    required this.productKey,
    required this.name,
    required this.unitsSold,
    required this.revenueUsd,
    required this.monthProgress,
    required this.trendPct,
    required this.spark,
    this.sku,
    this.category,
  });

  final String productKey;
  final String name;
  final String? sku;
  final String? category;
  final int unitsSold;
  final double revenueUsd;

  /// Avance vs. ingresos del mes en curso (0–1).
  final double monthProgress;

  /// Variación vs. la semana anterior (%).
  final double trendPct;

  /// Serie diaria de ingresos (7 puntos, lunes→hoy relativo).
  final List<double> spark;

  String get subtitle {
    final skuLabel = sku?.trim();
    if (skuLabel != null && skuLabel.isNotEmpty) return 'SKU $skuLabel';
    final cat = category?.trim();
    if (cat != null && cat.isNotEmpty) return cat;
    return 'Repuesto';
  }
}

@immutable
class AdminTopProductsWeekSnapshot {
  const AdminTopProductsWeekSnapshot({
    required this.rows,
    this.bcvRate,
    this.isFallback = false,
  });

  final List<TopProductWeekRow> rows;
  final double? bcvRate;
  final bool isFallback;

  bool get isEmpty => rows.isEmpty;

  static const empty = AdminTopProductsWeekSnapshot(rows: []);

  static AdminTopProductsWeekSnapshot structuredFallback({double? bcvRate}) {
    return AdminTopProductsWeekSnapshot(
      isFallback: true,
      bcvRate: bcvRate,
      rows: const [
        TopProductWeekRow(
          productKey: 'fb-1',
          name: 'Disco EBC 245 mm',
          sku: 'EBC-245-FR',
          category: 'Frenos',
          unitsSold: 128,
          revenueUsd: 3840,
          monthProgress: 0.72,
          trendPct: 12.4,
          spark: [420, 510, 480, 620, 590, 710, 510],
        ),
        TopProductWeekRow(
          productKey: 'fb-2',
          name: 'Casco Venture 1.0 MIPS',
          sku: 'VEN-MIPS-M',
          category: 'Seguridad',
          unitsSold: 46,
          revenueUsd: 3220,
          monthProgress: 0.58,
          trendPct: 8.1,
          spark: [380, 410, 390, 450, 470, 520, 600],
        ),
        TopProductWeekRow(
          productKey: 'fb-3',
          name: 'Pastillas de freno sinterizadas',
          sku: 'PAD-SIN-01',
          category: 'Frenos',
          unitsSold: 210,
          revenueUsd: 2520,
          monthProgress: 0.64,
          trendPct: -3.2,
          spark: [410, 390, 370, 360, 340, 330, 320],
        ),
        TopProductWeekRow(
          productKey: 'fb-4',
          name: 'Kit cadena DID 520VX3',
          sku: 'DID-520-VX3',
          category: 'Transmisión',
          unitsSold: 67,
          revenueUsd: 2144,
          monthProgress: 0.41,
          trendPct: 5.6,
          spark: [250, 280, 270, 300, 310, 340, 394],
        ),
        TopProductWeekRow(
          productKey: 'fb-5',
          name: 'Aceite Motul 7100 10W40',
          sku: 'MOT-7100-1L',
          category: 'Lubricantes',
          unitsSold: 312,
          revenueUsd: 1872,
          monthProgress: 0.55,
          trendPct: 2.1,
          spark: [240, 250, 260, 255, 270, 280, 317],
        ),
      ],
    );
  }
}

/// Ranking top 5 productos por ingresos (última semana).
class AdminTopProductsWeek extends ChangeNotifier {
  AdminTopProductsWeek({AdminTopProductsWeekSnapshot? seed})
      : _snapshot = seed ?? AdminTopProductsWeekSnapshot.empty;

  AdminTopProductsWeekSnapshot _snapshot;
  bool _loading = false;
  bool _started = false;
  bool _disposed = false;
  Timer? _poll;

  AdminTopProductsWeekSnapshot get snapshot => _snapshot;
  bool get loading => _loading;

  @visibleForTesting
  void applySnapshot(
    AdminTopProductsWeekSnapshot snapshot, {
    bool loading = false,
  }) {
    _snapshot = snapshot;
    _loading = loading;
    notifyListeners();
  }

  Future<void> start() async {
    if (_started || _disposed) return;
    _started = true;
    await refresh();
    if (_disposed) return;
    _poll = Timer.periodic(const Duration(seconds: 90), (_) {
      unawaited(refresh());
    });
  }

  Future<void> refresh() async {
    if (_loading || _disposed) return;
    _loading = true;
    notifyListeners();
    try {
      final today = CommissionCollectedIncomePeriod.dateOnlyCaracas();
      final weekFrom = today.subtract(const Duration(days: 6));
      final prevTo = weekFrom.subtract(const Duration(days: 1));
      final prevFrom = prevTo.subtract(const Duration(days: 6));
      final monthFrom = DateTime(today.year, today.month, 1);

      const statuses = [
        TransactionRequestStatus.entregado,
        TransactionRequestStatus.enTransito,
        TransactionRequestStatus.enviado,
        TransactionRequestStatus.pedidoListo,
        TransactionRequestStatus.enPreparacion,
        TransactionRequestStatus.aprobadoAdmin,
      ];

      final results = await Future.wait<Object?>([
        SupabaseService.fetchTransactionRequestsForAdminReport(
          createdFromLocal: weekFrom,
          createdToLocal: today,
          statuses: statuses,
          limit: 1500,
        ),
        SupabaseService.fetchTransactionRequestsForAdminReport(
          createdFromLocal: prevFrom,
          createdToLocal: prevTo,
          statuses: statuses,
          limit: 1500,
        ),
        SupabaseService.fetchTransactionRequestsForAdminReport(
          createdFromLocal: monthFrom,
          createdToLocal: today,
          statuses: statuses,
          limit: 2500,
        ),
        BcvBasePrice.currentRate(),
      ]);

      if (_disposed) return;

      final weekRows = results[0] as List<TransactionRequestModel>;
      final prevRows = results[1] as List<TransactionRequestModel>;
      final monthRows = results[2] as List<TransactionRequestModel>;
      final bcv = results[3] as double?;

      final weekAgg = _aggregateByRevenue(weekRows);
      if (weekAgg.isEmpty) {
        _snapshot = AdminTopProductsWeekSnapshot.structuredFallback(
          bcvRate: bcv,
        );
      } else {
        final prevMap = {
          for (final s in aggregateProductSales(prevRows))
            s.productKey: s.totalRefUsd,
        };
        final monthMap = {
          for (final s in aggregateProductSales(monthRows))
            s.productKey: s.totalRefUsd,
        };
        final sparks = _dailySparks(weekRows, weekFrom, today);

        final top = weekAgg.take(5).map((s) {
          final prev = prevMap[s.productKey] ?? 0;
          final month = monthMap[s.productKey] ?? s.totalRefUsd;
          final trend = prev <= 0
              ? (s.totalRefUsd > 0 ? 100.0 : 0.0)
              : ((s.totalRefUsd - prev) / prev) * 100;
          final progress = month <= 0
              ? 0.0
              : (s.totalRefUsd / month).clamp(0.0, 1.0);
          return TopProductWeekRow(
            productKey: s.productKey,
            name: s.productName,
            sku: s.productSku,
            category: s.importerName,
            unitsSold: s.unitsSold,
            revenueUsd: s.totalRefUsd,
            monthProgress: progress.toDouble(),
            trendPct: trend,
            spark: sparks[s.productKey] ?? List<double>.filled(7, 0),
          );
        }).toList();

        _snapshot = AdminTopProductsWeekSnapshot(
          rows: top,
          bcvRate: bcv,
        );
      }
    } catch (_) {
      if (_disposed) return;
      if (_snapshot.isEmpty || _snapshot.isFallback) {
        _snapshot = AdminTopProductsWeekSnapshot.structuredFallback(
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

  static List<AdminProductSalesStat> _aggregateByRevenue(
    List<TransactionRequestModel> rows,
  ) {
    final stats = aggregateProductSales(rows);
    stats.sort((a, b) {
      final byRev = b.totalRefUsd.compareTo(a.totalRefUsd);
      if (byRev != 0) return byRev;
      return b.unitsSold.compareTo(a.unitsSold);
    });
    return stats;
  }

  static Map<String, List<double>> _dailySparks(
    List<TransactionRequestModel> rows,
    DateTime from,
    DateTime to,
  ) {
    final days = to.difference(from).inDays + 1;
    final map = <String, List<double>>{};

    for (final r in rows) {
      final created = r.createdAt?.toLocal();
      if (created == null) continue;
      final day = DateTime(created.year, created.month, created.day);
      if (day.isBefore(from) || day.isAfter(to)) continue;
      final pk = adminProductSalesKey(r);
      final series = map.putIfAbsent(
        pk,
        () => List<double>.filled(days, 0),
      );
      final idx = day.difference(from).inDays.clamp(0, days - 1);
      series[idx] += r.precioTotal;
    }
    return map;
  }

  @override
  void dispose() {
    _disposed = true;
    _poll?.cancel();
    super.dispose();
  }
}
