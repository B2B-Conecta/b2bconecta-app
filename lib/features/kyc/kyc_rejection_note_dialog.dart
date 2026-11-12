import 'package:flutter/material.dart';

import 'package:motolink_pro_app/features/admin/admin_users_chrome.dart';

/// Motivo obligatorio (≥3) al rechazar un documento KYC.
Future<String?> promptKycRejectionNote(BuildContext context) async {
  final ctrl = TextEditingController();
  final res = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AdminUsersChrome.sheetRadius),
      ),
      title: const Text('Motivo del rechazo'),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        maxLines: 4,
        decoration: AdminUsersChrome.field(
          label: 'Motivo',
          hint: 'Ej. imagen borrosa, RIF vencido, la foto no muestra el local…',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFB91C1C),
          ),
          onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
          child: const Text('Rechazar'),
        ),
      ],
    ),
  );
  ctrl.dispose();
  if (res == null || res.length < 3) return null;
  return res;
}
