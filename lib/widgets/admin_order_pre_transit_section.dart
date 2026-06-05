import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/transaction_request_model.dart';
import '../models/transaction_request_status.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import 'admin_pago_revision_section.dart';
import 'efectivo_respaldo_registrar.dart';

/// En preparación: factura del importador al aliado, pago y paso a tránsito.
class AdminOrderPreTransitSection extends StatefulWidget {
  const AdminOrderPreTransitSection({
    super.key,
    required this.request,
    required this.onRefresh,
    required this.onMarcarEnTransito,
  });

  final TransactionRequestModel request;
  final VoidCallback onRefresh;
  final VoidCallback onMarcarEnTransito;

  @override
  State<AdminOrderPreTransitSection> createState() =>
      _AdminOrderPreTransitSectionState();
}

class _AdminOrderPreTransitSectionState extends State<AdminOrderPreTransitSection> {
  Future<void> _openUrl(
    BuildContext context,
    Future<String> Function() signed,
  ) async {
    try {
      final url = await signed();
      final uri = Uri.parse(url);
      if (!context.mounted) return;
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir el enlace.')),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    final st = r.status;
    if (st != TransactionRequestStatus.aprobadoAdmin &&
        st != TransactionRequestStatus.enPreparacion &&
        st != TransactionRequestStatus.pedidoListo) {
      return const SizedBox.shrink();
    }

    final hasFacturaImportador = r.hasProveedorFactura;
    final puedeTransito =
        st == TransactionRequestStatus.pedidoListo && hasFacturaImportador;

    String? bloqueoTransito;
    if (st == TransactionRequestStatus.enPreparacion) {
      bloqueoTransito =
          'El importador debe marcar «Pedido listo» cuando la mercancía esté lista en despacho.';
    } else if (st == TransactionRequestStatus.aprobadoAdmin) {
      bloqueoTransito =
          'Falta que los importadores avancen a preparación/listo para habilitar el tránsito.';
    } else if (!hasFacturaImportador) {
      bloqueoTransito =
          'Falta la factura del importador al aliado (pestaña Pedidos del importador).';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 20),
        const Text(
          'Facturación y pago',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'La factura comercial la emite el importador. Tras registrarla, el aliado '
          'puede declarar pago; en tránsito solo con factura cargada.',
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade700,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 12),
        if (st == TransactionRequestStatus.enPreparacion) ...[
          Material(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.inventory_2_outlined, color: Colors.amber.shade900),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Espere «Pedido listo» del importador antes de retirar la carga.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                        color: Colors.amber.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        Text(
          'Factura del importador al aliado',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 4),
        if (hasFacturaImportador)
          OutlinedButton.icon(
            onPressed: () => _openUrl(
              context,
              () => SupabaseService.createSignedUrlForOrderInvoice(
                r.proveedorFacturaStoragePath!.trim(),
              ),
            ),
            icon: const Icon(Icons.open_in_new, size: 18),
            label: Text(r.proveedorFacturaFileName ?? 'Abrir factura'),
          )
        else
          Text(
            'Pendiente: el importador la adjunta en su pestaña Pedidos.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
        const SizedBox(height: 14),
        Text(
          'Pago del aliado',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 4),
        if (!hasFacturaImportador)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              'Sin factura del importador el aliado aún no puede enviar comprobante.',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
                height: 1.25,
              ),
            ),
          ),
        if (!hasFacturaImportador)
          Text(
            'Estado: ${AdminPagoRevisionSection.estadoPagoLabelEs(r)}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.brandBlue,
            ),
          ),
        if (hasFacturaImportador)
          AdminPagoRevisionSection(
            request: r,
            onRefresh: widget.onRefresh,
            includeSectionTitle: false,
          ),
        EfectivoRespaldoRegistrar(
          request: r,
          onRegistered: widget.onRefresh,
        ),
        const SizedBox(height: 14),
        Text(
          'Envío en tránsito',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 6),
        if (puedeTransito)
          FilledButton.icon(
            onPressed: widget.onMarcarEnTransito,
            icon: const Icon(Icons.local_shipping_outlined, size: 18),
            label: const Text('Marcar en tránsito'),
          )
        else
          Text(
            bloqueoTransito ?? 'Complete los pasos anteriores.',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade700,
              height: 1.25,
            ),
          ),
        const SizedBox(height: 12),
      ],
    );
  }
}
