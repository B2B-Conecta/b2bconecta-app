import 'package:flutter/material.dart';

import '../models/transaction_request_model.dart';
import '../models/transaction_request_status.dart';
import '../utils/ves_amount_format.dart';
import 'importer_aliado_solicitud_section.dart';
import 'order_commission_summary.dart';
import 'profile_section_helpers.dart';

export '../utils/order_flow_copy/order_section_help.dart';

/// Espaciado estándar entre bloques colapsables dentro de una ficha expandida.
const double kOrderCardSectionGap = 8;

/// Subtítulo de una línea para nombre + ubicación de contraparte.
String orderCardPartySubtitle({
  String? businessName,
  String? ciudad,
  String? estado,
}) {
  final name = businessName?.trim();
  final loc = [
    if (ciudad?.trim().isNotEmpty == true) ciudad!.trim(),
    if (estado?.trim().isNotEmpty == true) estado!.trim(),
  ].join(', ');
  if (name != null && name.isNotEmpty && loc.isNotEmpty) {
    return '$name · $loc';
  }
  if (name != null && name.isNotEmpty) return name;
  if (loc.isNotEmpty) return loc;
  return 'Ver datos de contacto';
}

/// Resumen de productos para subtítulo de sección.
String orderCardProductosSubtitle(
  List<TransactionRequestModel> lines, {
  required PedidoDesgloseViewer viewer,
}) {
  if (lines.isEmpty) return 'Sin partidas';
  final uds = lines.fold<int>(0, (a, r) => a + r.cantidad);
  final totalRef = lines.fold<double>(0, (a, r) => a + r.precioTotal);
  final n = lines.length;
  final partidas = n == 1 ? '1 partida' : '$n partidas';
  return '$partidas · $uds uds · ${formatRefAmount(totalRef)} REF';
}

/// Subtítulo de comisión B2B Conecta (importador).
String? orderCardCommissionSubtitle(List<TransactionRequestModel> lines) {
  final eligible = orderLinesEligibleForCommission(lines);
  if (eligible.isEmpty) return null;
  final total = eligible.fold<double>(
    0,
    (s, r) => s + (r.comisionDevengadaUsd ?? r.comisionEstimadaUsd),
  );
  final devengada = eligible.every((r) => r.comisionDevengada);
  return 'USD ${total.toStringAsFixed(2)} · ${devengada ? 'devengada' : 'estimada'}';
}

/// Etapa actual para subtítulo del seguimiento.
String orderCardTimelineSubtitle(
  TransactionRequestModel r, {
  bool aliadoViewer = false,
}) {
  final label = r.statusLabelEs(aliadoViewer: aliadoViewer);
  if (r.hasTransitEta &&
      (r.status == TransactionRequestStatus.enTransito ||
          r.status == TransactionRequestStatus.enviado)) {
    return '$label · ETA ${r.transitEtaResumenEs}';
  }
  return label;
}

bool orderCardTimelineInitiallyExpanded(TransactionRequestModel r) {
  return r.status != TransactionRequestStatus.entregado &&
      r.status != TransactionRequestStatus.rechazado;
}

/// Bloque colapsable reutilizable en fichas de pedido.
class OrderCardCollapsibleSection extends StatelessWidget {
  const OrderCardCollapsibleSection({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    this.initiallyExpanded = false,
    this.infoMessage,
    this.infoTitle,
    this.trailingActions = const [],
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final bool initiallyExpanded;
  final String? infoMessage;
  final String? infoTitle;
  final List<Widget> trailingActions;

  @override
  Widget build(BuildContext context) {
    return ProfileCollapsibleSection(
      title: title,
      subtitle: subtitle,
      initiallyExpanded: initiallyExpanded,
      infoMessage: infoMessage,
      infoTitle: infoTitle ?? title,
      trailingActions: trailingActions,
      child: child,
    );
  }
}

/// Avisos breves en la cabecera colapsada (sin cajas grandes).
class OrderCardCompactNoticeChip extends StatelessWidget {
  const OrderCardCompactNoticeChip({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 14, color: color),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
      backgroundColor: color.withOpacity(0.08),
      side: BorderSide(color: color.withOpacity(0.35)),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
