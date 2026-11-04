import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support_ticket_message_model.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/widgets/chat_conversation_widgets.dart';

/// Conversación de un reclamo, con escritura fija bajo el historial.
class SupportTicketThreadSection extends StatefulWidget {
  const SupportTicketThreadSection({
    super.key,
    required this.ticketId,
    required this.canReplyAsOwner,
    required this.canReplyAsAdmin,
    required this.isTicketClosed,
    this.onThreadChanged,
    this.refreshVersion = 0,
  });

  final String ticketId;
  final bool canReplyAsOwner;
  final bool canReplyAsAdmin;
  final bool isTicketClosed;
  final VoidCallback? onThreadChanged;
  final int refreshVersion;

  @override
  State<SupportTicketThreadSection> createState() =>
      _SupportTicketThreadSectionState();
}

class _SupportTicketThreadSectionState
    extends State<SupportTicketThreadSection> {
  final _ctrl = TextEditingController();
  List<SupportTicketMessageModel> _items = [];
  bool _loading = true;
  bool _sending = false;
  String? _error;
  RealtimeChannel? _channel;
  int _loadVersion = 0;

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
  void didUpdateWidget(covariant SupportTicketThreadSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshVersion != widget.refreshVersion ||
        oldWidget.isTicketClosed != widget.isTicketClosed) {
      _load(silent: true);
    }
  }

  @override
  void dispose() {
    SupabaseService.unsubscribeChannel(_channel);
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    final version = ++_loadVersion;
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final rows =
          await SupabaseService.fetchSupportTicketMessages(widget.ticketId);
      if (!mounted || version != _loadVersion) return;
      setState(() {
        _items = rows;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted || version != _loadVersion) return;
      setState(() {
        _error = 'Revisa tu conexión e inténtalo de nuevo.';
        _loading = false;
      });
    }
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (!_canReply || text.isEmpty || _sending) return;
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
      if (!mounted) return;
      _ctrl.clear();
      await _load(silent: true);
      if (mounted) widget.onThreadChanged?.call();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo enviar el mensaje. Inténtalo de nuevo.'),
        ),
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
        if (_loading && _items.isNotEmpty)
          const LinearProgressIndicator(minHeight: 2),
        if (_error != null && _items.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(child: Text(_error!)),
                TextButton(
                  onPressed: () => _load(),
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        Expanded(
          child: _loading && _items.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _error != null && _items.isEmpty
                  ? ChatConversationNotice(
                      title: 'No se pudo cargar la conversación',
                      description: _error,
                      icon: Icons.info_outline,
                      onRetry: () => _load(),
                    )
                  : _items.isEmpty
                      ? const ChatConversationNotice(
                          title: 'Conversa con B2B Conecta',
                          description:
                              'Aquí puedes consultar y seguir tu reclamo.',
                          icon: Icons.support_agent_outlined,
                        )
                      : ChatTimeline(
                          itemCount: _items.length,
                          dateAt: (i) => _items[i].createdAt,
                          messageAt: (i) {
                            final message = _items[i];
                            final mine = uid != null && message.authorId == uid;
                            return ChatMessageBubble(
                              key: ValueKey(message.id),
                              mine: mine,
                              at: message.createdAt,
                              author: mine
                                  ? null
                                  : message.isFromAdmin
                                      ? 'Soporte B2B Conecta'
                                      : 'Usuario',
                              child: Text(
                                message.body,
                                style: const TextStyle(height: 1.4),
                              ),
                            );
                          },
                        ),
        ),
        if (_canReply)
          ChatComposer(
            controller: _ctrl,
            onSend: _send,
            sending: _sending,
            hint: widget.canReplyAsAdmin
                ? 'Responde al usuario…'
                : 'Escribe a soporte…',
          )
        else if (widget.isTicketClosed)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Reclamo cerrado · Solo lectura',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
      ],
    );
  }
}
