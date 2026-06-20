import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/support_ticket_message_model.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_date_format.dart';

/// Hilo de mensajes de un reclamo de soporte.
class SupportTicketThreadSection extends StatefulWidget {
  const SupportTicketThreadSection({
    super.key,
    required this.ticketId,
    required this.canReplyAsOwner,
    required this.canReplyAsAdmin,
    required this.isTicketClosed,
    this.onThreadChanged,
  });

  final String ticketId;
  final bool canReplyAsOwner;
  final bool canReplyAsAdmin;
  final bool isTicketClosed;
  final VoidCallback? onThreadChanged;

  @override
  State<SupportTicketThreadSection> createState() =>
      _SupportTicketThreadSectionState();
}

class _SupportTicketThreadSectionState extends State<SupportTicketThreadSection> {
  final _ctrl = TextEditingController();
  List<SupportTicketMessageModel> _items = [];
  bool _loading = true;
  bool _sending = false;
  String? _error;
  RealtimeChannel? _channel;

  bool get _canReply =>
      !widget.isTicketClosed &&
      (widget.canReplyAsOwner || widget.canReplyAsAdmin);

  @override
  void initState() {
    super.initState();
    _load();
    _channel = SupabaseService.subscribeToSupportTicketMessages(
      ticketId: widget.ticketId,
      onInsert: () {
        if (!mounted) return;
        _load(silent: true);
        widget.onThreadChanged?.call();
      },
    );
  }

  @override
  void dispose() {
    if (_channel != null) {
      SupabaseService.unsubscribeChannel(_channel!);
    }
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final rows =
          await SupabaseService.fetchSupportTicketMessages(widget.ticketId);
      if (!mounted) return;
      setState(() {
        _items = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    try {
      if (widget.canReplyAsAdmin) {
        await SupabaseService.adminReplySupportTicket(
          ticketId: widget.ticketId,
          body: text,
        );
      } else {
        await SupabaseService.replySupportTicketAsOwner(
          ticketId: widget.ticketId,
          body: text,
        );
      }
      _ctrl.clear();
      await _load(silent: true);
      widget.onThreadChanged?.call();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo enviar: $e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = SupabaseService.currentUserId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Conversación',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Actualizar',
              onPressed: _loading ? null : () => _load(),
              icon: const Icon(Icons.refresh, size: 20),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else if (_error != null)
          Text(_error!, style: TextStyle(fontSize: 12, color: Colors.red.shade800))
        else if (_items.isEmpty)
          Text(
            'Sin mensajes en este reclamo.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final m = _items[i];
              final mine = uid != null && m.authorId == uid;
              final label = mine
                  ? 'Tú'
                  : (m.isFromAdmin
                      ? 'MotoLink'
                      : (m.isFromImportador ? 'Importador' : 'Aliado'));
              final align =
                  mine ? CrossAxisAlignment.end : CrossAxisAlignment.start;
              final bg = m.isFromAdmin
                  ? AppColors.surfaceTinted.withOpacity(0.55)
                  : (mine
                      ? AppColors.brandBlue.withOpacity(0.12)
                      : Colors.grey.shade200);

              return Column(
                crossAxisAlignment: align,
                children: [
                  Text(
                    '$label · ${formatEsShortDateTime(m.createdAt)}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                      child: Text(
                        m.body,
                        style: const TextStyle(fontSize: 13, height: 1.35),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        if (_canReply) ...[
          const SizedBox(height: 10),
          TextField(
            controller: _ctrl,
            minLines: 1,
            maxLines: 4,
            textInputAction: TextInputAction.newline,
            decoration: InputDecoration(
              hintText: widget.canReplyAsAdmin
                  ? 'Respuesta al usuario…'
                  : 'Escriba su mensaje…',
              isDense: true,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: _sending ? null : _send,
              child: _sending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Enviar'),
            ),
          ),
        ] else if (widget.isTicketClosed)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Este reclamo está cerrado.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
          ),
      ],
    );
  }
}
