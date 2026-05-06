import 'package:flutter/material.dart';

import '../models/transaction_request_model.dart';
import '../models/transaction_request_status.dart';
import '../models/transportista_info_model.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_date_format.dart';

/// MotoLink: sugerencia por distancia a almacenes importador y asignación al pedido.
class AdminTransportistaAssignmentSection extends StatefulWidget {
  const AdminTransportistaAssignmentSection({
    super.key,
    required this.request,
    required this.onMutated,
  });

  final TransactionRequestModel request;
  final VoidCallback onMutated;

  @override
  State<AdminTransportistaAssignmentSection> createState() =>
      _AdminTransportistaAssignmentSectionState();
}

class _AdminTransportistaAssignmentSectionState
    extends State<AdminTransportistaAssignmentSection> {
  List<TransportistaProximityCandidate>? _ranked;
  String? _rankError;
  bool _rankLoading = false;
  String? _assignBusyId;
  bool _unassignBusy = false;
  String? _assignedLabel;

  @override
  void initState() {
    super.initState();
    _refreshAssignedLabel();
  }

  @override
  void didUpdateWidget(covariant AdminTransportistaAssignmentSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.request.assignedTransportistaId !=
            widget.request.assignedTransportistaId ||
        oldWidget.request.id != widget.request.id) {
      _refreshAssignedLabel();
    }
  }

  Future<void> _refreshAssignedLabel() async {
    final id = widget.request.assignedTransportistaId?.trim();
    if (id == null || id.isEmpty) {
      if (mounted) setState(() => _assignedLabel = null);
      return;
    }
    final name = await SupabaseService.fetchProfileBusinessName(id);
    if (!mounted) return;
    setState(() {
      _assignedLabel = name ?? id;
    });
  }

  bool get _allowsMutate {
    final s = widget.request.status;
    return s != TransactionRequestStatus.rechazado &&
        s != TransactionRequestStatus.entregado;
  }

  bool _cambioTransportistaRequiereMotivo({
    required String? nuevoTransportistaId,
  }) {
    final r = widget.request;
    if (r.status != TransactionRequestStatus.enTransito) return false;
    final actual = r.assignedTransportistaId?.trim();
    final nuevo = nuevoTransportistaId?.trim();
    if (actual == nuevo) return false;
    return true;
  }

  Future<String?> _pedirMotivoCambioEnTransito(BuildContext context) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Motivo del cambio de transportista'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'El pedido está en tránsito. Indique por qué reasigna o retira al transportista.',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: ctrl,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    hintText:
                        'Ej.: avería del vehículo, disponibilidad, solicitud del aliado…',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (ctrl.text.trim().isEmpty) return;
                Navigator.of(ctx).pop(true);
              },
              child: const Text('Continuar'),
            ),
          ],
        );
      },
    );
    final text = ctrl.text.trim();
    ctrl.dispose();
    if (ok != true || text.isEmpty) return null;
    return text;
  }

  Future<void> _runRank() async {
    if (!widget.request.canComputeTransportistaProximity) {
      setState(() {
        _rankError =
            'No hay importadores vinculados al pedido para calcular distancias.';
        _ranked = null;
      });
      return;
    }
    setState(() {
      _rankLoading = true;
      _rankError = null;
      _ranked = null;
    });
    try {
      final list =
          await SupabaseService.adminRankTransportistasByImporterProximity(
        importerProfileIds:
            widget.request.importerProfileIdsForTransportistaProximity,
        limit: 12,
      );
      if (!mounted) return;
      setState(() {
        _ranked = list;
        _rankLoading = false;
        if (list.isEmpty) {
          _rankError =
              'Ningún transportista con expediente completo coincide. Verifique transportista_info.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _rankLoading = false;
        _rankError = e.toString();
      });
    }
  }

  Future<void> _assign(String transportistaId) async {
    String? motivo;
    if (_cambioTransportistaRequiereMotivo(nuevoTransportistaId: transportistaId)) {
      motivo = await _pedirMotivoCambioEnTransito(context);
      if (motivo == null) return;
    }

    setState(() => _assignBusyId = transportistaId);
    try {
      await SupabaseService.adminAssignTransportistaPedido(
        requestId: widget.request.id,
        transportistaId: transportistaId,
        cambioMotivoEnTransito: motivo,
      );
      if (!mounted) return;
      await _afterAssignSuccess();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo asignar: $e')),
      );
    } finally {
      if (mounted) setState(() => _assignBusyId = null);
    }
  }

  Future<void> _afterAssignSuccess() async {
    if (!mounted) return;
    var rutaMsg = '';
    try {
      final ok = await SupabaseService.adminTryAutoPublishRutaMapsUrl(
        widget.request.id,
      );
      rutaMsg = ok
          ? ' Ruta en Maps generada automáticamente.'
          : ' Si no hay ruta automática, revise direcciones en perfiles.';
    } catch (_) {
      rutaMsg = ' Revise el enlace de ruta del pedido si hace falta.';
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Transportista asignado. Verá el pedido en Despacho.$rutaMsg',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
    widget.onMutated();
  }

  Future<void> _unassign() async {
    String? motivo;
    if (_cambioTransportistaRequiereMotivo(nuevoTransportistaId: null)) {
      motivo = await _pedirMotivoCambioEnTransito(context);
      if (motivo == null) return;
    }

    setState(() => _unassignBusy = true);
    try {
      await SupabaseService.adminAssignTransportistaPedido(
        requestId: widget.request.id,
        transportistaId: null,
        cambioMotivoEnTransito: motivo,
      );
      try {
        await SupabaseService.adminSetTransactionRequestRutaMapsUrl(
          requestId: widget.request.id,
          urlOrNull: null,
        );
      } catch (_) {}
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Asignación de transportista quitada.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() {
        _ranked = null;
        _assignedLabel = null;
      });
      widget.onMutated();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo quitar: $e')),
      );
    } finally {
      if (mounted) setState(() => _unassignBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    final ids = r.importerProfileIdsForTransportistaProximity;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 24),
        const Text(
          'Transportista (despacho)',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Sugerimos transportistas según la distancia media desde su base operativa '
          'a los almacenes de este pedido (${ids.length} punto${ids.length == 1 ? '' : 's'}). '
          'Quien esté asignado verá la orden en la app Despacho.',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade700, height: 1.3),
        ),
        const SizedBox(height: 10),
        if (r.hasAssignedTransportista) ...[
          Material(
            color: AppColors.fieldFill,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.local_shipping_outlined,
                      color: AppColors.brandBlue, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Asignado: ${_assignedLabel ?? '…'}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  if (_allowsMutate)
                    TextButton(
                      onPressed: _unassignBusy ? null : _unassign,
                      child: _unassignBusy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Quitar'),
                    ),
                ],
              ),
            ),
          ),
          if (r.transportistaReconocioAsignacion &&
              r.transportistaGestionEtaLabelEs != null) ...[
            const SizedBox(height: 8),
            Text(
              'Tiempo estimado declarado por el transportista: '
              '${r.transportistaGestionEtaLabelEs}'
              '${r.transportistaGestionEtaSetAt != null ? ' · ${formatEsShortDateTime(r.transportistaGestionEtaSetAt)}' : ''}',
              style: TextStyle(
                fontSize: 11.5,
                color: Colors.teal.shade900,
                height: 1.25,
              ),
            ),
          ],
          const SizedBox(height: 10),
        ],
        if (!r.hasAssignedTransportista &&
            r.transportistaDeclinedAt != null &&
            (r.transportistaDeclineMotivo?.trim().isNotEmpty ?? false)) ...[
          Material(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: Colors.orange.shade900, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Último rechazo por transportista (${formatEsShortDateTime(r.transportistaDeclinedAt)}): '
                      '${r.transportistaDeclineMotivo!.trim()}',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.3,
                        color: Colors.grey.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (!_allowsMutate && !r.hasAssignedTransportista)
          Text(
            'Sin transportista asignado.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
        if (_allowsMutate) ...[
          if (!r.canComputeTransportistaProximity)
            Text(
              'Cuando el pedido tenga sub-pedidos o un importador dueño, podrá calcular sugerencias.',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            )
          else ...[
            OutlinedButton.icon(
              onPressed: _rankLoading ? null : _runRank,
              icon: _rankLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.route_outlined, size: 20),
              label: Text(_rankLoading
                  ? 'Calculando…'
                  : 'Sugerir por proximidad a almacenes'),
            ),
            if (_rankError != null) ...[
              const SizedBox(height: 8),
              Text(
                _rankError!,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.red.shade800,
                  height: 1.25,
                ),
              ),
            ],
            if (_ranked != null && _ranked!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'Ordenados por km promedio (máx.)',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 6),
              ..._ranked!.map((c) {
                final busy = _assignBusyId == c.transportistaId;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  c.businessName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Promedio ${c.avgDistanceKm.toStringAsFixed(1)} km · '
                                  'máx. ${c.maxDistanceKm.toStringAsFixed(1)} km',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          FilledButton.tonal(
                            onPressed: busy
                                ? null
                                : () => _assign(c.transportistaId),
                            child: busy
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Asignar'),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ],
        ],
      ],
    );
  }
}
