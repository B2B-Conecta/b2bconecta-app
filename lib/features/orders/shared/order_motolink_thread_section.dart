import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'order_chat_access.dart';
import 'order_postventa_chat_card.dart';
import 'order_return_rules.dart';
import 'order_message_attachment.dart';
import 'orders_service.dart';
import 'transaction_request_model.dart';
import 'order_message_media.dart';
import 'order_message_pick.dart';
import 'transaction_request_message_model.dart';
import 'package:motolink_pro_app/core/data/jwt_clock_skew.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/utils/app_date_format.dart';
import 'package:motolink_pro_app/app/main_shell_tab.dart';
import 'order_card_collapsible_layout.dart';
import 'package:motolink_pro_app/features/inventory/product_images.dart';
import 'package:motolink_pro_app/features/profile/profile_section_helpers.dart';

/// Hilo de mensajes del pedido: aliado ↔ importador, con supervisión B2B Conecta.
class OrderMotolinkThreadSection extends StatefulWidget {
  const OrderMotolinkThreadSection({
    super.key,
    required this.transactionRequestId,
    required this.allowReplyAsAliado,
    required this.allowReplyAsAdmin,
    this.allowReplyAsImportador = false,
    this.deliveryGrace = false,
    this.onThreadChanged,
    this.suppressBuiltinTitle = false,
    this.suppressInlineHelp = false,
    this.expandMessages = false,
    this.emptyHint,
    /// Varias líneas del mismo importador: vista única; inserción en [transactionRequestId].
    this.mergedThreadRequestIds,
    this.orderLines = const [],
  });

  final String transactionRequestId;
  final bool allowReplyAsAliado;
  final bool allowReplyAsAdmin;
  final bool allowReplyAsImportador;

  /// Pedido ya recibido: el composer sigue abierto dentro de los 7 días.
  final bool deliveryGrace;

  /// Varios ids de `transaction_requests` (mismo importador en un carrito): se listan mensajes juntos.
  final List<String>? mergedThreadRequestIds;

  /// Líneas del pedido, para la foto y la decisión del reporte en el chat.
  final List<TransactionRequestModel> orderLines;

  /// Nuevo mensaje (Realtime) u operaciones en el hilo: refresca la ficha del pedido.
  final VoidCallback? onThreadChanged;

  /// Cuando el padre ya mostró el título de sección (p. ej. carrito multi‑línea).
  final bool suppressBuiltinTitle;

  /// La ayuda va en el icono ℹ️ del bloque colapsable padre.
  final bool suppressInlineHelp;

  /// La lista de mensajes ocupa el alto libre y el campo queda abajo.
  final bool expandMessages;

  /// Texto cuando todavía no hay mensajes.
  final String? emptyHint;

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
  String? _composeHint;
  final List<RealtimeChannel> _messageChannels = [];
  final Set<String> _resolvedRequestIds = {};
  String? _resolvingRequestId;

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
        _error = isJwtIssuedAtFutureError(e)
            ? 'El reloj local y Supabase no coinciden. Cierra el chat y ábrelo de nuevo en unos segundos.'
            : 'No se pudieron cargar los mensajes. Toque actualizar para reintentar.';
        _loading = false;
      });
    }
  }

  String? get _replyRole {
    if (widget.allowReplyAsAliado) return 'aliado';
    if (widget.allowReplyAsAdmin) return 'administrador';
    if (widget.allowReplyAsImportador) return 'importador';
    return null;
  }

  String _friendlySendError(Object error) {
    final raw = error.toString();
    if (raw.contains('plazo') || raw.contains('7 days') || raw.contains('7 días')) {
      return OrderReturnRules.closedHint;
    }
    return 'No se pudo enviar. Revise su conexión e intente de nuevo.';
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (_sending) return;
    if (text.isEmpty) {
      setState(() => _composeHint = 'Escriba el mensaje antes de enviarlo.');
      return;
    }

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
      if (mounted) setState(() => _composeHint = null);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlySendError(e))),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendAttachment({
    required bool video,
    required bool camera,
  }) async {
    if (_sending || _replyRole == null) return;
    PreparedOrderAttachment? prepared;
    try {
      prepared = video
          ? await prepareOrderChatVideo(fromCamera: camera)
          : await prepareOrderChatImage(fromCamera: camera);
    } on OrderMessageLimitException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
      return;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo obtener el archivo: $e')),
      );
      return;
    }
    if (prepared == null || !mounted) return;

    setState(() => _sending = true);
    try {
      await SupabaseService.sendOrderChatAttachment(
        transactionRequestId: widget.transactionRequestId,
        authorRole: _replyRole!,
        body: _ctrl.text.trim(),
        bytes: prepared.bytes,
        fileName: prepared.fileName,
        mime: prepared.mime,
        kind: prepared.kind,
      );
      _ctrl.clear();
      await _load();
    } on OrderMessageLimitException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlySendError(e))),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  TransactionRequestModel? _lineForMessage(
    TransactionRequestMessageModel message,
    ParsedReturnRequest data,
  ) {
    for (final line in widget.orderLines) {
      if (line.id == message.transactionRequestId) return line;
    }
    final name = data.productName.trim().toLowerCase();
    if (name.isEmpty) return null;
    for (final line in widget.orderLines) {
      final product = (line.productName ?? '').trim().toLowerCase();
      if (product == name) return line;
    }
    return null;
  }

  Future<void> _resolveReturn(
    TransactionRequestModel line,
    String resolution,
    String? note,
  ) async {
    setState(() => _resolvingRequestId = line.id);
    try {
      await OrdersService.resolveOrderPostventaCaso(
        transactionRequestId: line.id,
        resolution: resolution,
        note: note,
      );
      if (!mounted) return;
      setState(() => _resolvedRequestIds.add(line.id));
      await _load();
      widget.onThreadChanged?.call();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Acuerdo registrado en el chat.')),
      );
    } catch (e) {
      if (!mounted) return;
      final raw = e.toString();
      final message = RegExp(r'message:\s*([^,\n]+)')
              .firstMatch(raw)
              ?.group(1)
              ?.trim() ??
          'No se pudo registrar el acuerdo.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) setState(() => _resolvingRequestId = null);
    }
  }

  Widget _messageTile(String? uid, int i) {
    final m = _items[i];
    final request = OrderReturnRules.parseReturnRequestMessage(m.body);
    final line = request == null ? null : _lineForMessage(m, request);
    final mine = uid != null && m.authorId == uid;
    final label = mine
        ? 'Tú'
        : (m.isFromAdmin
            ? 'B2B Conecta'
            : (m.isFromImportador ? 'Importador' : 'Tienda minorista'));
    final align = mine ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bg = m.isFromAdmin
        ? AppColors.surfaceTinted.withOpacity(0.55)
        : (m.isFromImportador
            ? AppColors.brandBlueContainer
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
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 2),
        DecoratedBox(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            child: request == null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (m.body.trim().isNotEmpty)
                        Text(
                          m.body,
                          style: const TextStyle(fontSize: 13, height: 1.35),
                        ),
                      OrderMessageMediaStrip(attachments: m.attachments),
                    ],
                  )
                : OrderPostventaChatCard(
                    data: request,
                    attachments: m.attachments,
                    imageUrl: line == null
                        ? null
                        : productCoverImageUrl(line.productImageUrls),
                    creditAmount: line == null
                        ? 0
                        : OrderReturnRules.creditAmount(
                            unitPrice: line.precioUnitarioAliado,
                            lineTotal: line.precioTotal,
                            lineQty: line.cantidad,
                            affectedQty: request.units > 0
                                ? request.units
                                : line.cantidad,
                          ),
                    canDecide: widget.allowReplyAsImportador &&
                        line != null &&
                        line.postventaDevolucionAt != null &&
                        line.postventaResolucion == null &&
                        !_resolvedRequestIds.contains(line.id),
                    busy: _resolvingRequestId == line?.id,
                    onResolve: (resolution, note) =>
                        _resolveReturn(line!, resolution, note),
                  ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = SupabaseService.currentUserId;
    final canReply = widget.allowReplyAsAliado ||
        widget.allowReplyAsAdmin ||
        widget.allowReplyAsImportador;

    return Column(
      mainAxisSize:
          widget.expandMessages ? MainAxisSize.max : MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (!widget.suppressBuiltinTitle)
              Expanded(
                child: Text(
                  'Chat del pedido',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            if (!widget.suppressInlineHelp)
              const ProfileInfoIcon(
                title: 'Chat del pedido',
                message: OrderSectionHelp.chatPedido,
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
            widget.emptyHint ??
                (canReply
                    ? 'Aún no hay mensajes. Escriba aquí si tiene dudas sobre este pedido.'
                    : 'Sin mensajes en este pedido.'),
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          )
        else if (widget.expandMessages)
          Expanded(
            child: ListView.separated(
              itemCount: _items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) => _messageTile(uid, i),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) => _messageTile(uid, i),
          ),
        if (canReply) ...[
          if (widget.deliveryGrace) ...[
            const SizedBox(height: 10),
            Text(
              orderChatDeliveryGraceHint,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.35,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 10),
          TextField(
            controller: _ctrl,
            enabled: !_sending,
            onChanged: (_) {
              if (_composeHint != null) setState(() => _composeHint = null);
            },
            minLines: 1,
            maxLines: 4,
            textInputAction: TextInputAction.newline,
            decoration: InputDecoration(
              hintText: widget.allowReplyAsAdmin
                  ? 'Respuesta a la tienda minorista…'
                  : 'Escriba su mensaje…',
              errorText: _composeHint,
              isDense: true,
              border: const OutlineInputBorder(),
            ),
          ),
          OrderMessageAttachButtons(
            enabled: !_sending,
            onPhotoCamera: () => _sendAttachment(video: false, camera: true),
            onPhotoGallery: () => _sendAttachment(video: false, camera: false),
            onVideoCamera: () => _sendAttachment(video: true, camera: true),
            onVideoGallery: () => _sendAttachment(video: true, camera: false),
          ),
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
