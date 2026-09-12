import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/utils/app_date_format.dart';
import 'package:motolink_pro_app/features/kyc/kyc_status.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';
import 'package:motolink_pro_app/features/profile/profile_role_labels.dart';

/// Ficha de contacto y datos fiscales para el owner (Cuentas y KYC).
class OwnerAccountDossier extends StatelessWidget {
  const OwnerAccountDossier({
    super.key,
    required this.profile,
    this.title,
    this.showAuthEmail = true,
    this.isSelf = false,
  });

  final ProfileModel profile;
  final String? title;

  /// El correo de Auth solo lo ve el owner.
  final bool showAuthEmail;

  final bool isSelf;

  bool get _isImportador =>
      profile.role?.trim().toLowerCase() == 'importador';

  bool get _isAliado => profile.role?.trim().toLowerCase() == 'aliado';

  @override
  Widget build(BuildContext context) {
    final email = profile.email?.trim();
    final phone = profile.phone?.trim();
    final rif = profile.rif?.trim();
    final location = [
      profile.estado?.trim(),
      profile.ciudad?.trim(),
    ].whereType<String>().where((s) => s.isNotEmpty).join(' · ');
    final address = profile.direccion?.trim();
    final maps = profile.fiscalMapsUrl?.trim();
    final note = profile.accountReviewNote?.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null && title!.trim().isNotEmpty) ...[
          Text(
            title!.trim(),
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
        ],
        _PlainRow(
          label: 'Rol',
          value: [
            ProfileRoleLabels.labelEs(profile.role),
            if (isSelf) 'su cuenta',
          ].join(' · '),
        ),
        if (showAuthEmail)
          _CopyRow(
            label: 'Correo',
            value: email,
            emptyLabel: 'Sin correo de acceso',
          ),
        _CopyRow(
          label: 'Teléfono',
          value: phone,
          emptyLabel: 'Sin teléfono',
        ),
        if (rif != null && rif.isNotEmpty) _PlainRow(label: 'RIF', value: rif),
        if (location.isNotEmpty)
          _PlainRow(label: 'Ubicación', value: location),
        if (address != null && address.isNotEmpty)
          _PlainRow(label: 'Dirección', value: address),
        if (maps != null && maps.isNotEmpty) ...[
          const SizedBox(height: 2),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () async {
                final uri = Uri.tryParse(maps);
                if (uri == null) return;
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              },
              icon: const Icon(Icons.map_outlined, size: 18),
              label: const Text('Ver en Google Maps'),
            ),
          ),
        ],
        if (_isAliado) ...[
          const SizedBox(height: 4),
          _PlainRow(
            label: 'KYC',
            value: KycStatus.labelEs(profile.kycStatus),
          ),
        ],
        if (profile.pedidosSuspendidosMorosidad) ...[
          const SizedBox(height: 4),
          Text(
            'Nuevos pedidos suspendidos por morosidad',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: Colors.red.shade800,
            ),
          ),
        ],
        if (profile.createdAt != null) ...[
          const SizedBox(height: 4),
          _PlainRow(
            label: 'Alta',
            value: formatEsShortDateTime(profile.createdAt),
          ),
        ],
        if (_isImportador) ...[
          const SizedBox(height: 12),
          Text(
            'Referencia legal',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.borderSubtle),
              borderRadius: BorderRadius.circular(8),
              color: AppColors.brandBlueContainer,
            ),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: profile.hasLegalContact
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.legalContactName!.trim(),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          profile.legalContactEmail!.trim(),
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          profile.legalContactPhone!.trim(),
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    )
                  : Text(
                      'Sin referencia legal completa.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: AppColors.textSecondary,
                      ),
                    ),
            ),
          ),
        ],
        const SizedBox(height: 8),
        Text(
          profile.hasAcceptedCurrentTerms
              ? 'Términos y privacidad: aceptados'
              : 'Términos y privacidad: pendientes',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: profile.hasAcceptedCurrentTerms
                ? AppColors.successGreen
                : AppColors.textSecondary,
          ),
        ),
        if (note != null && note.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Nota: $note',
            style: TextStyle(
              fontSize: 12.5,
              color: Colors.red.shade800,
            ),
          ),
        ],
      ],
    );
  }
}

class _PlainRow extends StatelessWidget {
  const _PlainRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        '$label: $value',
        style: TextStyle(
          fontSize: 13,
          height: 1.35,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _CopyRow extends StatelessWidget {
  const _CopyRow({
    required this.label,
    required this.value,
    required this.emptyLabel,
  });

  final String label;
  final String? value;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    final v = value?.trim();
    if (v == null || v.isEmpty) {
      return _PlainRow(label: label, value: emptyLabel);
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$label: $v',
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Copiar $label',
            visualDensity: VisualDensity.compact,
            iconSize: 18,
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: v));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$label copiado'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            icon: const Icon(Icons.copy_outlined),
          ),
        ],
      ),
    );
  }
}
