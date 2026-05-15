import 'package:flutter/material.dart';

import '../models/app_home_role.dart';
import '../models/sub_order_model.dart';
import '../models/transaction_request_model.dart';
import '../models/transaction_request_status.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_date_format.dart';

/// Fase en tránsito: recogida en almacén del importador (transportista confirma; resto solo lectura).
class TransportistaRecogidaAlmacenSection extends StatefulWidget {
  const TransportistaRecogidaAlmacenSection({
    super.key,
    required this.request,
    required this.viewerRole,
    this.onUpdated,
  });

  final TransactionRequestModel request;
  final AppHomeRole viewerRole;
  final VoidCallback? onUpdated;

  @override
  State<TransportistaRecogidaAlmacenSection> createState() =>
      _TransportistaRecogidaAlmacenSectionState();
}

class _TransportistaRecogidaAlmacenSectionState
    extends State<TransportistaRecogidaAlmacenSection> {
  String? _busySubOrderId;
  bool _busySimple = false;

  bool get _visible =>
      widget.request.status == TransactionRequestStatus.enTransito &&
      widget.request.hasAssignedTransportista;

  bool get _puedeActuar {
    if (widget.viewerRole != AppHomeRole.transportista) return false;
    final uid = SupabaseService.currentUserId?.trim();
    if (uid == null || uid.isEmpty) return false;
    return widget.request.assignedTransportistaId?.trim() == uid;
  }

  Future<void> _marcar({String? subOrderId}) async {
    if (subOrderId != null) {
      setState(() => _busySubOrderId = subOrderId);
    } else {
      setState(() => _busySimple = true);
    }
    try {
      await SupabaseService.transportistaMarcaRecogidaEnAlmacen(
        requestId: widget.request.id,
        subOrderId: subOrderId,
      );
      try {
        await SupabaseService.transportistaTryRefreshRutaMapsRemaining(
          widget.request.id,
        );
      } catch (_) {}
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Recogida en almacén registrada. Se notificó al pedido.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      widget.onUpdated?.call();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busySubOrderId = null;
          _busySimple = false;
        });
      }
    }
  }

  Widget _chipOk(String label) {
    return Chip(
      avatar: Icon(Icons.check_circle_outline, size: 18, color: Colors.green.shade700),
      label: Text(label, style: TextStyle(fontSize: 12, color: Colors.green.shade900)),
      backgroundColor: Colors.green.shade50,
      side: BorderSide(color: Colors.green.shade200),
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  Widget _filaMaestro(SubOrderModel s) {
    final nombre = s.importadorBusinessName?.trim().isNotEmpty == true
        ? s.importadorBusinessName!.trim()
        : 'Importador';
    final hecho = s.transportistaRecogioEnAlmacen;
    final busy = _busySubOrderId == s.id;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.fieldFill,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.storefront_outlined, size: 20, color: AppColors.brandBlue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      nombre,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              if (hecho) ...[
                const SizedBox(height: 8),
                _chipOk('Retirado · ${formatEsShortDateTime(s.transportistaRecogidaAlmacenAt)}'),
              ] else if (_puedeActuar) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : () => _marcar(subOrderId: s.id),
                    icon: busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.brandBlue,
                            ),
                          )
                        : const Icon(Icons.inventory_outlined, size: 18),
                    label: Text(busy ? 'Registrando…' : 'Confirmar retiro en este almacén'),
                  ),
                ),
              ] else ...[
                const SizedBox(height: 8),
                Text(
                  'Pendiente de confirmación por el transportista.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();

    final r = widget.request;
    final titulo = _puedeActuar
        ? 'Recogida en almacén'
        : 'Estado · recogida en almacén';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.move_to_inbox_outlined, size: 20, color: Colors.teal.shade800),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                titulo,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: Colors.teal.shade900,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          _puedeActuar
              ? 'Al recibir la carga en el almacén del importador, confirme aquí. MotoLink, el aliado y los importadores del pedido recibirán un aviso.'
              : 'El transportista confirma cada retiro en almacén; aquí ve el avance.',
          style: TextStyle(fontSize: 11.5, height: 1.35, color: Colors.grey.shade700),
        ),
        const SizedBox(height: 12),
        if (r.isMasterOrder && r.subOrders.isNotEmpty) ...[
          ...r.subOrders.map(_filaMaestro),
        ] else ...[
          Material(
            color: AppColors.fieldFill,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.ownerBusinessName?.trim().isNotEmpty == true
                        ? 'Almacén · ${r.ownerBusinessName!.trim()}'
                        : 'Almacén del importador',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (r.transportistaRecogioAlmacenSimple) ...[
                    const SizedBox(height: 8),
                    _chipOk(
                      'Retirado · ${formatEsShortDateTime(r.transportistaRecogidaAlmacenAt)}',
                    ),
                  ] else if (_puedeActuar) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _busySimple ? null : () => _marcar(subOrderId: null),
                        icon: _busySimple
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.brandBlue,
                                ),
                              )
                            : const Icon(Icons.inventory_outlined, size: 18),
                        label: Text(
                          _busySimple ? 'Registrando…' : 'Confirmar retiro en almacén',
                        ),
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 8),
                    Text(
                      'Pendiente de confirmación por el transportista.',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
