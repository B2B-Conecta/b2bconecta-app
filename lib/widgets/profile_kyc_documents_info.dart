import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Documentación orientativa para verificación (persona natural / jurídica).
class ProfileKycDocumentsInfo extends StatelessWidget {
  const ProfileKycDocumentsInfo({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.brandBlueContainer,
        borderRadius: AppDecorations.radius12,
        border: Border.all(
          color: AppColors.brandBlue.withOpacity(0.22),
        ),
      ),
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.folder_open_outlined,
                  size: 22,
                  color: AppColors.brandBlue,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Documentos básicos de identificación',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      height: 1.3,
                      color: AppColors.brandBlue,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 14),
            Text(
              'Persona natural (cliente o proveedor individual)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 8),
            _KycBullet(
              'Cédula de identidad legible (frente y dorso), vigente.',
            ),
            _KycBullet(
              'RIF actualizado (si actúa como vendedor o presta servicios gravados al IVA).',
            ),
            SizedBox(height: 14),
            Text(
              'Persona jurídica (empresa)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 8),
            _KycBullet(
              'RIF empresarial y certificado de registro mercantil o de la Cámara de Comercio, con fecha reciente.',
            ),
            _KycBullet(
              'Copia de la cédula de identidad del representante legal y, en algunos casos, poder notarial.',
            ),
          ],
        ),
      ),
    );
  }
}

class _KycBullet extends StatelessWidget {
  const _KycBullet(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '• ',
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: Colors.grey.shade700,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                height: 1.45,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
