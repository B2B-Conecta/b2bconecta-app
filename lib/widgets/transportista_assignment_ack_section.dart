import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/transaction_request_model.dart';
import '../models/transaction_request_status.dart';
import '../services/supabase_service.dart';

/// Transportista asignado: confirma la orden con ETA de gestión o rechaza la asignación con motivo.
class TransportistaAssignmentAckSection extends StatefulWidget {
  const TransportistaAssignmentAckSection({
    super.key,
    required this.request,
    required this.onAcknowledged,
  });

  final TransactionRequestModel request;
  final VoidCallback onAcknowledged;

  @override
  State<TransportistaAssignmentAckSection> createState() =>
      _TransportistaAssignmentAckSectionState();
}

class _TransportistaAssignmentAckSectionState
    extends State<TransportistaAssignmentAckSection> {
  bool _busy = false;
  late final TextEditingController _daysCtrl;
  late final TextEditingController _hoursCtrl;

  @override
  void initState() {
    super.initState();
    _daysCtrl = TextEditingController(text: '0');
    _hoursCtrl = TextEditingController(text: '0');
  }

  @override
  void dispose() {
    _daysCtrl.dispose();
    _hoursCtrl.dispose();
    super.dispose();
  }

  bool get _visible {
    final r = widget.request;
    final uid = SupabaseService.currentUserId?.trim();
    if (uid == null || uid.isEmpty) return false;
    if (!r.hasAssignedTransportista) return false;
    if (r.assignedTransportistaId?.trim() != uid) return false;
    if (r.transportistaReconocioAsignacion) return false;
    return TransactionRequestStatus.adminOperationalActive.contains(r.status);
  }

  int? _parseNonNegative(String raw, {required int max}) {
    final t = raw.trim();
    if (t.isEmpty) return 0;
    final v = int.tryParse(t);
    if (v == null || v < 0 || v > max) return null;
    return v;
  }

  Future<void> _confirm() async {
    final days = _parseNonNegative(_daysCtrl.text, max: 365);
    final hours = _parseNonNegative(_hoursCtrl.text, max: 23);
    if (days == null || hours == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Use días entre 0 y 365 y horas entre 0 y 23 (horas adicionales a los días).',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (days == 0 && hours == 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Indique al menos un día u hora estimada para gestionar este envío.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      await SupabaseService.transportistaAcknowledgeAssignment(
        requestId: widget.request.id,
        gestionEtaDays: days,
        gestionEtaHours: hours,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Asignación confirmada. MotoLink y el aliado recibirán una notificación con su estimación.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      widget.onAcknowledged();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _decline() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Rechazar asignación'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Si no puede tomar este pedido (por ejemplo, porque ya está con otro envío), '
                  'indique el motivo. MotoLink y el aliado serán notificados y la asignación se quitará.',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade800, height: 1.35),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: ctrl,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    hintText:
                        'Ej.: ya tengo otro pedido en curso; no puedo en el horario solicitado…',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Volver'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade800,
              ),
              onPressed: () {
                if (ctrl.text.trim().isEmpty) return;
                Navigator.of(ctx).pop(true);
              },
              child: const Text('Rechazar asignación'),
            ),
          ],
        );
      },
    );
    if (ok != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await SupabaseService.transportistaDeclineAssignment(
        requestId: widget.request.id,
        motivo: ctrl.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Asignación rechazada. MotoLink y el aliado han sido notificados.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      widget.onAcknowledged();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    return Material(
      color: Colors.indigo.shade50,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.assignment_turned_in_outlined,
                  color: Colors.indigo.shade900,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Asignación de despacho',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: Colors.indigo.shade900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Confirme que recibe la orden e indique cuánto tiempo estima necesitar para '
              'gestionar el envío (MotoLink y el aliado recibirán una notificación). '
              'Si no puede tomar el pedido, rechace la asignación con un motivo claro.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.35,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Tiempo estimado de gestión',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: Colors.indigo.shade900,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _daysCtrl,
                    enabled: !_busy,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(3),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Días',
                      hintText: '0',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _hoursCtrl,
                    enabled: !_busy,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(2),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Horas (0–23)',
                      hintText: '0',
                      border: OutlineInputBorder(),
                      isDense: true,
                      helperText: 'Además de los días',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _busy ? null : _confirm,
                child: _busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Confirmo la asignación'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _busy ? null : _decline,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red.shade800,
                  side: BorderSide(color: Colors.red.shade300),
                ),
                child: const Text('Rechazar asignación'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
