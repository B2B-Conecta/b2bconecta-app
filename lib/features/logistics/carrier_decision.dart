/// Decisión del aliado sobre usar transportista de la plataforma (`transaction_requests.carrier_decision`).
abstract final class CarrierDecision {
  static const pending = 'pending';
  static const selected = 'selected';
  static const skipped = 'skipped';
  static const notApplicable = 'not_applicable';

  static String labelEs(String? raw) => switch (raw?.trim()) {
        pending => 'Pendiente',
        selected => 'Transportista elegido',
        skipped => 'Sin transportista de la plataforma',
        notApplicable => 'Sin transportistas en catálogo',
        _ => '—',
      };

  static bool isResolved(String? raw) =>
      raw == selected || raw == skipped || raw == notApplicable;
}
