import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:motolink_pro_app/features/payments/document_type_preference.dart';
import 'package:motolink_pro_app/features/payments/pago_metodo.dart';
import 'package:motolink_pro_app/features/payments/pago_revision_estado.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_model.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_status.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/utils/app_date_format.dart';
import 'package:motolink_pro_app/features/orders/shared/b2b_orders_panel_layout.dart';
import 'package:motolink_pro_app/features/reputation/order_rating_eligibility.dart';
import 'package:motolink_pro_app/features/reputation/admin_order_rating_sheet.dart';
import 'package:motolink_pro_app/features/commissions/order_commission_summary.dart';
import 'package:motolink_pro_app/features/kyc/kyc_approved_aliado_model.dart';
import 'package:motolink_pro_app/features/kyc/kyc_status.dart';
import 'package:motolink_pro_app/features/kyc/importer_kyc_approved_aliados_panel.dart';
import 'package:motolink_pro_app/features/orders/shared/order_card_collapsible_layout.dart';
import 'package:motolink_pro_app/features/profile/profile_section_helpers.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_counterparty_profile_section.dart';

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
    this.embedded = false,
  });

  final TransactionRequestModel request;
  final bool embedded;

  static String partiesSubtitle(TransactionRequestModel r) {
    final aliado = r.aliadoBusinessName?.trim();
    final imp = r.ownerBusinessName?.trim();
    if (aliado != null &&
        aliado.isNotEmpty &&
        imp != null &&
        imp.isNotEmpty) {
      return '$aliado · $imp';
    }
    return aliado ?? imp ?? 'Ver contacto B2B';
  }

  @override
  Widget build(BuildContext context) {
    final r = request;
    final aliadoProfile = TransactionRequestCounterpartyProfileSection(
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
          loadApprovedDocuments: !embedded,
        );
    final importadorProfile = TransactionRequestCounterpartyProfileSection(
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
      loadApprovedDocuments: false,
    );

    if (embedded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          aliadoProfile,
          const SizedBox(height: 10),
          importadorProfile,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Contacto',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        aliadoProfile,
        const SizedBox(height: 10),
        importadorProfile,
      ],
    );
  }
}

/// Solo el aliado (vista importador en pedidos).
class TransactionRequestAliadoContactSection extends StatelessWidget {
  const TransactionRequestAliadoContactSection({
    super.key,
    required this.request,
    this.embedded = false,
  });

  final TransactionRequestModel request;
  final bool embedded;

  static bool kycAprobadoPara(TransactionRequestModel r) =>
      r.aliadoKycStatus?.trim() == KycStatus.aprobado;

  static KycApprovedAliadoModel kycModelPara(TransactionRequestModel r) =>
      KycApprovedAliadoModel(
        id: r.aliadoId,
        businessName: r.aliadoBusinessName,
        rif: r.aliadoRif,
        phone: r.aliadoPhone,
        estado: r.aliadoEstado,
        ciudad: r.aliadoCiudad,
        direccion: r.aliadoDireccion,
        fiscalMapsUrl: r.aliadoFiscalMapsUrl,
        logoStoragePath: r.aliadoLogoStoragePath,
        kycStatus: r.aliadoKycStatus,
      );

  @override
  Widget build(BuildContext context) {
    final r = request;
    final profile = TransactionRequestCounterpartyProfileSection(
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
      loadApprovedDocuments: !embedded,
    );

    if (embedded) return profile;

    final kycAprobado = kycAprobadoPara(r);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Datos del aliado',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            if (kycAprobado)
              TextButton.icon(
                onPressed: () => showImporterAliadoKycDetailSheet(
                  context,
                  aliado: kycModelPara(r),
                ),
                icon: const Icon(Icons.verified_user_outlined, size: 18),
                label: const Text('Expediente KYC'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        profile,
      ],
    );
  }
}

/// Importador — vista aliado (una línea `transaction_requests` por proveedor).
class TransactionRequestImporterContactSection extends StatelessWidget {
  const TransactionRequestImporterContactSection({
    super.key,
    required this.request,
    this.embedded = false,
  });

  final TransactionRequestModel request;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final r = request;
    final profile = TransactionRequestCounterpartyProfileSection(
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
      loadApprovedDocuments: false,
    );

    if (embedded) return profile;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Datos del importador',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        profile,
      ],
    );
  }
}

/// A6: valoración del aliado tras entrega (reportes gerenciales).
/// Si falta y el pedido es elegible, el admin puede registrar en nombre del aliado.
class TransactionRequestAliadoExperienceAdminSection extends StatelessWidget {
  const TransactionRequestAliadoExperienceAdminSection({
    super.key,
    required this.request,
    this.hideSectionTitle = false,
    this.onMutated,
  });

  final TransactionRequestModel request;
  final bool hideSectionTitle;
  final VoidCallback? onMutated;

  @override
  Widget build(BuildContext context) {
    final r = request;
    final at = r.aliadoExperienceSubmittedAt;
    final stars = r.aliadoExperienceStars;
    final comment = r.aliadoExperienceComment?.trim();
    final canAdminRate = at == null &&
        onMutated != null &&
        lineaElegibleValoracionAliado(r);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!hideSectionTitle) ...[
          Text(
            'Valoración del aliado (post-entrega)',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
        ],
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          decoration: BoxDecoration(
            color: at != null
                ? Colors.purple.shade50
                : AppColors.brandBlueContainer,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: at != null
                  ? Colors.purple.shade200
                  : AppColors.borderSubtle,
            ),
          ),
          child: at == null
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Sin valoración: el aliado aún no envió calificación '
                      'ni comentario para este pedido.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (canAdminRate) ...[
                      const SizedBox(height: 10),
                      FilledButton.icon(
                        onPressed: () => showAdminOrderRatingSheet(
                          context,
                          request: r,
                          raterRole: 'aliado',
                          onSubmitted: () => onMutated?.call(),
                        ),
                        icon: const Icon(Icons.star_outline, size: 18),
                        label: const Text('Valorar como administración'),
                      ),
                    ],
                  ],
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

/// Valoración importador → aliado: pendiente o CTA admin si aún no calificó.
class TransactionRequestImporterRatingAdminSection extends StatefulWidget {
  const TransactionRequestImporterRatingAdminSection({
    super.key,
    required this.request,
    this.onMutated,
  });

  final TransactionRequestModel request;
  final VoidCallback? onMutated;

  @override
  State<TransactionRequestImporterRatingAdminSection> createState() =>
      _TransactionRequestImporterRatingAdminSectionState();
}

class _TransactionRequestImporterRatingAdminSectionState
    extends State<TransactionRequestImporterRatingAdminSection> {
  bool _loading = true;
  bool _hasRated = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(
    covariant TransactionRequestImporterRatingAdminSection oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.request.id != widget.request.id ||
        oldWidget.request.checkoutGroupId != widget.request.checkoutGroupId) {
      _load();
    }
  }

  Future<void> _load() async {
    final r = widget.request;
    final aliadoId = r.aliadoId.trim();
    final importadorId = r.ownerId.trim();
    if (aliadoId.isEmpty || importadorId.isEmpty) {
      setState(() {
        _loading = false;
        _hasRated = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final exists = await SupabaseService.orderRatingExistsForRater(
        raterRole: 'importador',
        importadorId: importadorId,
        aliadoId: aliadoId,
        checkoutGroupId: r.checkoutGroupId,
        transactionRequestId: r.id,
      );
      if (!mounted) return;
      setState(() {
        _hasRated = exists;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    final canAdminRate = !_hasRated &&
        !_loading &&
        widget.onMutated != null &&
        lineaElegibleValoracionImportador(r);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Valoración del mayorista (al aliado)',
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
            color: _hasRated
                ? AppColors.successGreen.withOpacity(0.12)
                : AppColors.brandBlueContainer,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: _loading
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              : _error != null
                  ? Text(
                      'No se pudo verificar: $_error',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red.shade800,
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _hasRated
                              ? 'El mayorista ya registró su valoración al aliado.'
                              : 'Sin valoración: el mayorista aún no calificó al aliado.',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.35,
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (canAdminRate) ...[
                          const SizedBox(height: 10),
                          FilledButton.icon(
                            onPressed: () => showAdminOrderRatingSheet(
                              context,
                              request: r,
                              raterRole: 'importador',
                              onSubmitted: () {
                                _load();
                                widget.onMutated?.call();
                              },
                            ),
                            icon: const Icon(Icons.star_outline, size: 18),
                            label: const Text('Valorar como administración'),
                          ),
                        ],
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
        Text(
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
    this.hideSectionTitle = false,
  });

  final TransactionRequestModel request;
  final bool hideSectionTitle;

  @override
  Widget build(BuildContext context) {
    final density = B2bOrderCardDensityScope.of(context);
    final r = request;
    final usa = r.destinoEntregaUsaPerfil;
    final texto = r.destinoEntregaTexto?.trim();
    final fiscalBloque = r.aliadoDireccionFiscalMultilineaEs;
    final bodySize = density.contentBodySize;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!hideSectionTitle) ...[
          Text(
            'Destino de entrega',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: density.contentTitleSize,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: density.isDesktop ? 4 : 6),
        ],
        if (usa) ...[
          if (fiscalBloque != null && fiscalBloque.isNotEmpty)
            Text(
              fiscalBloque,
              style: TextStyle(
                fontSize: bodySize,
                color: AppColors.textPrimary,
                height: 1.4,
              ),
            )
          else
            Text(
              'Dirección fiscal del aliado aún no disponible en esta vista.',
              style: TextStyle(
                fontSize: bodySize,
                color: AppColors.textSecondary,
                height: 1.35,
              ),
            ),
        ] else ...[
          Text(
            texto != null && texto.isNotEmpty
                ? texto
                : 'Otro destino (sin texto guardado)',
            style: TextStyle(
              fontSize: bodySize,
              color: AppColors.textPrimary,
              height: 1.35,
            ),
          ),
        ],
      ],
    );
  }
}

/// Enlaces firmados a facturas y comprobantes (B2B Conecta / admin): referencia durante y después del ciclo.
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
        const ProfileSectionHeader(
          label: 'DOCUMENTACIÓN Y EVIDENCIA',
          infoMessage: OrderSectionHelp.evidenciaPedido,
          infoTitle: 'Documentación y evidencia',
          padding: EdgeInsets.only(bottom: 10, top: 0),
        ),
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
        const ProfileSectionHeader(
          label: 'CICLO DEL ENVÍO',
          infoMessage: OrderSectionHelp.cicloEnvioPago,
          infoTitle: 'Ciclo del envío',
          padding: EdgeInsets.only(bottom: 8, top: 0),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surfaceTinted.withOpacity(0.4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderSubtle),
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
                  Divider(
                      height: 16, thickness: 0.5, color: AppColors.borderSubtle),
                  _TimelineRow(
                    label: r.anuladoPorMotolink
                        ? 'Anulado por B2B Conecta (post-aprobación)'
                        : (r.canceladoPorImportador
                            ? 'Cancelado por proveedor (importador)'
                            : (r.canceladoPorAliado
                                ? 'Cancelado por el aliado'
                                : 'Rechazado (B2B Conecta)')),
                    value: formatEsShortDateTime(r.atRechazado),
                    isDone: r.atRechazado != null,
                    highlight: true,
                  ),
                  if (r.anuladoPorMotolink &&
                      (r.motolinkAnulacionMotivo?.trim().isNotEmpty ??
                          false)) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Motivo (B2B Conecta): ${r.motolinkAnulacionMotivo!.trim()}',
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.35,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ] else if (r.canceladoPorImportador &&
                      (r.importadorCancelacionMotivo?.trim().isNotEmpty ??
                          false)) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Motivo (proveedor): ${r.importadorCancelacionMotivo!.trim()}',
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.35,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ] else if (r.canceladoPorAliado &&
                      (r.aliadoCancelacionMotivo?.trim().isNotEmpty ??
                          false)) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Motivo: ${r.aliadoCancelacionMotivo!.trim()}',
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.35,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ] else ...[
                  _TimelineRow(
                    label: 'Solicitud registrada',
                    value: formatEsShortDateTime(r.createdAt),
                    isDone: r.createdAt != null,
                  ),
                  Divider(
                      height: 16, thickness: 0.5, color: AppColors.borderSubtle),
                  _TimelineRow(
                    label: 'Aprobado por B2B Conecta',
                    value: formatEsShortDateTime(r.atAprobadoAdmin),
                    isDone: r.atAprobadoAdmin != null,
                    mutedIfEmpty:
                        r.status == TransactionRequestStatus.pendiente,
                  ),
                  Divider(
                      height: 16, thickness: 0.5, color: AppColors.borderSubtle),
                  _TimelineRow(
                    label: 'En preparación (importador)',
                    value: _prepValue(r),
                    isDone: r.atEnPreparacion != null,
                  ),
                  Divider(
                      height: 16, thickness: 0.5, color: AppColors.borderSubtle),
                  _TimelineRow(
                    label: 'Pedido listo para recolección (importador)',
                    value: formatEsShortDateTime(r.atPedidoListo),
                    isDone: r.atPedidoListo != null,
                    highlight: r.status == TransactionRequestStatus.pedidoListo,
                  ),
                  Divider(
                      height: 16, thickness: 0.5, color: AppColors.borderSubtle),
                  _TimelineRow(
                    label: 'Factura importador al aliado',
                    value: _facturaImportadorTimeline(r),
                    isDone: r.hasProveedorFactura,
                  ),
                  Divider(
                      height: 16, thickness: 0.5, color: AppColors.borderSubtle),
                  _TimelineRow(
                    label: 'Respaldo cobro en efectivo',
                    value: _efectivoRespaldoTimeline(r),
                    isDone: r.hasEfectivoRespaldo,
                    mutedIfEmpty: true,
                  ),
                  Divider(
                      height: 16, thickness: 0.5, color: AppColors.borderSubtle),
                  _TimelineRow(
                    label: 'En tránsito (B2B Conecta)',
                    value: _transitoValue(r),
                    isDone: r.atEnTransito != null,
                  ),
                  Divider(
                      height: 16, thickness: 0.5, color: AppColors.borderSubtle),
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

  static String _facturaImportadorTimeline(TransactionRequestModel r) {
    if (!r.hasProveedorFactura) return '—';
    final fn = r.proveedorFacturaFileName?.trim();
    final t = formatEsShortDateTime(r.proveedorFacturaSubmittedAt);
    if (fn != null && fn.isNotEmpty) return '$fn\n$t';
    return t;
  }

  static String _efectivoRespaldoTimeline(TransactionRequestModel r) {
    if (r.pagoMetodo?.trim() != PagoMetodo.efectivo) return '—';
    if (!r.hasEfectivoRespaldo) {
      final pagoAprobado =
          r.pagoEstadoRevision?.trim() == PagoRevisionEstado.aprobado;
      if (pagoAprobado || r.status == TransactionRequestStatus.enTransito) {
        return 'Pendiente por registrar (B2B Conecta)';
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
                  color: empty ? AppColors.textSecondary : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Comisión B2B Conecta (Minuta #7 C1). Delega en [OrderCommissionSummary].
@Deprecated('Use OrderCommissionSummary directly')
class TransactionRequestCommissionSection extends StatelessWidget {
  const TransactionRequestCommissionSection({
    super.key,
    required this.request,
  });

  final TransactionRequestModel request;

  @override
  Widget build(BuildContext context) {
    return OrderCommissionSummary(
      lines: orderLinesEligibleForCommission([request]),
    );
  }
}
