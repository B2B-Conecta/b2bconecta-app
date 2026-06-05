import 'package:flutter/material.dart';

import '../models/aliado_doc_type.dart';
import '../models/profile_document_model.dart';
import '../models/profile_model.dart';
import '../theme/app_theme.dart';

/// Checklist compacto: datos del formulario + documentos mínimos del aliado.
class AliadoProfileRequirementsBanner extends StatelessWidget {
  const AliadoProfileRequirementsBanner({
    super.key,
    required this.profile,
    required this.documents,
  });

  final ProfileModel? profile;
  final List<ProfileDocumentModel> documents;

  bool _hasDoc(String type) =>
      documents.any((d) => d.docType == type && d.isCurrent);

  bool get _hasCedula =>
      documents.any((d) => AliadoDocType.isCedulaAliadoDoc(d.docType));

  @override
  Widget build(BuildContext context) {
    final p = profile;
    final rifOk = p?.rif?.trim().isNotEmpty == true;
    final ubicOk = p?.hasRegisteredLocation == true;
    final mapsOk = p?.hasFiscalMapsShareLink == true;
    final fotoOk = _hasDoc(AliadoDocType.fotoTienda);
    final regOk = _hasDoc(AliadoDocType.registroMercantil);

    Widget row(String label, bool ok) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            Icon(
              ok ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 16,
              color: ok ? AppColors.successGreen : Colors.grey.shade500,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.25,
                  color: ok ? Colors.grey.shade800 : Colors.grey.shade600,
                  fontWeight: ok ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.brandBlueContainer.withOpacity(0.55),
        borderRadius: AppDecorations.radius12,
        border: Border.all(color: AppColors.brandBlue.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Registro inicial — requisitos para ingresar',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.brandBlue,
              ),
            ),
            const SizedBox(height: 8),
            row('RIF', rifOk),
            row('Dirección fiscal (estado, ciudad y domicilio)', ubicOk),
            row('Enlace de Google Maps', mapsOk),
            row('Foto de la tienda', fotoOk),
            row('Cédula del propietario', _hasCedula),
            row('Registro mercantil / cámara', regOk),
          ],
        ),
      ),
    );
  }
}
