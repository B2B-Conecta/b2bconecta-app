import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/utils/ves_amount_format.dart';
import 'order_message_attachment.dart';
import 'order_message_media.dart';
import 'order_product_thumb.dart';
import 'order_return_rules.dart';

/// Tarjeta del reporte dentro del chat del pedido.
class OrderPostventaChatCard extends StatelessWidget {
  const OrderPostventaChatCard({
    super.key,
    required this.data,
    required this.attachments,
    required this.canDecide,
    required this.busy,
    required this.onResolve,
    this.imageUrl,
    this.creditAmount = 0,
  });

  final ParsedReturnRequest data;
  final List<OrderMessageAttachment> attachments;
  final String? imageUrl;
  final bool canDecide;
  final bool busy;
  final double creditAmount;
  final Future<void> Function(String resolution, String? note) onResolve;

  @override
  Widget build(BuildContext context) {
    final pref = data.preferenceLabel.trim().isEmpty
        ? OrderReturnRules.preferenceLabel(data.preference)
        : _capitalize(data.preferenceLabel);
    final title = pref.isEmpty
        ? 'Observación del pedido'
        : 'Solicitud de devolución';
    final units = data.units == 1 ? '1 unidad' : '${data.units} unidades';
    final product =
        data.productName.trim().isEmpty ? 'Producto' : data.productName.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OrderProductThumb(size: 56, url: imageUrl),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$product · $units',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (pref.isNotEmpty)
                    Text(
                      'Preferencia: $pref',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        if (data.reason.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            data.reason.trim(),
            style: const TextStyle(fontSize: 13, height: 1.35),
          ),
        ],
        OrderMessageMediaStrip(attachments: attachments),
        if (canDecide) ...[
          const SizedBox(height: 10),
          Text(
            'Usted acuerda la solución con la tienda.',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.35,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          _decision(
            context,
            resolution: 'credito',
            label: creditAmount > 0
                ? 'Aprobar crédito a favor · ${formatRefAmount(creditAmount)} REF'
                : 'Aprobar crédito a favor',
          ),
          const SizedBox(height: 8),
          _decision(
            context,
            resolution: 'cambio',
            label: 'Aprobar cambio de producto',
          ),
          Align(
            alignment: Alignment.center,
            child: TextButton(
              onPressed: busy ? null : () => _reject(context),
              child: const Text('No aceptar'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _decision(
    BuildContext context, {
    required String resolution,
    required String label,
  }) {
    final onPressed = busy
        ? null
        : () async {
            final title = resolution == 'credito'
                ? '¿Aprueba el crédito a favor?'
                : '¿Aprueba el cambio de producto?';
            final body = resolution == 'cambio'
                ? 'Se reserva el stock y el pedido muestra el seguimiento del reemplazo.'
                : 'El saldo queda para el próximo pedido de esta tienda con usted.';
            final ok = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(title),
                content: Text(body),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancelar'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Confirmar'),
                  ),
                ],
              ),
            );
            if (ok == true) await onResolve(resolution, null);
          };
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.brand,
        side: const BorderSide(color: AppColors.brand),
        minimumSize: const Size(double.infinity, 44),
      ),
      child: Text(label, textAlign: TextAlign.center),
    );
  }

  Future<void> _reject(BuildContext context) async {
    final noteCtrl = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('No aceptar'),
        content: TextField(
          controller: noteCtrl,
          minLines: 2,
          maxLines: 4,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Motivo',
            hintText: 'La tienda lo ve en el chat.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final text = noteCtrl.text.trim();
              if (text.length < 3) return;
              Navigator.of(context).pop(text);
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    noteCtrl.dispose();
    if (note == null) return;
    if (note.length < 3) return;
    await onResolve('rechazo', note);
  }

  String _capitalize(String value) {
    final text = value.trim();
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }
}
