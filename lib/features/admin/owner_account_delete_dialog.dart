import 'package:flutter/material.dart';

import 'package:motolink_pro_app/features/admin/owner_account_rules.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';
import 'package:motolink_pro_app/features/profile/profile_role_labels.dart';

enum OwnerAccountDeleteKind { soft, hard }

/// Popup de confirmación para baja lógica o borrado de Auth.
Future<String?> showOwnerAccountDeleteDialog({
  required BuildContext context,
  required ProfileModel profile,
  required OwnerAccountDeleteKind kind,
}) {
  return showDialog<String>(
    context: context,
    builder: (ctx) => _OwnerAccountDeleteDialog(
      profile: profile,
      kind: kind,
    ),
  );
}

class _OwnerAccountDeleteDialog extends StatefulWidget {
  const _OwnerAccountDeleteDialog({
    required this.profile,
    required this.kind,
  });

  final ProfileModel profile;
  final OwnerAccountDeleteKind kind;

  @override
  State<_OwnerAccountDeleteDialog> createState() =>
      _OwnerAccountDeleteDialogState();
}

class _OwnerAccountDeleteDialogState extends State<_OwnerAccountDeleteDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  bool get _isHard => widget.kind == OwnerAccountDeleteKind.hard;

  String get _who {
    final name = widget.profile.businessName?.trim();
    final email = widget.profile.email?.trim();
    if (name != null && name.isNotEmpty && email != null && email.isNotEmpty) {
      return '$name ($email)';
    }
    return email ?? name ?? widget.profile.id;
  }

  bool get _canConfirm {
    if (_isHard) {
      return OwnerAccountRules.hardDeleteConfirmMatches(
        typed: _ctrl.text,
        email: widget.profile.email,
      );
    }
    return _ctrl.text.trim().length >= 3;
  }

  @override
  Widget build(BuildContext context) {
    final role = ProfileRoleLabels.labelEs(widget.profile.role);
    return AlertDialog(
      title: Text(_isHard ? 'Borrar definitiva' : 'Eliminar cuenta'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isHard
                  ? 'Se borra el usuario de Auth y se libera el correo. '
                      'No se puede deshacer. Si la cuenta tiene pedidos, '
                      'use baja lógica.\n\n$_who · $role'
                  : 'Es una baja lógica: deja de entrar, el historial se '
                      'conserva y el correo no se libera.\n\n$_who · $role',
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _ctrl,
              autofocus: true,
              maxLines: _isHard ? 1 : 3,
              keyboardType:
                  _isHard ? TextInputType.emailAddress : TextInputType.text,
              decoration: InputDecoration(
                hintText: _isHard
                    ? 'Escriba el correo para confirmar…'
                    : 'Motivo (visible en la cuenta)…',
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
          onPressed: _canConfirm ? _submit : null,
          child: Text(_isHard ? 'Borrar' : 'Eliminar'),
        ),
      ],
    );
  }

  void _submit() {
    if (!_canConfirm) return;
    Navigator.of(context).pop(_ctrl.text.trim());
  }
}
