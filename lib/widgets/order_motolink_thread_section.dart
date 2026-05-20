import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/transaction_request_message_model.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_date_format.dart';
import 'main_shell_tab.dart';

/// Hilo de mensajes del pedido: aliado ↔ importador, con supervisión MotoLink.
class OrderMotolinkThreadSection extends StatefulWidget {
  const OrderMotolinkThreadSection({
    super.key,
    required this.transactionRequestId,
    required this.allowReplyAsAliado,
    required this.allowReplyAsAdmin,
    this.allowReplyAsImportador = false,
    this.onThreadChanged,
    this.suppressBuiltinTitle = false,
    /// Varias líneas del mismo importador: vista única; inserción en [transactionRequestId].
    this.mergedThreadRequestIds,
  });

  final String transactionRequestId;
  final bool allowReplyAsAliado;
  final bool allowReplyAsAdmin;
  final bool allowReplyAsImportador;

  /// Varios ids de `transaction_requests` (mismo importador en un carrito): se listan mensajes juntos.
  final List<String>? mergedThreadRequestIds;

  /// Nuevo mensaje (Realtime) u operaciones en el hilo: refresca la ficha del pedido.
  final VoidCallback? onThreadChanged;

  /// Cuando el padre ya mostró el título de sección (p. ej. carrito multi‑línea).
  final bool suppressBuiltinTitle;

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
  final List<RealtimeChannel> _messageChannels = [];

  bool get _usaHiloFusionado =>
      widget.mergedThreadRequestIds != null &&
      widget.mergedThreadRequestIds!.length > 1;

  @override
  void dispose() {
    for (final c in _messageChannels) {
      SupabaseService.unsubscribeChannel(c);
    }
    _messageChannels.clear();
    _ctrl.dispose();
    super.dispose();
  }

  void _unsubscribeAll() {
    for (final c in _messageChannels) {
      SupabaseService.unsubscribeChannel(c);
    }
    _messageChannels.clear();
  }

  void _subscribeChannels() {
    _unsubscribeAll();
    void onInsert() {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _load();
          widget.onThreadChanged?.call();
        }
      });
    }

    final merge = widget.mergedThreadRequestIds;
    if (merge != null && merge.length > 1) {
      _messageChannels.addAll(
        SupabaseService.subscribeToTransactionRequestMessagesMany(
          transactionRequestIds: merge,
          onInsert: onInsert,
        ),
      );
    } else {
      _messageChannels.add(
        SupabaseService.subscribeToTransactionRequestMessages(
          transactionRequestId: widget.transactionRequestId,
          onInsert: onInsert,
        ),
      );
    }
  }

  Future<void> _markNotificationsReadAsync() async {
    final merge = widget.mergedThreadRequestIds;
    if (merge != null && merge.length > 1) {
      for (final id in merge) {
        await SupabaseService.markNotificationsReadForRelatedOrder(id);
      }
    } else {
      await SupabaseService.markNotificationsReadForRelatedOrder(
        widget.transactionRequestId,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _markNotificationsReadAsync().then((_) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        MainShellTabController.requestNotificationsReload();
      });
    });
    _subscribeChannels();
    _load();
  }

  @override
  void didUpdateWidget(covariant OrderMotolinkThreadSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.transactionRequestId != widget.transactionRequestId ||
        _listEq(
              oldWidget.mergedThreadRequestIds,
              widget.mergedThreadRequestIds,
            ) ==
            false) {
      _unsubscribeAll();
      _subscribeChannels();
      unawaited(_markNotificationsReadAsync());
      _load();
    }
  }

  static bool _listEq(List<String>? a, List<String>? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return a == b;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final List<TransactionRequestMessageModel> list;
      if (_usaHiloFusionado) {
        list = await SupabaseService.fetchTransactionRequestMessagesForRequests(
          widget.mergedThreadRequestIds!,
        );
      } else {
        list = await SupabaseService.fetchTransactionRequestMessages(
          widget.transactionRequestId,
        );
      }
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
      } else if (widget.allowReplyAsImportador) {
        await SupabaseService.insertTransactionRequestMessageAsImportador(
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
    final canReply = widget.allowReplyAsAliado ||
        widget.allowReplyAsAdmin ||
        widget.allowReplyAsImportador;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (!widget.suppressBuiltinTitle)
              const Expanded(
                child: Text(
                  'Chat del pedido',
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
        Text(
          'Desde que el pedido está pendiente, aliado e importador pueden escribir aquí '
          '(coordinación de cantidad, plazos y logística). MotoLink puede leer el hilo en tiempo real.',
          style: TextStyle(fontSize: 11, height: 1.3, color: Colors.grey.shade700),
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
              final label = mine
                  ? 'Tú'
                  : (m.isFromAdmin
                      ? 'MotoLink'
                      : (m.isFromImportador ? 'Importador' : 'Aliado'));
              final align =
                  mine ? CrossAxisAlignment.end : CrossAxisAlignment.start;
              final bg = m.isFromAdmin
                  ? AppColors.surfaceTinted.withOpacity(0.55)
                  : (m.isFromImportador
                      ? Colors.orange.shade50
                      : (mine
                          ? AppColors.brandBlue.withOpacity(0.12)
                          : Colors.grey.shade200));

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
        ],
      ],
    );
  }
}
