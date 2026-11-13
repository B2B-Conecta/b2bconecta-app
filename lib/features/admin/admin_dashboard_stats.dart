import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:motolink_pro_app/core/data/supabase_access.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'package:motolink_pro_app/core/utils/bcv_base_price.dart';
import 'package:motolink_pro_app/features/commissions/commission_collected_income_period.dart';
import 'package:motolink_pro_app/features/commissions/commission_collected_income_report.dart';
import 'package:motolink_pro_app/features/kyc/account_access_status.dart';
import 'package:motolink_pro_app/features/orders/shared/aliado_order_grouping.dart';
import 'package:motolink_pro_app/features/orders/shared/orders_service.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_status.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Snapshot de métricas del dashboard admin.
@immutable
class AdminDashboardStatsSnapshot {
  const AdminDashboardStatsSnapshot({
    required this.activeUsers,
    required this.activeUsersDeltaPct,
    required this.activeOrders,
    required this.activeOrdersDeltaPct,
    required this.revenueUsd,
    required this.revenueDeltaPct,
    required this.bcvRate,
    required this.conversionPct,
    required this.conversionDeltaPct,
  });

  final int activeUsers;
  final double activeUsersDeltaPct;
  final int activeOrders;
  final double activeOrdersDeltaPct;
  final double revenueUsd;
  final double revenueDeltaPct;
  final double? bcvRate;
  final double conversionPct;
  final double conversionDeltaPct;

  double? get revenueBs {
    final rate = bcvRate;
    if (rate == null || rate <= 0) return null;
    return revenueUsd * rate;
  }

  static const empty = AdminDashboardStatsSnapshot(
    activeUsers: 0,
    activeUsersDeltaPct: 0,
    activeOrders: 0,
    activeOrdersDeltaPct: 0,
    revenueUsd: 0,
    revenueDeltaPct: 0,
    bcvRate: null,
    conversionPct: 0,
    conversionDeltaPct: 0,
  );
}

/// Carga periódica de métricas clave del panel admin.
class AdminDashboardStats extends ChangeNotifier {
  AdminDashboardStats({AdminDashboardStatsSnapshot? seed})
      : _snapshot = seed ?? AdminDashboardStatsSnapshot.empty;

  AdminDashboardStatsSnapshot _snapshot;
  bool _loading = false;
  bool _started = false;
  bool _disposed = false;
  Timer? _poll;

  AdminDashboardStatsSnapshot get snapshot => _snapshot;
  bool get loading => _loading;

  /// Inyecta un snapshot (tests / demos) sin pegarle a Supabase.
  @visibleForTesting
  void applySnapshot(
    AdminDashboardStatsSnapshot snapshot, {
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
    _poll = Timer.periodic(const Duration(seconds: 60), (_) {
      unawaited(refresh());
    });
  }

  Future<void> refresh() async {
    if (_loading || _disposed) return;
    _loading = true;
    notifyListeners();
    try {
      final period = CommissionCollectedIncomePeriod.fromPreset(
        CommissionCollectedIncomePreset.thisMonth,
      );
      final prev = period.previousEquivalent;

      final results = await Future.wait<Object?>([
        _countActiveBusinessProfiles(),
        OrdersService.countActiveTransactionRequestsForAdmin(),
        _countOrdersCreatedBetween(
          from: prev.from,
          to: prev.to,
          activeOnly: true,
        ),
        SupabaseService.fetchCollectedCommissionReport(
          from: period.from,
          to: period.to,
        ),
        BcvBasePrice.currentRate(),
        _countOrdersByStatusBetween(
          from: period.from,
          to: period.to,
          statuses: const [TransactionRequestStatus.entregado],
        ),
        _countOrdersCreatedBetween(
          from: period.from,
          to: period.to,
          activeOnly: false,
        ),
        _countOrdersByStatusBetween(
          from: prev.from,
          to: prev.to,
          statuses: const [TransactionRequestStatus.entregado],
        ),
        _countOrdersCreatedBetween(
          from: prev.from,
          to: prev.to,
          activeOnly: false,
        ),
      ]);

      if (_disposed) return;

      final activeUsers = results[0] as int;
      final activeOrders = results[1] as int;
      final prevActiveOrders = results[2] as int;
      final revenueReport = results[3] as CommissionCollectedIncomeReport;
      final bcv = results[4] as double?;
      final delivered = results[5] as int;
      final created = results[6] as int;
      final prevDelivered = results[7] as int;
      final prevCreated = results[8] as int;

      final revenueUsd = revenueReport.totalCollectedUsd;
      final revenueDelta = revenueReport.variationPct ?? 0.0;

      final conversion = created <= 0 ? 0.0 : (delivered / created) * 100;
      final prevConversion =
          prevCreated <= 0 ? 0.0 : (prevDelivered / prevCreated) * 100;

      _snapshot = AdminDashboardStatsSnapshot(
        activeUsers: activeUsers,
        // Sin serie histórica de perfiles: delta neutro hasta que exista RPC.
        activeUsersDeltaPct: 0,
        activeOrders: activeOrders,
        activeOrdersDeltaPct:
            _deltaPct(activeOrders.toDouble(), prevActiveOrders.toDouble()),
        revenueUsd: revenueUsd,
        revenueDeltaPct: revenueDelta,
        bcvRate: bcv,
        conversionPct: conversion,
        conversionDeltaPct: conversion - prevConversion,
      );
    } catch (_) {
      // Conserva el último snapshot.
    } finally {
      if (!_disposed) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  static double _deltaPct(double current, double previous) {
    if (previous <= 0) return current > 0 ? 100 : 0;
    return ((current - previous) / previous) * 100;
  }

  static Future<int> _countActiveBusinessProfiles() async {
    final res = await SupabaseAccess.client
        .from('profiles')
        .select('id')
        .inFilter('role', const ['aliado', 'importador'])
        .eq('account_access_status', AccountAccessStatus.active)
        .count(CountOption.exact);
    return (res as PostgrestResponse<dynamic>).count;
  }

  /// Cuenta pedidos/carritos (no líneas) en el rango.
  static Future<int> _countOrdersCreatedBetween({
    required DateTime from,
    required DateTime to,
    required bool activeOnly,
  }) async {
    final fromUtc = DateTime(from.year, from.month, from.day).toUtc();
    final toUtc = DateTime(to.year, to.month, to.day, 23, 59, 59, 999).toUtc();
    var q = SupabaseAccess.client
        .from('transaction_requests')
        .select('id, checkout_group_id')
        .gte('created_at', fromUtc.toIso8601String())
        .lte('created_at', toUtc.toIso8601String());
    if (activeOnly) {
      q = q.inFilter(
        'status',
        TransactionRequestStatus.motoconectaAdminOperationalActive,
      );
    }
    final response = await q;
    final list = response as List<dynamic>;
    return countDistinctCheckoutOrders(
      list.map((raw) {
        final m = Map<String, dynamic>.from(raw as Map);
        return (
          id: m['id']?.toString() ?? '',
          checkoutGroupId: m['checkout_group_id']?.toString(),
        );
      }),
    );
  }

  static Future<int> _countOrdersByStatusBetween({
    required DateTime from,
    required DateTime to,
    required List<String> statuses,
  }) async {
    final fromUtc = DateTime(from.year, from.month, from.day).toUtc();
    final toUtc = DateTime(to.year, to.month, to.day, 23, 59, 59, 999).toUtc();
    final response = await SupabaseAccess.client
        .from('transaction_requests')
        .select('id, checkout_group_id')
        .inFilter('status', statuses)
        .gte('updated_at', fromUtc.toIso8601String())
        .lte('updated_at', toUtc.toIso8601String());
    final list = response as List<dynamic>;
    return countDistinctCheckoutOrders(
      list.map((raw) {
        final m = Map<String, dynamic>.from(raw as Map);
        return (
          id: m['id']?.toString() ?? '',
          checkoutGroupId: m['checkout_group_id']?.toString(),
        );
      }),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _poll?.cancel();
    super.dispose();
  }
}
