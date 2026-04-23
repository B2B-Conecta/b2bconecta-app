import 'package:flutter/material.dart';

import '../models/aliado_doc_type.dart';
import '../models/cash_phase_policy.dart';
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
        oldWidget.profile?.creditLimit != widget.profile?.creditLimit ||
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
          final docs = snap.data ?? [];
          return _AliadoAuthorizationCard(
            profile: p,
            documents: docs,
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
                  complete ? Icons.check_circle_outline : Icons.info_outline,
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
            _CheckRow(
              ok: complete,
              label: complete
                  ? 'Perfil B2B completo: puede gestionar inventario y pedidos validados.'
                  : 'Complete nombre del negocio, RIF y teléfono para operar con normalidad.',
            ),
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
    final faseContado = profile.esAliadoEnFaseContado;
    final tieneCupo = profile.tieneLineaCreditoMotoLink;
    final kycGlobal = profile.kycStatus?.trim();
    final kycOk = kycGlobal == KycStatus.aprobado;

    final cupoLabelEs = faseContado &&
            profile.puedeUsarLineaCreditoMotoLinkPreactivada
        ? 'MotoLink le habilitó el cupo desde el inicio (confianza): '
            '${profile.creditLimit!.toStringAsFixed(2)} USD. '
            'Puede usar la línea de crédito aun en fase contado. '
            '${(profile.creditoConsumidoAcumulado ?? 0).toStringAsFixed(2)} USD imputados acumulados (entregas a crédito sin plan, o al completar un plan a cuotas). '
            'El cupo restante se ve en su perfil.'
        : faseContado
            ? 'Primeros pedidos (contado): con RIF y domicilio fiscal puede pedir hasta '
                '${CashPhasePolicy.entregasRequeridas} entregas en esa modalidad. '
                'El cupo revolvente y la documentación completa se revisan al solicitar línea de crédito MotoLink.'
            : tieneCupo
                ? 'Cupo MotoLink ${profile.creditLimit!.toStringAsFixed(2)} USD · '
                    '${(profile.creditoConsumidoAcumulado ?? 0).toStringAsFixed(2)} USD imputados acumulados. '
                    'Compromiso, imputado y disponible se muestran en este perfil.'
                : 'Sin línea de crédito asignada: puede seguir solicitando repuestos pagando al contado '
                    '(transferencia o efectivo). MotoLink puede habilitar cupo y más medios de pago cuando lo solicite.';

    final kycLabelEs = faseContado && !kycOk
        ? 'Verificación documental: ${KycStatus.labelEs(kycGlobal)}. '
            'No bloquea pedidos en contado mientras tenga RIF y domicilio fiscal; '
            'la revisión completa de documentos aplica al solicitar crédito MotoLink.'
        : (kycOk
            ? 'Verificación documental aprobada (todos los documentos requeridos).'
            : 'Verificación documental: ${KycStatus.labelEs(kycGlobal)}.');

    // La fila resume cupo; operar al contado tras la fase inicial no requiere límite asignado.
    const cupoRowOk = true;
    final kycRowOk = faseContado || kycOk;

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
                  kycRowOk && cupoRowOk
                      ? Icons.check_circle_outline
                      : Icons.info_outline,
                  size: 22,
                  color: AppColors.brandBlue,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Estado para pedir repuestos (aliado)',
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
                  ? 'Perfil B2B completo.'
                  : 'Complete los datos fiscales y de contacto del perfil.',
            ),
            const SizedBox(height: 6),
            _CheckRow(
              ok: cupoRowOk,
              label: cupoLabelEs,
            ),
            const SizedBox(height: 6),
            _CheckRow(
              ok: kycRowOk,
              label: kycLabelEs,
            ),
            const SizedBox(height: 10),
            const Text(
              'Documentos (revisión individual)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            ...AliadoDocType.all.map((type) {
              final d = _docFor(type);
              final st = d?.reviewStatus?.trim();
              final line = d == null
                  ? 'Sin archivo — ${AliadoDocType.labelEs(type)}'
                  : '${AliadoDocType.labelEs(type)}: ${DocumentReviewStatus.labelEs(st ?? DocumentReviewStatus.pendiente)}';
              final docOk = st == DocumentReviewStatus.aprobado;
              final note = d?.reviewNote?.trim();
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      docOk ? Icons.check_circle : Icons.radio_button_off,
                      size: 16,
                      color: docOk ? AppColors.successGreen : Colors.grey.shade600,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            line,
                            style: const TextStyle(
                              fontSize: 12,
                              height: 1.35,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (note != null && note.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              'MotoLink: $note',
                              style: TextStyle(
                                fontSize: 11,
                                height: 1.35,
                                fontStyle: FontStyle.italic,
                                color: Colors.orange.shade900,
                              ),
                            ),
                          ],
                        ],
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
