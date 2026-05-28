import '../config/motolink_fiscal_issuer_constants.dart';
import '../models/commission_settlement_model.dart';

/// Cálculo fiscal unificado para cortes de comisión MotoLink (base + IVA 16%).
abstract final class CommissionSettlementFiscal {
  static double get ivaPct => MotolinkFiscalIssuerConstants.commissionIvaPct;

  static double roundUsd(double v) {
    if (v.isNaN || v.isInfinite) return 0;
    return (v * 100).roundToDouble() / 100;
  }

  static double baseImponibleUsd(CommissionSettlementModel s) =>
      roundUsd(s.totalCommissionUsd);

  static double ivaUsd(CommissionSettlementModel s) =>
      roundUsd(baseImponibleUsd(s) * (ivaPct / 100.0));

  static double totalFacturaUsd(CommissionSettlementModel s) =>
      roundUsd(baseImponibleUsd(s) + ivaUsd(s));

  static double totalVentasInformativoUsd(
    List<CommissionSettlementLineModel> lines,
  ) =>
      roundUsd(
        lines.fold<double>(0, (sum, l) => sum + l.precioTotalUsd),
      );
}

extension CommissionSettlementFiscalX on CommissionSettlementModel {
  double get baseImponibleComisionUsd =>
      CommissionSettlementFiscal.baseImponibleUsd(this);

  double get ivaComisionUsd =>
      isDeliveryNote ? 0 : CommissionSettlementFiscal.ivaUsd(this);

  double get totalFacturaUsd => isDeliveryNote
      ? baseImponibleComisionUsd
      : CommissionSettlementFiscal.totalFacturaUsd(this);

  /// Monto que debe pagar el importador según tipo de documento.
  double get totalCobroUsd => totalFacturaUsd;

  String get totalCobroLabelEs => isDeliveryNote
      ? 'Total neto (sin IVA)'
      : 'Total a pagar (IVA incl.)';
}
