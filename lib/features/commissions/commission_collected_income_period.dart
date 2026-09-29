import 'package:motolink_pro_app/features/commissions/bcv_reference_rate_service.dart';

/// Presets de período para el reporte de comisión cobrada (zona America/Caracas).
enum CommissionCollectedIncomePreset {
  today,
  last7Days,
  thisMonth,
  previousMonth,
  custom,
}

class CommissionCollectedIncomePeriod {
  const CommissionCollectedIncomePeriod({
    required this.from,
    required this.to,
    required this.preset,
  });

  /// Día inclusivo (sin hora) en calendario Caracas.
  final DateTime from;
  final DateTime to;
  final CommissionCollectedIncomePreset preset;

  bool get isInvalidRange => from.isAfter(to);

  int get inclusiveDayCount {
    final a = DateTime(from.year, from.month, from.day);
    final b = DateTime(to.year, to.month, to.day);
    return b.difference(a).inDays + 1;
  }

  CommissionCollectedIncomePeriod get previousEquivalent {
    final span = inclusiveDayCount - 1;
    final prevTo = DateTime(from.year, from.month, from.day)
        .subtract(const Duration(days: 1));
    final prevFrom = prevTo.subtract(Duration(days: span));
    return CommissionCollectedIncomePeriod(
      from: prevFrom,
      to: prevTo,
      preset: CommissionCollectedIncomePreset.custom,
    );
  }

  String get labelEs {
    String fmt(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    if (preset == CommissionCollectedIncomePreset.today) {
      return 'Hoy (${fmt(from)})';
    }
    return '${fmt(from)} — ${fmt(to)}';
  }

  String toDateParam(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static DateTime dateOnlyCaracas([DateTime? utcNow]) {
    final wall = BcvReferenceRateService.caracasWallClock(utcNow);
    return DateTime(wall.year, wall.month, wall.day);
  }

  static CommissionCollectedIncomePeriod fromPreset(
    CommissionCollectedIncomePreset preset, {
    DateTime? utcNow,
    DateTime? customFrom,
    DateTime? customTo,
  }) {
    final today = dateOnlyCaracas(utcNow);
    switch (preset) {
      case CommissionCollectedIncomePreset.today:
        return CommissionCollectedIncomePeriod(
          from: today,
          to: today,
          preset: preset,
        );
      case CommissionCollectedIncomePreset.last7Days:
        return CommissionCollectedIncomePeriod(
          from: today.subtract(const Duration(days: 6)),
          to: today,
          preset: preset,
        );
      case CommissionCollectedIncomePreset.thisMonth:
        return CommissionCollectedIncomePeriod(
          from: DateTime(today.year, today.month, 1),
          to: today,
          preset: preset,
        );
      case CommissionCollectedIncomePreset.previousMonth:
        final firstThis = DateTime(today.year, today.month, 1);
        final lastPrev = firstThis.subtract(const Duration(days: 1));
        return CommissionCollectedIncomePeriod(
          from: DateTime(lastPrev.year, lastPrev.month, 1),
          to: lastPrev,
          preset: preset,
        );
      case CommissionCollectedIncomePreset.custom:
        final from = customFrom == null
            ? today
            : DateTime(customFrom.year, customFrom.month, customFrom.day);
        final to = customTo == null
            ? today
            : DateTime(customTo.year, customTo.month, customTo.day);
        return CommissionCollectedIncomePeriod(
          from: from,
          to: to,
          preset: preset,
        );
    }
  }
}
