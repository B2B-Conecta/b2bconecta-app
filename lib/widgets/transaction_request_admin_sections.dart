import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/document_type_preference.dart';
import '../models/pago_metodo.dart';
import '../models/pago_revision_estado.dart';
import '../models/transaction_request_model.dart';
import '../models/transaction_request_status.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_date_format.dart';
import 'transaction_request_counterparty_profile_section.dart';
Future<void> _launchSignedOrderDoc(
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

/// Contacto B2B del aliado y del importador en un pedido.
class TransactionRequestPartiesContactSection extends StatelessWidget {
  const TransactionRequestPartiesContactSection({
    super.key,
    required this.request,
  });

  final TransactionRequestModel request;

  @override
  Widget build(BuildContext context) {
    final r = request;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Contacto',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        TransactionRequestCounterpartyProfileSection(
          profileId: r.aliadoId,
          partyLabel: 'Aliado',
          businessName: r.aliadoBusinessName,
          rif: r.aliadoRif,
          phone: r.aliadoPhone,
          estado: r.aliadoEstado,
          ciudad: r.aliadoCiudad,
          direccion: r.aliadoDireccion,
          fiscalMapsUrl: r.aliadoFiscalMapsUrl,
          logoStoragePath: r.aliadoLogoStoragePath,
          kycStatus: r.aliadoKycStatus,
        ),
        const SizedBox(height: 10),
        TransactionRequestCounterpartyProfileSection(
          profileId: r.ownerId,
          partyLabel: 'Importador',
          businessName: r.ownerBusinessName,
          rif: r.ownerRif,
          phone: r.ownerPhone,
          estado: r.ownerEstado,
          ciudad: r.ownerCiudad,
          direccion: r.ownerDireccion,
          fiscalMapsUrl: r.ownerFiscalMapsUrl,
          logoStoragePath: r.ownerLogoStoragePath,
          kycStatus: r.ownerKycStatus,
        ),
      ],
    );
  }
}

/// Solo el aliado (vista importador en pedidos).
class TransactionRequestAliadoContactSection extends StatelessWidget {
  const TransactionRequestAliadoContactSection({
    super.key,
    required this.request,
  });

  final TransactionRequestModel request;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Datos del aliado',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TransactionRequestCounterpartyProfileSection(
          profileId: request.aliadoId,
          partyLabel: 'Aliado',
          businessName: request.aliadoBusinessName,
          rif: request.aliadoRif,
          phone: request.aliadoPhone,
          estado: request.aliadoEstado,
          ciudad: request.aliadoCiudad,
          direccion: request.aliadoDireccion,
          fiscalMapsUrl: request.aliadoFiscalMapsUrl,
          logoStoragePath: request.aliadoLogoStoragePath,
          kycStatus: request.aliadoKycStatus,
        ),
      ],
    );
  }
}

/// Importador — vista aliado (una línea `transaction_requests` por proveedor).
class TransactionRequestImporterContactSection extends StatelessWidget {
  const TransactionRequestImporterContactSection({
    super.key,
    required this.request,
  });

  final TransactionRequestModel request;

  @override
  Widget build(BuildContext context) {
    final r = request;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Datos del importador',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TransactionRequestCounterpartyProfileSection(
          profileId: r.ownerId,
          partyLabel: 'Importador',
          businessName: r.ownerBusinessName,
          rif: r.ownerRif,
          phone: r.ownerPhone,
          estado: r.ownerEstado,
          ciudad: r.ownerCiudad,
          direccion: r.ownerDireccion,
          fiscalMapsUrl: r.ownerFiscalMapsUrl,
          logoStoragePath: r.ownerLogoStoragePath,
          kycStatus: r.ownerKycStatus,
        ),
      ],
    );
  }
}

/// A6: valoración del aliado tras entrega (reportes gerenciales).
class TransactionRequestAliadoExperienceAdminSection extends StatelessWidget {
  const TransactionRequestAliadoExperienceAdminSection({
    super.key,
    required this.request,
  });

  final TransactionRequestModel request;

  @override
  Widget build(BuildContext context) {
    final r = request;
    final at = r.aliadoExperienceSubmittedAt;
    final stars = r.aliadoExperienceStars;
    final comment = r.aliadoExperienceComment?.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Valoración del aliado (post-entrega)',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          decoration: BoxDecoration(
            color: at != null ? Colors.purple.shade50 : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: at != null
                  ? Colors.purple.shade200
                  : Colors.grey.shade300,
            ),
          ),
          child: at == null
              ? Text(
                  'Sin valoración: el aliado aún no envió calificación ni comentario para este pedido.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: Colors.grey.shade800,
                    fontWeight: FontWeight.w500,
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        ...List.generate(5, (i) {
                          final filled = (stars ?? 0) > i;
                          return Icon(
                            filled ? Icons.star : Icons.star_border,
                            size: 20,
                            color: Colors.amber.shade800,
                          );
                        }),
                        const SizedBox(width: 8),
                        Text(
                          '${stars ?? 0}/5',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: Colors.purple.shade900,
                          ),
                        ),
                      ],
                    ),
                    if (comment != null && comment.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        comment,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.35,
                          color: Colors.purple.shade900,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      'Registrado: ${formatEsShortDateTime(at)}',
                      style: TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: Colors.purple.shade800,
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

/// A6: preferencia de documento del aliado (instrucción para administración / IVA).
class TransactionRequestDocumentPreferenceAdminSection extends StatelessWidget {
  const TransactionRequestDocumentPreferenceAdminSection({
    super.key,
    required this.request,
  });

  final TransactionRequestModel request;

  @override
  Widget build(BuildContext context) {
    final p = request.documentTypePreference?.trim();
    final String label = p != null && p.isNotEmpty
        ? (DocumentTypePreference.labelEs(p) ?? p)
        : 'Pendiente: el aliado aún no indicó nota de entrega o factura fiscal.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Preferencia de documento (A6)',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          decoration: BoxDecoration(
            color: p != null && p.isNotEmpty
                ? Colors.indigo.shade50
                : Colors.amber.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: p != null && p.isNotEmpty
                  ? Colors.indigo.shade200
                  : Colors.amber.shade300,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                p != null && p.isNotEmpty
                    ? Icons.description_outlined
                    : Icons.pending_actions_outlined,
                size: 20,
                color: p != null && p.isNotEmpty
                    ? Colors.indigo.shade900
                    : Colors.amber.shade900,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                    color: p != null && p.isNotEmpty
                        ? Colors.indigo.shade900
                        : Colors.amber.shade900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Destino de entrega indicado por el aliado al solicitar el pedido.
class TransactionRequestDestinoEntregaSection extends StatelessWidget {
  const TransactionRequestDestinoEntregaSection({
    super.key,
    required this.request,
  });

  final TransactionRequestModel request;

  @override
  Widget build(BuildContext context) {
    final r = request;
    final usa = r.destinoEntregaUsaPerfil;
    final texto = r.destinoEntregaTexto?.trim();
    final fiscalBloque = r.aliadoDireccionFiscalMultilineaEs;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Destino de entrega',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        if (usa) ...[
          if (fiscalBloque != null && fiscalBloque.isNotEmpty)
            Text(
              fiscalBloque,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade800,
                height: 1.4,
              ),
            )
          else
            Text(
              'Dirección fiscal del aliado aún no disponible en esta vista.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade700,
                height: 1.35,
              ),
            ),
        ] else ...[
          Text(
            texto != null && texto.isNotEmpty
                ? texto
                : 'Otro destino (sin texto guardado)',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade800,
              height: 1.35,
            ),
          ),
        ],
      ],
    );
  }
}

/// Enlaces firmados a facturas y comprobantes (MotoLink / admin): referencia durante y después del ciclo.
class TransactionRequestEvidenceDocumentsSection extends StatelessWidget {
  const TransactionRequestEvidenceDocumentsSection({
    super.key,
    required this.request,
  });

  final TransactionRequestModel request;

  @override
  Widget build(BuildContext context) {
    final r = request;
    final chips = <Widget>[];

    if (r.hasProveedorFactura && r.proveedorFacturaStoragePath != null) {
      final path = r.proveedorFacturaStoragePath!.trim();
      chips.add(
        OutlinedButton.icon(
          onPressed: () => _launchSignedOrderDoc(
            context,
            () => SupabaseService.createSignedUrlForOrderInvoice(path),
          ),
          icon: const Icon(Icons.receipt_long_outlined, size: 18),
          label: Text(
            r.proveedorFacturaFileName?.trim().isNotEmpty == true
                ? 'Factura proveedor · ${r.proveedorFacturaFileName}'
                : 'Factura proveedor',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }
    if (r.hasFacturaAliado) {
      final moto = r.motolinkAllyInvoicesDescargables;
      if (moto.isNotEmpty) {
        for (final e in moto) {
          final path = e.storagePath?.trim();
          if (path == null || path.isEmpty) continue;
          chips.add(
            OutlinedButton.icon(
              onPressed: () => _launchSignedOrderDoc(
                context,
                () => SupabaseService.createSignedUrlForFacturaAliado(path),
              ),
              icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
              label: Text(
                'Factura MotoLink · ${e.downloadButtonLabel}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          );
        }
      } else if (r.facturaAliadoStoragePath != null) {
        final path = r.facturaAliadoStoragePath!.trim();
        chips.add(
          OutlinedButton.icon(
            onPressed: () => _launchSignedOrderDoc(
              context,
              () => SupabaseService.createSignedUrlForFacturaAliado(path),
            ),
            icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
            label: Text(
              r.facturaAliadoFileName?.trim().isNotEmpty == true
                  ? 'Factura MotoLink · ${r.facturaAliadoFileName}'
                  : 'Factura MotoLink al aliado',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      }
    }
    if (r.hasComprobantePago && r.comprobantePagoStoragePath != null) {
      final path = r.comprobantePagoStoragePath!.trim();
      chips.add(
        OutlinedButton.icon(
          onPressed: () => _launchSignedOrderDoc(
            context,
            () => SupabaseService.createSignedUrlForComprobantePago(path),
          ),
          icon: const Icon(Icons.account_balance_outlined, size: 18),
          label: Text(
            r.comprobantePagoFileName?.trim().isNotEmpty == true
                ? 'Comprobante de pago · ${r.comprobantePagoFileName}'
                : 'Comprobante de pago',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }
    if (r.hasEfectivoRespaldo && r.efectivoRespaldoStoragePath != null) {
      final path = r.efectivoRespaldoStoragePath!.trim();
      chips.add(
        OutlinedButton.icon(
          onPressed: () => _launchSignedOrderDoc(
            context,
            () => SupabaseService.createSignedUrlForEfectivoRespaldo(path),
          ),
          icon: const Icon(Icons.payments_outlined, size: 18),
          label: Text(
            r.efectivoRespaldoFileName?.trim().isNotEmpty == true
                ? 'Respaldo efectivo · ${r.efectivoRespaldoFileName}'
                : 'Respaldo cobro en efectivo',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }

    if (chips.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Documentación y evidencia',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Archivos del pedido (conservados al cerrar). Abrir con enlace temporal.',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade700, height: 1.25),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: chips,
        ),
      ],
    );
  }
}

/// Fechas por etapa del ciclo de envío.
class TransactionRequestLifecycleSection extends StatelessWidget {
  const TransactionRequestLifecycleSection({
    super.key,
    required this.request,
  });

  final TransactionRequestModel request;

  @override
  Widget build(BuildContext context) {
    final r = request;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ciclo del envío',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'El comprobante de pago y la aprobación de MotoLink quedan en el expediente del pedido '
          '(apartado «Factura y pago» del aliado, activo tras la factura MotoLink); no forman parte de este cronograma.',
          style: TextStyle(
            fontSize: 10.5,
            height: 1.35,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surfaceTinted.withOpacity(0.4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (r.status == TransactionRequestStatus.rechazado) ...[
                  _TimelineRow(
                    label: 'Solicitud registrada',
                    value: formatEsShortDateTime(r.createdAt),
                    isDone: r.createdAt != null,
                  ),
                  Divider(height: 16, thickness: 0.5, color: Colors.grey.shade300),
                  _TimelineRow(
                    label: r.anuladoPorMotolink
                        ? 'Anulado por MotoLink (post-aprobación)'
                        : (r.canceladoPorAliado
                            ? 'Cancelado por el aliado'
                            : 'Rechazado (MotoLink)'),
                    value: formatEsShortDateTime(r.atRechazado),
                    isDone: r.atRechazado != null,
                    highlight: true,
                  ),
                  if (r.anuladoPorMotolink &&
                      (r.motolinkAnulacionMotivo?.trim().isNotEmpty ?? false)) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Motivo (MotoLink): ${r.motolinkAnulacionMotivo!.trim()}',
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.35,
                        color: Colors.blueGrey.shade900,
                      ),
                    ),
                  ] else if (r.canceladoPorAliado &&
                      (r.aliadoCancelacionMotivo?.trim().isNotEmpty ?? false)) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Motivo: ${r.aliadoCancelacionMotivo!.trim()}',
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.35,
                        color: Colors.blueGrey.shade900,
                      ),
                    ),
                  ],
                ] else ...[
                  _TimelineRow(
                    label: 'Solicitud registrada',
                    value: formatEsShortDateTime(r.createdAt),
                    isDone: r.createdAt != null,
                  ),
                  Divider(height: 16, thickness: 0.5, color: Colors.grey.shade300),
                  _TimelineRow(
                    label: 'Aprobado por MotoLink',
                    value: formatEsShortDateTime(r.atAprobadoAdmin),
                    isDone: r.atAprobadoAdmin != null,
                    mutedIfEmpty: r.status == TransactionRequestStatus.pendiente,
                  ),
                  Divider(height: 16, thickness: 0.5, color: Colors.grey.shade300),
                  _TimelineRow(
                    label: 'En preparación (importador)',
                    value: _prepValue(r),
                    isDone: r.atEnPreparacion != null,
                  ),
                  Divider(height: 16, thickness: 0.5, color: Colors.grey.shade300),
                  _TimelineRow(
                    label: 'Pedido listo para recolección (importador)',
                    value: formatEsShortDateTime(r.atPedidoListo),
                    isDone: r.atPedidoListo != null,
                    highlight: r.status == TransactionRequestStatus.pedidoListo,
                  ),
                  Divider(height: 16, thickness: 0.5, color: Colors.grey.shade300),
                  _TimelineRow(
                    label: 'Factura MotoLink al aliado',
                    value: _facturaAliadoTimeline(r),
                    isDone: r.hasFacturaAliado,
                  ),
                  Divider(height: 16, thickness: 0.5, color: Colors.grey.shade300),
                  _TimelineRow(
                    label: 'Respaldo cobro en efectivo',
                    value: _efectivoRespaldoTimeline(r),
                    isDone: r.hasEfectivoRespaldo,
                    mutedIfEmpty: true,
                  ),
                  Divider(height: 16, thickness: 0.5, color: Colors.grey.shade300),
                  _TimelineRow(
                    label: 'En tránsito (MotoLink)',
                    value: _transitoValue(r),
                    isDone: r.atEnTransito != null,
                  ),
                  Divider(height: 16, thickness: 0.5, color: Colors.grey.shade300),
                  _TimelineRow(
                    label: 'Entregado',
                    value: _entregadoTimeline(r),
                    isDone: r.atEntregado != null,
                    highlight: r.status == TransactionRequestStatus.entregado,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  static String _entregadoTimeline(TransactionRequestModel r) {
    final d = formatEsShortDateTime(r.atEntregado);
    if (r.atEntregado == null) return '—';
    return '$d\nRecepción confirmada por el aliado en su taller';
  }

  static String _prepValue(TransactionRequestModel r) {
    final d = formatEsShortDateTime(r.atEnPreparacion);
    if (!r.hasProveedorFactura) return d;
    final fn = r.proveedorFacturaFileName?.trim();
    final extra = (fn != null && fn.isNotEmpty)
        ? '\nFactura digital: $fn'
        : '\nFactura digital enviada';
    final at = formatEsShortDateTime(r.proveedorFacturaSubmittedAt);
    final tail = at != '—' ? ' ($at)' : '';
    return '$d$extra$tail';
  }

  static String _transitoValue(TransactionRequestModel r) {
    final d = formatEsShortDateTime(r.atEnTransito);
    final eta = r.transitEtaResumenEs;
    if (eta == null) return d;
    return '$d\nEntrega estimada al aliado: $eta';
  }

  static String _facturaAliadoTimeline(TransactionRequestModel r) {
    if (!r.hasFacturaAliado) return '—';
    final fn = r.facturaAliadoFileName?.trim();
    final t = formatEsShortDateTime(r.facturaAliadoSubmittedAt);
    if (fn != null && fn.isNotEmpty) return '$fn\n$t';
    return t;
  }

  static String _efectivoRespaldoTimeline(TransactionRequestModel r) {
    if (r.pagoMetodo?.trim() != PagoMetodo.efectivo) return '—';
    if (!r.hasEfectivoRespaldo) {
      final pagoAprobado =
          r.pagoEstadoRevision?.trim() == PagoRevisionEstado.aprobado;
      if (pagoAprobado || r.status == TransactionRequestStatus.enTransito) {
        return 'Pendiente por registrar (MotoLink)';
      }
      return '—';
    }
    final fn = r.efectivoRespaldoFileName?.trim();
    final t = formatEsShortDateTime(r.efectivoRespaldoSubmittedAt);
    if (fn != null && fn.isNotEmpty) return '$fn\n$t';
    return t;
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.label,
    required this.value,
    required this.isDone,
    this.mutedIfEmpty = false,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool isDone;
  final bool mutedIfEmpty;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final empty = value == '—';
    final color = highlight
        ? Colors.green.shade800
        : (empty && mutedIfEmpty)
            ? Colors.grey.shade500
            : AppColors.textPrimary;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(
            isDone ? Icons.check_circle : Icons.circle_outlined,
            size: 18,
            color: isDone ? Colors.green.shade700 : Colors.grey.shade400,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.15,
                  color: color,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: empty ? Colors.grey.shade600 : Colors.grey.shade800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Comisión MotoLink (Minuta #7 C1): tasa, estimada y devengada al Recibido.
class TransactionRequestCommissionSection extends StatelessWidget {
  const TransactionRequestCommissionSection({
    super.key,
    required this.request,
  });

  final TransactionRequestModel request;

  @override
  Widget build(BuildContext context) {
    final r = request;
    final pct = (r.commissionRateSnapshot * 100).toStringAsFixed(2);
    final devengada = r.comisionDevengada;
    final monto = devengada
        ? (r.comisionDevengadaUsd ?? r.comisionEstimadaUsd)
        : r.comisionEstimadaUsd;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: Colors.teal.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.teal.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Comisión MotoLink',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            'Tasa $pct % · ${devengada ? 'Devengada' : 'Pendiente de recibir'}: '
            'USD ${monto.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 12, height: 1.35),
          ),
          if (devengada && r.comisionDevengadaAt != null)
            Text(
              'Devengada: ${formatEsShortDateTime(r.comisionDevengadaAt)}',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
            ),
          if (r.commissionSettlementId != null)
            Text(
              'Incluida en corte ${r.commissionSettlementId!.substring(0, 8)}…',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
            ),
        ],
      ),
    );
  }
}
