import 'package:flutter/material.dart';

import '../models/transaction_request_model.dart';
import '../models/transaction_request_status.dart';
import '../theme/app_theme.dart';
import '../utils/order_flow_copy/order_actions_flow_copy.dart';

/// Recepción en taller: se muestra al inicio de la ficha expandida del pedido.
class AliadoConfirmarRecepcionSection extends StatelessWidget {
  const AliadoConfirmarRecepcionSection({
    super.key,
    required this.bloques,
  });

  final List<AliadoConfirmarRecepcionBloque> bloques;

  @override
  Widget build(BuildContext context) {
    if (bloques.isEmpty) return const SizedBox.shrink();

    final varios = bloques.length > 1;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colors.teal.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.teal.shade300, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.inventory_2_outlined, color: Colors.teal.shade800, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  varios
                      ? OrderActionsFlowCopy.recepcionTituloMulti
                      : OrderActionsFlowCopy.recepcionTitulo,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: Colors.teal.shade900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            varios
                ? OrderActionsFlowCopy.recepcionIntroMulti
                : OrderActionsFlowCopy.recepcionIntro,
            style: TextStyle(
              fontSize: 11.5,
              height: 1.35,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 12),
          ...List.generate(bloques.length, (i) {
            final b = bloques[i];
            return Padding(
              padding: EdgeInsets.only(bottom: i < bloques.length - 1 ? 14 : 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (varios &&
                      b.importadorNombre != null &&
                      b.importadorNombre!.trim().isNotEmpty) ...[
                    Text(
                      b.importadorNombre!.trim(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  FilledButton.icon(
                    onPressed: b.busy || !b.puedeConfirmar ? null : b.onConfirmar,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.teal.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: b.busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.inventory_2_outlined, size: 20),
                    label: Text(
                      b.busy
                          ? 'Confirmando…'
                          : varios
                              ? OrderActionsFlowCopy.recepcionBoton
                              : OrderActionsFlowCopy.recepcionBotonTaller,
                    ),
                  ),
                  if (b.pagoPendienteEnTransito) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Puede confirmar la recepción aunque el pago siga pendiente.',
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.35,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// Datos de un bloque «confirmar recepción» (una línea o un importador en carrito).
class AliadoConfirmarRecepcionBloque {
  const AliadoConfirmarRecepcionBloque({
    this.importadorNombre,
    required this.busy,
    required this.puedeConfirmar,
    required this.onConfirmar,
    this.pagoPendienteEnTransito = false,
  });

  final String? importadorNombre;
  final bool busy;
  final bool puedeConfirmar;
  final VoidCallback onConfirmar;
  final bool pagoPendienteEnTransito;
}

/// Construye bloques de recepción para todas las líneas / importadores en tránsito.
List<AliadoConfirmarRecepcionBloque> aliadoRecepcionBloquesDesdePedido({
  required List<TransactionRequestModel> lines,
  required bool Function(TransactionRequestModel line) lineaPuedeConfirmar,
  required bool Function(List<TransactionRequestModel> chunk) chunkPuedeConfirmar,
  required String? Function(List<TransactionRequestModel> chunk) busyKeyForChunk,
  required String? entregaBusyId,
  required void Function(TransactionRequestModel line) onConfirmarLinea,
  required void Function(List<TransactionRequestModel> chunk) onConfirmarChunk,
}) {
  final enTransito = lines.where(
    (r) =>
        r.status == TransactionRequestStatus.enTransito ||
        r.status == TransactionRequestStatus.enviado,
  );
  if (enTransito.isEmpty) return const [];

  final porImp = <String, List<TransactionRequestModel>>{};
  final order = <String>[];
  for (final r in enTransito) {
    final k = r.ownerId.trim().isEmpty ? r.id : r.ownerId.trim();
    porImp.putIfAbsent(k, () {
      order.add(k);
      return <TransactionRequestModel>[];
    });
    porImp[k]!.add(r);
  }

  final out = <AliadoConfirmarRecepcionBloque>[];
  final multiImp = order.length > 1;

  for (final k in order) {
    final chunk = porImp[k]!;
    final ref = chunk.first;
    final key = busyKeyForChunk(chunk);
    final busy = key != null && entregaBusyId == key;

    out.add(
      AliadoConfirmarRecepcionBloque(
        importadorNombre: multiImp ? (ref.ownerBusinessName ?? 'Importador') : null,
        busy: busy,
        puedeConfirmar: chunk.length == 1
            ? lineaPuedeConfirmar(ref)
            : chunkPuedeConfirmar(chunk),
        onConfirmar: chunk.length == 1
            ? () => onConfirmarLinea(ref)
            : () => onConfirmarChunk(chunk),
        pagoPendienteEnTransito: chunk.any((r) => r.pagoMotolinkPendienteEnTransito),
      ),
    );
  }
  return out;
}
