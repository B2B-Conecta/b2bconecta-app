import 'package:flutter/material.dart';

import '../models/document_review_status.dart';
import '../models/kyc_status.dart';
import '../theme/app_theme.dart';

/// Borde de tarjeta por estado de revisión de un documento (admin y aliado).
Color kycDocumentReviewTileBorderColor({required bool has, String? status}) {
  if (!has) return Colors.grey.shade300;
  switch (status) {
    case DocumentReviewStatus.aprobado:
      return const Color(0xFFA5D6A7);
    case DocumentReviewStatus.rechazado:
      return const Color(0xFFEF9A9A);
    case DocumentReviewStatus.enRevision:
      return const Color(0xFFFFCC80);
    case DocumentReviewStatus.pendiente:
      return AppColors.brandBlue.withOpacity(0.35);
    default:
      return Colors.grey.shade300;
  }
}

/// Resalta el estado de revisión por archivo (misma lógica que revisión admin).
class KycDocumentReviewStatusHighlight extends StatelessWidget {
  const KycDocumentReviewStatusHighlight({
    super.key,
    required this.statusLabel,
    required this.hasFile,
    required this.effectiveStatus,
  });

  final String statusLabel;
  final bool hasFile;
  final String? effectiveStatus;

  @override
  Widget build(BuildContext context) {
    if (!hasFile) {
      return _statusPill(
        backgroundColor: Colors.grey.shade200,
        foregroundColor: Colors.grey.shade800,
        borderColor: Colors.grey.shade400,
        icon: Icons.folder_off_outlined,
        label: statusLabel,
        emphasized: false,
      );
    }
    switch (effectiveStatus) {
      case DocumentReviewStatus.aprobado:
        return _statusPill(
          backgroundColor: const Color(0xFFE8F5E9),
          foregroundColor: const Color(0xFF1B5E20),
          borderColor: const Color(0xFF66BB6A),
          icon: Icons.verified_outlined,
          label: statusLabel,
          emphasized: true,
        );
      case DocumentReviewStatus.rechazado:
        return _statusPill(
          backgroundColor: const Color(0xFFFFEBEE),
          foregroundColor: const Color(0xFFB71C1C),
          borderColor: const Color(0xFFE57373),
          icon: Icons.gpp_bad_outlined,
          label: statusLabel,
          emphasized: true,
        );
      case DocumentReviewStatus.enRevision:
        return _statusPill(
          backgroundColor: const Color(0xFFFFF3E0),
          foregroundColor: const Color(0xFFE65100),
          borderColor: const Color(0xFFFFB74D),
          icon: Icons.pending_actions_outlined,
          label: statusLabel,
          emphasized: true,
        );
      default:
        return _statusPill(
          backgroundColor: AppColors.brandBlueContainer,
          foregroundColor: AppColors.brandBlue,
          borderColor: AppColors.brandBlue.withOpacity(0.38),
          icon: Icons.edit_note_outlined,
          label: statusLabel,
          emphasized: false,
        );
    }
  }

  Widget _statusPill({
    required Color backgroundColor,
    required Color foregroundColor,
    required Color borderColor,
    required IconData icon,
    required String label,
    required bool emphasized,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: borderColor,
          width: emphasized ? 1.5 : 1.1,
        ),
        boxShadow: emphasized
            ? [
                BoxShadow(
                  color: foregroundColor.withOpacity(0.18),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 22, color: foregroundColor),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: emphasized ? 13.5 : 12.8,
                  fontWeight: emphasized ? FontWeight.w800 : FontWeight.w700,
                  height: 1.3,
                  color: foregroundColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Estado KYC global del aliado (`profiles.kyc_status`), mismo criterio visual que el panel admin.
class KycAliadoGlobalStatusHighlight extends StatelessWidget {
  const KycAliadoGlobalStatusHighlight({
    super.key,
    required this.kycStatus,
  });

  final String? kycStatus;

  @override
  Widget build(BuildContext context) {
    final s = kycStatus?.trim();
    final label = 'Estado general: ${KycStatus.labelEs(s)}';
    switch (s) {
      case KycStatus.aprobado:
        return _globalPill(
          label: label,
          backgroundColor: const Color(0xFFE8F5E9),
          foregroundColor: const Color(0xFF1B5E20),
          borderColor: const Color(0xFF66BB6A),
          icon: Icons.verified_outlined,
          emphasized: true,
        );
      case KycStatus.rechazado:
        return _globalPill(
          label: label,
          backgroundColor: const Color(0xFFFFEBEE),
          foregroundColor: const Color(0xFFB71C1C),
          borderColor: const Color(0xFFE57373),
          icon: Icons.gpp_bad_outlined,
          emphasized: true,
        );
      case KycStatus.enRevision:
        return _globalPill(
          label: label,
          backgroundColor: const Color(0xFFFFF3E0),
          foregroundColor: const Color(0xFFE65100),
          borderColor: const Color(0xFFFFB74D),
          icon: Icons.fact_check_outlined,
          emphasized: true,
        );
      default:
        return _globalPill(
          label: label,
          backgroundColor: AppColors.brandBlueContainer,
          foregroundColor: AppColors.brandBlue,
          borderColor: AppColors.brandBlue.withOpacity(0.38),
          icon: Icons.description_outlined,
          emphasized: false,
        );
    }
  }

  Widget _globalPill({
    required String label,
    required Color backgroundColor,
    required Color foregroundColor,
    required Color borderColor,
    required IconData icon,
    required bool emphasized,
  }) {
    return SizedBox(
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor, width: emphasized ? 1.5 : 1.1),
          boxShadow: emphasized
              ? [
                  BoxShadow(
                    color: foregroundColor.withOpacity(0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 22, color: foregroundColor),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: emphasized ? 13.5 : 13,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                    color: foregroundColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Chip compacto para cabeceras en filas estrechas (sin [Expanded] interno).
class KycCompactStatusChip extends StatelessWidget {
  const KycCompactStatusChip({super.key, required this.kycStatus});

  final String? kycStatus;

  @override
  Widget build(BuildContext context) {
    final s = kycStatus?.trim();
    final (bg, fg, border) = switch (s) {
      KycStatus.aprobado => (
          const Color(0xFFE8F5E9),
          const Color(0xFF1B5E20),
          const Color(0xFF66BB6A),
        ),
      KycStatus.rechazado => (
          const Color(0xFFFFEBEE),
          const Color(0xFFB71C1C),
          const Color(0xFFE57373),
        ),
      KycStatus.enRevision => (
          const Color(0xFFFFF3E0),
          const Color(0xFFE65100),
          const Color(0xFFFFB74D),
        ),
      _ => (
          AppColors.brandBlueContainer,
          AppColors.brandBlue,
          AppColors.brandBlue.withOpacity(0.38),
        ),
    };
    return Chip(
      label: Text(
        KycStatus.labelEs(s),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
      backgroundColor: bg,
      side: BorderSide(color: border),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: EdgeInsets.zero,
    );
  }
}
