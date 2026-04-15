import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/transaction_request_message_model.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_date_format.dart';
import 'main_shell_tab.dart';

/// Hilo de mensajes aliado ↔ MotoLink sobre un pedido.
class OrderMotolinkThreadSection extends StatefulWidget {
  const OrderMotolinkThreadSection({
    super.key,
    required this.transactionRequestId,
    required this.allowReplyAsAliado,
    required this.allowReplyAsAdmin,
  });

  final String transactionRequestId;
  final bool allowReplyAsAliado;
  final bool allowReplyAsAdmin;

  @override
  State<OrderMotolinkThreadSection> createState() =>
      _OrderMotolinkThreadSectionState();
}

class _OrderMotolinkThreadSectionState extends State<OrderMotolinkThreadSection> {
  final _ctrl = TextEditingController();
  List<TransactionRequestMessageModel> _items = [];
  bool _loading = true;
  bool _sending = false;
  String? _error;
  RealtimeChannel? _messagesChannel;

  @override
  void dispose() {
    SupabaseService.unsubscribeChannel(_messagesChannel);
    _ctrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    SupabaseService.markNotificationsReadForRelatedOrder(widget.transactionRequestId)
        .then((_) => MainShellTabController.requestNotificationsReload());
    _messagesChannel = SupabaseService.subscribeToTransactionRequestMessages(
      transactionRequestId: widget.transactionRequestId,
      onInsert: () {
        if (mounted) _load();
      },
    );
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await SupabaseService.fetchTransactionRequestMessages(
        widget.transactionRequestId,
      );
      if (!mounted) return;
      setState(() {
        _items = list;
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
      if (widget.allowReplyAsAliado) {
        await SupabaseService.insertTransactionRequestMessageAsAliado(
          transactionRequestId: widget.transactionRequestId,
          body: text,
        );
      } else if (widget.allowReplyAsAdmin) {
        await SupabaseService.insertTransactionRequestMessageAsAdmin(
          transactionRequestId: widget.transactionRequestId,
          body: text,
        );
      }
      _ctrl.clear();
      await _load();
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
    final canReply = widget.allowReplyAsAliado || widget.allowReplyAsAdmin;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Consultas a MotoLink',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Actualizar',
              onPressed: _loading ? null : _load,
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
            canReply
                ? 'Aún no hay mensajes. Escriba aquí si tiene dudas sobre este pedido.'
                : 'Sin mensajes en este pedido.',
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
              final fromMotoLink = m.isFromAdmin;
              final label =
                  fromMotoLink ? 'MotoLink' : (mine ? 'Tú' : 'Aliado');
              final align =
                  mine ? CrossAxisAlignment.end : CrossAxisAlignment.start;
              final bg = fromMotoLink
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
                      child: SelectableText(
                        m.body,
                        style: const TextStyle(fontSize: 13, height: 1.35),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        if (canReply) ...[
          const SizedBox(height: 10),
          TextField(
            controller: _ctrl,
            minLines: 1,
            maxLines: 4,
            textInputAction: TextInputAction.newline,
            decoration: InputDecoration(
              hintText: widget.allowReplyAsAdmin
                  ? 'Respuesta al aliado…'
                  : 'Escriba a MotoLink…',
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
        ],
      ],
    );
  }
}
