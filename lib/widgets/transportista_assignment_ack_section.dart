import 'package:flutter/material.dart';

import '../models/transaction_request_model.dart';
import '../models/transaction_request_status.dart';
import '../services/supabase_service.dart';

/// Transportista asignado: confirma en la app que recibió la orden (RPC `transportista_acknowledge_assignment`).
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

  bool get _visible {
    final r = widget.request;
    final uid = SupabaseService.currentUserId?.trim();
    if (uid == null || uid.isEmpty) return false;
    if (!r.hasAssignedTransportista) return false;
    if (r.assignedTransportistaId?.trim() != uid) return false;
    if (r.transportistaReconocioAsignacion) return false;
    return TransactionRequestStatus.adminOperationalActive.contains(r.status);
  }

  Future<void> _ack() async {
    setState(() => _busy = true);
    try {
      await SupabaseService.transportistaAcknowledgeAssignment(
        widget.request.id,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Asignación confirmada. MotoLink verá la confirmación en el pedido.',
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
              'Confirme que recibió esta orden en la app para que MotoLink tenga constancia.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.35,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _busy ? null : _ack,
                child: _busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Confirmo la asignación'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
