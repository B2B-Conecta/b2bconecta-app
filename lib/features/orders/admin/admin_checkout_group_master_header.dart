import 'package:flutter/material.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';

import 'package:motolink_pro_app/features/orders/shared/transaction_request_model.dart';
import 'package:motolink_pro_app/features/orders/shared/admin_order_panel_utils.dart';
import 'package:motolink_pro_app/features/reputation/order_rating_eligibility.dart';
import 'package:motolink_pro_app/features/orders/shared/order_card_collapsible_layout.dart';
import 'transaction_request_admin_sections.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_counterparty_profile_section.dart';

/// Cabecera unificada de un carrito admin: aliado, destino y valoración (comisión por proveedor).
class AdminCheckoutGroupMasterHeader extends StatelessWidget {
  const AdminCheckoutGroupMasterHeader({
    super.key,
    required this.lines,
    this.onMutated,
  });

  final List<TransactionRequestModel> lines;
  final VoidCallback? onMutated;

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) return const SizedBox.shrink();
    final r = lines.first;
    TransactionRequestModel? expLine;
    for (final x in lines) {
      if (x.aliadoExperienceSubmittedAt != null) {
        expLine = x;
        break;
      }
    }
    if (expLine == null) {
      for (final x in lines) {
        if (lineaElegibleValoracionAliado(x)) {
          expLine = x;
          break;
        }
      }
    }
    expLine ??= lines.first;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          adminCheckoutGroupResumenLinea(lines),
          style: TextStyle(
            fontSize: 12,
            height: 1.35,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: kOrderCardSectionGap),
        OrderCardCollapsibleSection(
          title: 'Aliado',
          subtitle: orderCardPartySubtitle(
            businessName: r.aliadoBusinessName,
            ciudad: r.aliadoCiudad,
            estado: r.aliadoEstado,
          ),
          infoMessage: 'Taller solicitante del carrito y estado KYC.',
          child: TransactionRequestCounterpartyProfileSection(
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
        ),
        const SizedBox(height: kOrderCardSectionGap),
        OrderCardCollapsibleSection(
          title: 'Entrega',
          subtitle: r.destinoEntregaLineaCompactaEs,
          child: TransactionRequestDestinoEntregaSection(
            request: r,
            hideSectionTitle: true,
          ),
        ),
        if (expLine.aliadoExperienceSubmittedAt != null ||
            lineaElegibleValoracionAliado(expLine)) ...[
          const SizedBox(height: kOrderCardSectionGap),
          OrderCardCollapsibleSection(
            title: 'Valoración del aliado',
            subtitle: expLine.aliadoExperienceStars != null
                ? '${expLine.aliadoExperienceStars}/5 post-entrega'
                : (expLine.aliadoExperienceSubmittedAt != null
                    ? 'Sin estrellas'
                    : 'Pendiente — admin puede registrar'),
            child: TransactionRequestAliadoExperienceAdminSection(
              request: expLine,
              hideSectionTitle: true,
              onMutated: onMutated,
            ),
          ),
        ],
        if (lineaElegibleValoracionImportador(expLine)) ...[
          const SizedBox(height: kOrderCardSectionGap),
          OrderCardCollapsibleSection(
            title: 'Valoración del mayorista',
            subtitle: 'Al aliado de este pedido',
            child: TransactionRequestImporterRatingAdminSection(
              request: expLine,
              onMutated: onMutated,
            ),
          ),
        ],
      ],
    );
  }
}
