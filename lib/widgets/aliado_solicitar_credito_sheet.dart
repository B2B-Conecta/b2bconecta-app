import 'package:flutter/material.dart';

import '../models/aliado_doc_type.dart';
import '../models/cash_phase_policy.dart';
import '../models/kyc_status.dart';
import '../models/profile_model.dart';
import '../theme/app_theme.dart';

/// Flujo UX: requisitos para línea MotoLink y listado de documentación.
abstract final class AliadoSolicitarCreditoSheet {
  static Future<void> show(
    BuildContext context, {
    required ProfileModel profile,
    /// Tras cerrar el sheet (p. ej. ir a documentación o mostrar aviso si faltan datos).
    required VoidCallback onContinuar,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final bottom = MediaQuery.paddingOf(ctx).bottom;
        final maxH = MediaQuery.sizeOf(ctx).height * 0.88;
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxH),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 16 + bottom),
            child: _SheetBody(
              profile: profile,
              onContinuar: () {
                Navigator.of(ctx).pop();
                onContinuar();
              },
            ),
          ),
        );
      },
    );
  }
}

class _SheetBody extends StatelessWidget {
  const _SheetBody({
    required this.profile,
    required this.onContinuar,
  });

  final ProfileModel profile;
  final VoidCallback onContinuar;

  bool get _rifOk {
    final r = profile.rif?.trim();
    return r != null && r.isNotEmpty;
  }

  bool get _ubicOk =>
      profile.hasRegisteredLocation && profile.hasFiscalMapsShareLink;

  int get _pce => profile.primerosPedidosContadoEntregados ?? 0;

  bool get _faseInicial =>
      profile.esAliadoEnFaseContado;

  bool get _entregasOk =>
      _pce >= CashPhasePolicy.entregasRequeridas;

  bool get _lineaAsignada =>
      profile.creditLimit != null && profile.creditLimit! > 0;

  bool get _kycAprobado => profile.kycStatus?.trim() == KycStatus.aprobado;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.brandBlue.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.account_balance_outlined,
                color: AppColors.brandBlue,
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Línea de crédito MotoLink',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (_lineaAsignada && !_faseInicial && _kycAprobado) ...[
          _InfoCallout(
            icon: Icons.check_circle_outline,
            color: AppColors.successGreen,
            child: Text(
              'Tiene un límite de crédito de '
              '${profile.creditLimit!.toStringAsFixed(2)} REF. '
              'Los pedidos a crédito consumen cupo según entregas y pedidos abiertos.',
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: Colors.grey.shade800,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ] else if (_lineaAsignada && _faseInicial) ...[
          _InfoCallout(
            icon: Icons.info_outline,
            color: AppColors.brandBlue,
            child: Text(
              'MotoLink puede tener registrado un cupo preliminar. '
              'Podrá usar la línea en pedidos al completar las '
              '${CashPhasePolicy.entregasRequeridas} entregas en contado y con KYC aprobado.',
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: Colors.grey.shade800,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        Text(
          _faseInicial
              ? 'Requisitos para habilitar la evaluación crediticia'
              : 'Siguiente paso: documentación y revisión MotoLink',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        _RequisitoRow(
          ok: _rifOk,
          titulo: 'RIF comercial',
          subtitulo: 'Debe figurar en su perfil.',
        ),
        _RequisitoRow(
          ok: _ubicOk,
          titulo: 'Domicilio fiscal',
          subtitulo: 'Estado, ciudad y dirección completos.',
        ),
        _RequisitoRow(
          ok: _entregasOk,
          titulo:
              'Primeros pedidos en contado (${CashPhasePolicy.entregasRequeridas} entregas)',
          subtitulo:
              'Progreso: $_pce / ${CashPhasePolicy.entregasRequeridas} entregas registradas.',
        ),
        if (_faseInicial) ...[
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: CashPhasePolicy.entregasRequeridas == 0
                  ? 0
                  : (_pce / CashPhasePolicy.entregasRequeridas).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: Colors.grey.shade200,
              color: AppColors.brand,
            ),
          ),
          const SizedBox(height: 4),
        ],
        const SizedBox(height: 8),
        Text(
          _faseInicial
              ? 'Mientras esté en esta fase puede pedir al contado (transferencia o efectivo) '
                  'con los datos mínimos anteriores. La documentación detallada aplica al '
                  'solicitar la línea MotoLink una vez cumplidos los requisitos.'
              : 'Con los requisitos de fase inicial cumplidos, cargue la documentación para que '
                  'MotoLink pueda evaluar y asignar (o activar) su línea de crédito.',
          style: TextStyle(
            fontSize: 12,
            height: 1.4,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Documentación solicitada por MotoLink',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Suba cada archivo en la sección «Documentación para revisión MotoLink» de este perfil.',
          style: TextStyle(
            fontSize: 12,
            height: 1.35,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 10),
        ...AliadoDocType.all.map(
          (t) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.description_outlined,
                  size: 18,
                  color: AppColors.brandBlue.withOpacity(0.85),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    AliadoDocType.labelEs(t),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (!_kycAprobado) ...[
          const SizedBox(height: 8),
          _InfoCallout(
            icon: Icons.schedule_outlined,
            color: Colors.orange.shade800,
            child: Text(
              'Estado KYC: ${KycStatus.labelEs(profile.kycStatus)}. '
              'MotoLink revisará tras enviar o actualizar documentos.',
              style: TextStyle(
                fontSize: 12,
                height: 1.35,
                color: Colors.grey.shade900,
              ),
            ),
          ),
        ],
        const SizedBox(height: 20),
        if (!_rifOk || !_ubicOk)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              'Complete primero RIF y domicilio fiscal en los campos de arriba; '
              'luego podrá cargar la documentación.',
              style: TextStyle(
                fontSize: 12,
                height: 1.35,
                color: Colors.orange.shade900,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        FilledButton.icon(
          onPressed: onContinuar,
          icon: const Icon(Icons.folder_open_outlined, size: 20),
          label: const Text('Ir a documentación en el perfil'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}

class _RequisitoRow extends StatelessWidget {
  const _RequisitoRow({
    required this.ok,
    required this.titulo,
    required this.subtitulo,
  });

  final bool ok;
  final String titulo;
  final String subtitulo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            ok ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 22,
            color: ok ? AppColors.successGreen : Colors.grey.shade400,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitulo,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.3,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCallout extends StatelessWidget {
  const _InfoCallout({
    required this.icon,
    required this.color,
    required this.child,
  });

  final IconData icon;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 10),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}
