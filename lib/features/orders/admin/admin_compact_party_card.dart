import 'package:flutter/material.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/layout/admin_collapsible_section.dart';
import 'package:motolink_pro_app/features/catalog/importer_catalog_seals.dart';
import 'package:motolink_pro_app/features/kyc/kyc_status_highlight_widgets.dart';
import 'package:motolink_pro_app/features/onboarding/entrepreneur_badge_chip.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_counterparty_profile_section.dart';

/// Aliado en ficha admin: datos esenciales; detalle fiscal bajo demanda.
class AdminCompactAliadoCard extends StatelessWidget {
  const AdminCompactAliadoCard({
    super.key,
    required this.profileId,
    required this.businessName,
    this.rif,
    this.phone,
    this.estado,
    this.ciudad,
    this.direccion,
    this.fiscalMapsUrl,
    this.logoStoragePath,
    this.kycStatus,
    this.catalogVerifiedAt,
    this.showEntrepreneurBadge = false,
  });

  final String profileId;
  final String? businessName;
  final String? rif;
  final String? phone;
  final String? estado;
  final String? ciudad;
  final String? direccion;
  final String? fiscalMapsUrl;
  final String? logoStoragePath;
  final String? kycStatus;
  final DateTime? catalogVerifiedAt;
  final bool showEntrepreneurBadge;

  @override
  Widget build(BuildContext context) {
    return AdminCollapsibleSection(
      title: _CompactPartyHeader(
        label: 'Tienda minorista',
        name: businessName,
        kycStatus: kycStatus,
        catalogVerified: catalogVerifiedAt != null,
        showEntrepreneurBadge: showEntrepreneurBadge,
      ),
      subtitle: _subtitleWidget(),
      child: TransactionRequestCounterpartyProfileSection(
        profileId: profileId,
        partyLabel: 'Tienda minorista',
        businessName: businessName,
        rif: rif,
        phone: phone,
        estado: estado,
        ciudad: ciudad,
        direccion: direccion,
        fiscalMapsUrl: fiscalMapsUrl,
        logoStoragePath: logoStoragePath,
        kycStatus: kycStatus,
        catalogVerifiedAt: catalogVerifiedAt,
        showEntrepreneurBadge: showEntrepreneurBadge,
        loadApprovedDocuments: true,
      ),
    );
  }

  Widget? _subtitleWidget() {
    final line = _subtitleLine();
    if (line == null) return null;
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        line,
        style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
      ),
    );
  }

  String? _subtitleLine() {
    final parts = <String>[];
    final r = rif?.trim();
    final t = phone?.trim();
    if (r != null && r.isNotEmpty) parts.add('RIF $r');
    if (t != null && t.isNotEmpty) parts.add(t);
    return parts.isEmpty ? null : parts.join(' · ');
  }
}

/// Importador activo: una línea; datos fiscales si se expande (sin KYC).
class AdminCompactImportadorCard extends StatelessWidget {
  const AdminCompactImportadorCard({
    super.key,
    required this.profileId,
    required this.businessName,
    this.rif,
    this.phone,
    this.estado,
    this.ciudad,
    this.direccion,
    this.fiscalMapsUrl,
    this.logoStoragePath,
    this.catalogVerifiedAt,
    this.initiallyExpanded = false,
  });

  final String profileId;
  final String? businessName;
  final String? rif;
  final String? phone;
  final String? estado;
  final String? ciudad;
  final String? direccion;
  final String? fiscalMapsUrl;
  final String? logoStoragePath;
  final DateTime? catalogVerifiedAt;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return AdminCollapsibleSection(
      initiallyExpanded: initiallyExpanded,
      title: _CompactPartyHeader(
        label: 'Importador',
        name: businessName,
        catalogVerified: catalogVerifiedAt != null,
      ),
      subtitle: _subtitleWidget(),
      child: TransactionRequestCounterpartyProfileSection(
        profileId: profileId,
        partyLabel: 'Importador',
        businessName: businessName,
        rif: rif,
        phone: phone,
        estado: estado,
        ciudad: ciudad,
        direccion: direccion,
        fiscalMapsUrl: fiscalMapsUrl,
        logoStoragePath: logoStoragePath,
        catalogVerifiedAt: catalogVerifiedAt,
        loadApprovedDocuments: false,
      ),
    );
  }

  Widget? _subtitleWidget() {
    final line = _subtitleLine();
    if (line == null) return null;
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        line,
        style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
      ),
    );
  }

  String? _subtitleLine() {
    final parts = <String>[];
    final r = rif?.trim();
    final t = phone?.trim();
    if (r != null && r.isNotEmpty) parts.add('RIF $r');
    if (t != null && t.isNotEmpty) parts.add(t);
    return parts.isEmpty ? null : parts.join(' · ');
  }
}

class _CompactPartyHeader extends StatelessWidget {
  const _CompactPartyHeader({
    required this.label,
    required this.name,
    this.kycStatus,
    this.catalogVerified = false,
    this.showEntrepreneurBadge = false,
  });

  final String label;
  final String? name;
  final String? kycStatus;
  final bool catalogVerified;
  final bool showEntrepreneurBadge;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: AppColors.brandBlue,
          ),
        ),
        Text(
          name?.trim().isNotEmpty == true ? name!.trim() : '—',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
        if (showEntrepreneurBadge ||
            catalogVerified ||
            (kycStatus != null && kycStatus!.trim().isNotEmpty)) ...[
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (showEntrepreneurBadge)
                const EntrepreneurBadgeChip(compact: true),
              if (catalogVerified)
                const ImporterCatalogSealChip(
                  kind: ImporterCatalogSealKind.verified,
                  compact: true,
                ),
              if (kycStatus != null && kycStatus!.trim().isNotEmpty)
                KycCompactStatusChip(kycStatus: kycStatus),
            ],
          ),
        ],
      ],
    );
  }
}
