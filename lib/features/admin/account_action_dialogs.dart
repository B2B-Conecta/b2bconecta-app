import 'package:flutter/material.dart';

import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';
import 'package:motolink_pro_app/features/admin/admin_users_chrome.dart';
import 'package:motolink_pro_app/features/admin/unified_action_dialog.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';

const _suspendReasons = [
  'Inactividad',
  'Solicitud del cliente',
  'Documentación incompleta',
  'Revisión de seguridad',
];

const _deactivateReasons = [
  'Inactividad',
  'Solicitud del cliente',
  'Cierre de operaciones',
  'Documentación incompleta',
];

/// Suspende el acceso temporalmente (bloqueo / rejected) sin liberar el correo.
Future<String?> showSuspendAccessDialog({
  required BuildContext context,
  required ProfileModel profile,
}) {
  return UnifiedActionDialog.show<String>(
    context: context,
    builder: (ctx) => _ReasonActionDialog(
      profile: profile,
      title: 'Suspender acceso temporalmente',
      subtitle:
          'La cuenta no podrá iniciar sesión. El historial y el correo se conservan.',
      glyph: LucideGlyph.circlePause,
      tone: UnifiedActionTone.warning,
      primaryLabel: 'Suspender acceso',
      fieldLabel: 'Motivo de la suspensión',
      fieldHint: 'Explique por qué se pausa el acceso…',
      chips: _suspendReasons,
    ),
  );
}

/// Baja administrativa: congela acceso, conserva auditoría y reserva el correo.
Future<String?> showDeactivateAccountDialog({
  required BuildContext context,
  required ProfileModel profile,
}) {
  return UnifiedActionDialog.show<String>(
    context: context,
    builder: (ctx) => _ReasonActionDialog(
      profile: profile,
      title: 'Desactivar cuenta',
      subtitle:
          'Se congela el acceso y se conserva el historial. El correo permanece '
          'reservado para auditoría fiscal.',
      glyph: LucideGlyph.userMinus,
      tone: UnifiedActionTone.warning,
      primaryLabel: 'Desactivar cuenta',
      fieldLabel: 'Motivo de la desactivación',
      fieldHint: 'Quedará registrado en el expediente…',
      chips: _deactivateReasons,
    ),
  );
}

/// Reactiva o habilita el acceso de una cuenta.
Future<bool?> showReactivateAccountDialog({
  required BuildContext context,
  required ProfileModel profile,
  required bool firstActivate,
}) {
  final who = profile.businessName?.trim().isNotEmpty == true
      ? profile.businessName!.trim()
      : (profile.email ?? 'esta cuenta');
  return UnifiedActionDialog.show<bool>(
    context: context,
    builder: (ctx) => UnifiedActionDialog(
      title: firstActivate ? 'Activar cuenta' : 'Restablecer acceso',
      subtitle: firstActivate
          ? '¿Habilitar $who con el expediente ya cargado? Podrá entrar sin '
              'repetir el registro inicial.'
          : '¿Restablecer el acceso de $who a la plataforma?',
      glyph: LucideGlyph.circlePlay,
      tone: UnifiedActionTone.info,
      profile: profile,
      primaryLabel: firstActivate ? 'Activar cuenta' : 'Restablecer acceso',
      onPrimary: () => Navigator.of(ctx).pop(true),
      body: const Text(
        'Esta acción solo afecta el acceso. Los datos fiscales y el historial '
        'no se modifican.',
        style: TextStyle(
          fontSize: 13,
          height: 1.45,
          color: Color(0xFF475569),
        ),
      ),
    ),
  );
}

class _ReasonActionDialog extends StatefulWidget {
  const _ReasonActionDialog({
    required this.profile,
    required this.title,
    required this.subtitle,
    required this.glyph,
    required this.tone,
    required this.primaryLabel,
    required this.fieldLabel,
    required this.fieldHint,
    required this.chips,
  });

  final ProfileModel profile;
  final String title;
  final String subtitle;
  final LucideGlyph glyph;
  final UnifiedActionTone tone;
  final String primaryLabel;
  final String fieldLabel;
  final String fieldHint;
  final List<String> chips;

  @override
  State<_ReasonActionDialog> createState() => _ReasonActionDialogState();
}

class _ReasonActionDialogState extends State<_ReasonActionDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  bool get _canConfirm => _ctrl.text.trim().length >= 3;

  @override
  Widget build(BuildContext context) {
    return UnifiedActionDialog(
      title: widget.title,
      subtitle: widget.subtitle,
      glyph: widget.glyph,
      tone: widget.tone,
      profile: widget.profile,
      primaryLabel: widget.primaryLabel,
      primaryEnabled: _canConfirm,
      onPrimary: () => Navigator.of(context).pop(_ctrl.text.trim()),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _ctrl,
            autofocus: true,
            maxLines: 3,
            style: const TextStyle(fontSize: 13),
            decoration: AdminUsersChrome.field(
              label: widget.fieldLabel,
              hint: widget.fieldHint,
            ),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) {
              if (_canConfirm) {
                Navigator.of(context).pop(_ctrl.text.trim());
              }
            },
          ),
          const SizedBox(height: 10),
          Text(
            'Sugerencias rápidas',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AdminUsersChrome.muted,
            ),
          ),
          const SizedBox(height: 6),
          UnifiedReasonChips(
            options: widget.chips,
            onSelected: (value) => setState(() => _ctrl.text = value),
          ),
        ],
      ),
    );
  }
}
