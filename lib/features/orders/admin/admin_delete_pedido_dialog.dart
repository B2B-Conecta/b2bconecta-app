import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';
import 'package:motolink_pro_app/features/admin/unified_action_dialog.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_model.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_status.dart';

enum AdminDeletePedidoScope { one, checkoutGroup }

Future<bool> confirmAdminDeletePedido(
  BuildContext context, {
  required TransactionRequestModel line,
}) {
  final name = line.productName?.trim();
  final label = (name == null || name.isEmpty) ? 'este pedido' : '«$name»';
  final billed = line.commissionSettlementId != null;
  final theme = B2BThemeExtension.of(context);

  return UnifiedActionDialog.show<bool>(
    context: context,
    builder: (ctx) => UnifiedActionDialog(
      title: 'Eliminar pedido',
      subtitle: 'Esta acción es permanente.',
      glyph: LucideGlyph.trash2,
      tone: UnifiedActionTone.danger,
      primaryLabel: 'Eliminar pedido',
      onPrimary: () => Navigator.of(ctx).pop(true),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Se va a borrar $label (${line.statusLabelEs()}). '
            'También se borra su chat y su postventa. No se puede deshacer.',
            style: TextStyle(
              fontSize: 13.5,
              height: 1.45,
              color: theme.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (billed) ...[
            const SizedBox(height: 12),
            _SoftNotice(
              theme: theme,
              tone: UnifiedActionTone.warning,
              message:
                  'Esta línea ya está en una factura de comisión; esa factura no se recalcula.',
            ),
          ],
        ],
      ),
    ),
  ).then((value) => value == true);
}

/// Motivo obligatorio para borrar un pedido que ya está entregado.
Future<String?> askAdminDeleteEntregadoMotivo(BuildContext context) async {
  final result = await UnifiedActionDialog.show<String>(
    context: context,
    builder: (ctx) => const _DeleteEntregadoMotivoDialog(),
  );
  final motivo = result?.trim() ?? '';
  if (motivo.length < 3) return null;
  return motivo;
}

class _DeleteEntregadoMotivoDialog extends StatefulWidget {
  const _DeleteEntregadoMotivoDialog();

  @override
  State<_DeleteEntregadoMotivoDialog> createState() =>
      _DeleteEntregadoMotivoDialogState();
}

class _DeleteEntregadoMotivoDialogState
    extends State<_DeleteEntregadoMotivoDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final ready = _ctrl.text.trim().length >= 3;

    return UnifiedActionDialog(
      title: 'Motivo de la eliminación',
      subtitle: 'Pedido entregado · se quitará de los reportes.',
      glyph: LucideGlyph.triangleAlert,
      tone: UnifiedActionTone.danger,
      primaryLabel: 'Eliminar pedido',
      primaryEnabled: ready,
      onPrimary: () => Navigator.of(context).pop(_ctrl.text.trim()),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Indique por qué elimina este pedido (p. ej. pedido de prueba). '
            'El inventario no vuelve y una factura de comisión ya emitida no cambia.',
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: theme.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ctrl,
            maxLines: 4,
            maxLength: 500,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            style: TextStyle(color: theme.textPrimary, fontSize: 13.5),
            decoration: InputDecoration(
              labelText: 'Motivo (obligatorio)',
              alignLabelWithHint: true,
              filled: true,
              fillColor: theme.inputFill,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: theme.borderSubtle),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: theme.borderSubtle),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: theme.brand, width: 1.4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Segunda confirmación cuando el carrito tiene otras líneas.
Future<AdminDeletePedidoScope?> confirmAdminDeletePedidoGroup(
  BuildContext context, {
  required List<TransactionRequestModel> siblings,
  bool includesDelivered = false,
}) {
  final theme = B2BThemeExtension.of(context);
  return UnifiedActionDialog.show<AdminDeletePedidoScope>(
    context: context,
    builder: (ctx) => UnifiedActionDialog(
      title: 'Hay más pedidos en este carrito',
      subtitle: siblings.length == 1
          ? 'Puedes borrar solo esta línea o todo el carrito.'
          : 'El carrito incluye ${siblings.length} líneas adicionales.',
      glyph: LucideGlyph.package,
      tone: UnifiedActionTone.warning,
      primaryLabel: 'Todo el carrito (${siblings.length + 1})',
      onPrimary: () =>
          Navigator.of(ctx).pop(AdminDeletePedidoScope.checkoutGroup),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            siblings.length == 1
                ? 'Además de esta línea, el carrito incluye otro pedido.'
                : 'Además de esta línea, el carrito incluye ${siblings.length} pedidos.',
            style: TextStyle(
              fontSize: 13.5,
              height: 1.45,
              color: theme.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (includesDelivered) ...[
            const SizedBox(height: 10),
            _SoftNotice(
              theme: theme,
              tone: UnifiedActionTone.warning,
              message:
                  'Hay líneas entregadas. Borrar el carrito completo pide un motivo y las quita de los reportes.',
            ),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            decoration: BoxDecoration(
              color: theme.inputFill,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: theme.borderSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final line in siblings.take(8))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      '• ${line.productName?.trim().isNotEmpty == true ? line.productName!.trim() : 'Pedido'} · ${line.cantidad} u. · ${TransactionRequestStatus.labelEs(line.status)}',
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.35,
                        color: theme.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                if (siblings.length > 8)
                  Text(
                    'y ${siblings.length - 8} más',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: theme.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              onPressed: () =>
                  Navigator.of(ctx).pop(AdminDeletePedidoScope.one),
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.brand,
                side: BorderSide(color: theme.brand.withOpacity(0.35)),
                backgroundColor: theme.brandContainer,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                minimumSize: const Size(0, 36),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Solo este pedido',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _SoftNotice extends StatelessWidget {
  const _SoftNotice({
    required this.theme,
    required this.tone,
    required this.message,
  });

  final B2BThemeExtension theme;
  final UnifiedActionTone tone;
  final String message;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = tone == UnifiedActionTone.warning
        ? const Color(0xFFD97706)
        : theme.brand;
    final bg = tone == UnifiedActionTone.warning
        ? (dark ? const Color(0x26F59E0B) : const Color(0xFFFFFBEB))
        : theme.brandContainer;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withOpacity(0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LucideIcon(
            LucideGlyph.triangleAlert,
            size: 16,
            color: accent,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: theme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
