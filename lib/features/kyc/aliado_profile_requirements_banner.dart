import 'package:flutter/material.dart';

import 'aliado_doc_type.dart';
import 'profile_document_model.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';

/// Progreso de requisitos mínimos del aliado (perfil + documentos iniciales).
class AliadoProfileRequirementsProgress {
  const AliadoProfileRequirementsProgress({
    required this.done,
    required this.total,
    required this.rifOk,
    required this.ubicOk,
    required this.mapsOk,
    required this.fotoOk,
    required this.cedulaOk,
    required this.registroOk,
  });

  final int done;
  final int total;
  final bool rifOk;
  final bool ubicOk;
  final bool mapsOk;
  final bool fotoOk;
  final bool cedulaOk;
  final bool registroOk;

  bool get allComplete => done >= total;

  String get subtitle {
    if (allComplete) return 'Todos los requisitos completos';
    return '$done de $total completos';
  }

  static AliadoProfileRequirementsProgress compute({
    ProfileModel? profile,
    required List<ProfileDocumentModel> documents,
  }) {
    final p = profile;
    final rifOk = p?.rif?.trim().isNotEmpty == true;
    final ubicOk = p?.hasRegisteredLocation == true;
    final mapsOk = p?.hasFiscalMapsShareLink == true;
    final fotoOk =
        documents.any((d) => d.docType == AliadoDocType.fotoTienda && d.isCurrent);
    final cedulaOk =
        documents.any((d) => AliadoDocType.isCedulaAliadoDoc(d.docType));
    final regOk = documents
        .any((d) => d.docType == AliadoDocType.registroMercantil && d.isCurrent);

    final flags = [rifOk, ubicOk, mapsOk, fotoOk, cedulaOk, regOk];
    return AliadoProfileRequirementsProgress(
      done: flags.where((x) => x).length,
      total: flags.length,
      rifOk: rifOk,
      ubicOk: ubicOk,
      mapsOk: mapsOk,
      fotoOk: fotoOk,
      cedulaOk: cedulaOk,
      registroOk: regOk,
    );
  }
}

/// Checklist: datos del formulario + documentos mínimos del aliado.
class AliadoProfileRequirementsBanner extends StatelessWidget {
  const AliadoProfileRequirementsBanner({
    super.key,
    required this.profile,
    required this.documents,
    this.compact = false,
  });

  final ProfileModel? profile;
  final List<ProfileDocumentModel> documents;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final progress = AliadoProfileRequirementsProgress.compute(
      profile: profile,
      documents: documents,
    );

    Widget row(String label, bool ok) {
      return Padding(
        padding: EdgeInsets.only(bottom: compact ? 3 : 4),
        child: Row(
          children: [
            Icon(
              ok ? Icons.check_circle : Icons.radio_button_unchecked,
              size: compact ? 15 : 16,
              color: ok ? AppColors.successGreen : Colors.grey.shade500,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: compact ? 11 : 11.5,
                  height: 1.25,
                  color: ok ? AppColors.textPrimary : AppColors.textSecondary,
                  fontWeight: ok ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final checklist = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        row('RIF', progress.rifOk),
        row('Dirección fiscal (estado, ciudad y domicilio)', progress.ubicOk),
        row('Enlace de Google Maps', progress.mapsOk),
        row('Foto de la tienda', progress.fotoOk),
        row('Cédula del propietario', progress.cedulaOk),
        row('Registro mercantil / cámara', progress.registroOk),
      ],
    );

    if (compact) return checklist;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.brandBlueContainer.withOpacity(0.35),
        borderRadius: AppDecorations.radius12,
        border: Border.all(color: AppColors.brandBlue.withOpacity(0.15)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        child: checklist,
      ),
    );
  }
}
