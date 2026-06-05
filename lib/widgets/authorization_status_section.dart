import 'package:flutter/material.dart';

import '../models/aliado_doc_type.dart';
import '../models/document_review_status.dart';
import '../models/kyc_status.dart';
import '../models/profile_document_model.dart';
import '../models/profile_model.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';

/// Resumen de lo que falta para operar (importador o aliado).
class AuthorizationStatusSection extends StatefulWidget {
  const AuthorizationStatusSection({
    super.key,
    required this.profile,
  });

  final ProfileModel? profile;

  @override
  State<AuthorizationStatusSection> createState() =>
      _AuthorizationStatusSectionState();
}

class _AuthorizationStatusSectionState extends State<AuthorizationStatusSection> {
  Future<List<ProfileDocumentModel>>? _docsFuture;

  @override
  void initState() {
    super.initState();
    _reloadDocs();
  }

  @override
  void didUpdateWidget(covariant AuthorizationStatusSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile?.id != widget.profile?.id ||
        oldWidget.profile?.kycStatus != widget.profile?.kycStatus ||
        oldWidget.profile?.pedidosSuspendidosMorosidad !=
            widget.profile?.pedidosSuspendidosMorosidad) {
      _reloadDocs();
    }
  }

  void _reloadDocs() {
    final role = widget.profile?.role?.trim().toLowerCase();
    if (role == 'aliado') {
      setState(() {
        _docsFuture = SupabaseService.fetchMyProfileDocuments();
      });
    } else {
      setState(() => _docsFuture = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    if (p == null) return const SizedBox.shrink();

    final role = p.role?.trim().toLowerCase();
    if (role == 'importador') {
      return _ImportadorAuthorizationCard(profile: p);
    }
    if (role == 'aliado') {
      return FutureBuilder<List<ProfileDocumentModel>>(
        future: _docsFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }
          return _AliadoAuthorizationCard(
            profile: p,
            documents: snap.data ?? [],
          );
        },
      );
    }
    return const SizedBox.shrink();
  }
}

class _ImportadorAuthorizationCard extends StatelessWidget {
  const _ImportadorAuthorizationCard({required this.profile});

  final ProfileModel profile;

  @override
  Widget build(BuildContext context) {
    final complete = profile.isComplete;
    final operacionLabelEs = complete
        ? 'Perfil B2B completo: puede gestionar inventario y pedidos.'
        : 'Complete nombre, RIF, domicilio fiscal y enlace Google Maps.';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.brandBlueContainer,
        borderRadius: AppDecorations.radius12,
        border: Border.all(color: AppColors.brandBlue.withOpacity(0.22)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  complete
                      ? Icons.check_circle_outline
                      : Icons.info_outline,
                  size: 22,
                  color: AppColors.brandBlue,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Estado para operar (importador)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.brandBlue,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _CheckRow(ok: complete, label: operacionLabelEs),
          ],
        ),
      ),
    );
  }
}

class _AliadoAuthorizationCard extends StatelessWidget {
  const _AliadoAuthorizationCard({
    required this.profile,
    required this.documents,
  });

  final ProfileModel profile;
  final List<ProfileDocumentModel> documents;

  ProfileDocumentModel? _docFor(String type) {
    for (final d in documents) {
      if (d.docType == type) return d;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final kycGlobal = profile.kycStatus?.trim();
    final kycOk = kycGlobal == KycStatus.aprobado;

    final kycLabelEs = kycOk
        ? 'Verificación documental aprobada.'
        : 'Verificación: ${KycStatus.labelEs(kycGlobal)}.';

    const operacionRowOk = true;
    final kycRowOk = kycOk;
    final docTypes = AliadoDocType.forRole('aliado');

    ProfileDocumentModel? docForType(String type) {
      if (type == AliadoDocType.cedulaPropietario) {
        for (final d in documents) {
          if (AliadoDocType.isCedulaAliadoDoc(d.docType)) return d;
        }
        return null;
      }
      return _docFor(type);
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.brandBlueContainer,
        borderRadius: AppDecorations.radius12,
        border: Border.all(color: AppColors.brandBlue.withOpacity(0.22)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  kycRowOk && operacionRowOk && profile.isComplete
                      ? Icons.check_circle_outline
                      : Icons.info_outline,
                  size: 20,
                  color: AppColors.brandBlue,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Estado del aliado',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.brandBlue,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (profile.pedidosSuspendidosMorosidad) ...[
              Material(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.block, color: Colors.red.shade800, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'MotoLink suspendió la creación de nuevos pedidos por morosidad. '
                          'Regularice los pagos en pedidos entregados; cuando reactivemos su cuenta, '
                          'podrá volver a solicitar en el catálogo.',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                            color: Colors.red.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            _CheckRow(
              ok: profile.isComplete,
              label: profile.isComplete
                  ? 'RIF, dirección fiscal y Maps completos.'
                  : 'Complete RIF, dirección fiscal y enlace Google Maps.',
            ),
            const SizedBox(height: 4),
            _CheckRow(ok: kycRowOk, label: kycLabelEs),
            const SizedBox(height: 8),
            ...docTypes.map((type) {
              final d = docForType(type);
              final st = d?.reviewStatus?.trim();
              final docOk = st == DocumentReviewStatus.aprobado;
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(
                      docOk ? Icons.check_circle : Icons.radio_button_off,
                      size: 15,
                      color: docOk ? AppColors.successGreen : Colors.grey.shade600,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        d == null
                            ? AliadoDocType.labelEs(type)
                            : '${AliadoDocType.labelEs(type)} · ${DocumentReviewStatus.labelEs(st ?? DocumentReviewStatus.pendiente)}',
                        style: const TextStyle(
                          fontSize: 11,
                          height: 1.3,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.ok, required this.label});

  final bool ok;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          ok ? Icons.check_circle : Icons.warning_amber_rounded,
          size: 18,
          color: ok ? AppColors.successGreen : Colors.orange.shade800,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              height: 1.35,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
