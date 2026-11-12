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
import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'package:motolink_pro_app/core/widgets/chat_conversation_widgets.dart';
import 'package:motolink_pro_app/app/main_shell_tab.dart';
import 'order_card_collapsible_layout.dart';
import 'package:motolink_pro_app/features/inventory/product_images.dart';

enum _ChatAction { refresh, help }

enum _ChatAttachment { photoCamera, photoGallery, videoCamera, videoGallery }

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
    this.conversationContext,
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
  final Widget? conversationContext;

  /// Texto cuando todavía no hay mensajes.
  final String? emptyHint;

  @override
  State<OrderMotolinkThreadSection> createState() =>
      _OrderMotolinkThreadSectionState();
}

class _OrderMotolinkThreadSectionState
    extends State<OrderMotolinkThreadSection> {
  final _ctrl = TextEditingController();
  List<TransactionRequestMessageModel> _items = [];
  bool _loading = true;
  bool _sending = false;
  bool _pickingAttachment = false;
  PreparedOrderAttachment? _attachment;
  String? _error;
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
          if (widget.expandMessages &&
              ModalRoute.of(context)?.isCurrent == true) {
            unawaited(_refreshReadReceipt());
          }
          widget.onThreadChanged?.call();
        }
      });
      SchedulerBinding.instance.ensureVisualUpdate();
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

  Future<void> _refreshReadReceipt() async {
    try {
      await _markNotificationsReadAsync();
      MainShellTabController.requestNotificationsReload();
    } catch (_) {
      // A temporary receipt failure should not block message access.
    }
  }

  @override
  void initState() {
    super.initState();
    unawaited(_refreshReadReceipt());
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
      _attachment = null;
      unawaited(_refreshReadReceipt());
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
    if (raw.contains('plazo') ||
        raw.contains('7 days') ||
        raw.contains('7 días')) {
      return OrderReturnRules.closedHint;
    }
    return 'No se pudo enviar. Revise su conexión e intente de nuevo.';
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    final attachment = _attachment;
    final role = _replyRole;
    if (_sending ||
        _pickingAttachment ||
        role == null ||
        (text.isEmpty && attachment == null)) {
      return;
    }

    setState(() => _sending = true);
    try {
      if (attachment != null) {
        await SupabaseService.sendOrderChatAttachment(
          transactionRequestId: widget.transactionRequestId,
          authorRole: role,
          body: text,
          bytes: attachment.bytes,
          fileName: attachment.fileName,
          mime: attachment.mime,
          kind: attachment.kind,
        );
      } else if (widget.allowReplyAsAliado) {
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
      if (!mounted) return;
      _ctrl.clear();
      setState(() => _attachment = null);
      await _load();
      if (mounted) widget.onThreadChanged?.call();
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

  Future<void> _pickAttachment({
    required bool video,
    required bool camera,
  }) async {
    if (_sending || _pickingAttachment || _replyRole == null) return;
    final requestId = widget.transactionRequestId;
    setState(() => _pickingAttachment = true);
    try {
      final prepared = video
          ? await prepareOrderChatVideo(fromCamera: camera)
          : await prepareOrderChatImage(fromCamera: camera);
      if (mounted &&
          prepared != null &&
          requestId == widget.transactionRequestId) {
        setState(() => _attachment = prepared);
      }
    } on OrderMessageLimitException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo adjuntar el archivo.')),
      );
    } finally {
      if (mounted) setState(() => _pickingAttachment = false);
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
      final message =
          RegExp(r'message:\s*([^,\n]+)').firstMatch(raw)?.group(1)?.trim() ??
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
    final author = m.isFromAdmin
        ? 'B2B Conecta'
        : widget.allowReplyAsAdmin && !mine
            ? (m.isFromImportador ? 'Importador' : 'Tienda minorista')
            : null;
    return ChatMessageBubble(
      key: ValueKey(m.id),
      mine: mine,
      at: m.createdAt,
      author: author,
      isAction: request != null,
      showDate: !widget.expandMessages,
      child: request == null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (m.body.trim().isNotEmpty)
                  Text(m.body, style: const TextStyle(height: 1.35)),
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
                      affectedQty:
                          request.units > 0 ? request.units : line.cantidad,
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
    );
  }

  void _handleChatAction(_ChatAction action) {
    if (action == _ChatAction.refresh) {
      _load();
      return;
    }
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chat del pedido'),
        content: const Text(OrderSectionHelp.chatPedido),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  Widget _attachmentMenu() {
    final theme = B2BThemeExtension.of(context);
    return PopupMenuButton<_ChatAttachment>(
      tooltip: 'Adjuntar foto o video',
      enabled: !_sending && !_pickingAttachment,
      icon: Icon(Icons.attach_file_rounded, color: theme.textSecondary),
      position: PopupMenuPosition.over,
      onSelected: (attachment) => _pickAttachment(
        video: attachment == _ChatAttachment.videoCamera ||
            attachment == _ChatAttachment.videoGallery,
        camera: attachment == _ChatAttachment.photoCamera ||
            attachment == _ChatAttachment.videoCamera,
      ),
      itemBuilder: (context) => const [
        PopupMenuItem(
            value: _ChatAttachment.photoCamera, child: Text('Tomar foto')),
        PopupMenuItem(
            value: _ChatAttachment.photoGallery, child: Text('Elegir foto')),
        PopupMenuItem(
            value: _ChatAttachment.videoCamera, child: Text('Grabar video')),
        PopupMenuItem(
            value: _ChatAttachment.videoGallery, child: Text('Elegir video')),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = SupabaseService.currentUserId;
    final canReply = _replyRole != null;
    final attachment = _attachment;
    final Widget messages;
    if (_loading && _items.isEmpty) {
      messages = const Center(child: CircularProgressIndicator());
    } else if (_error != null && _items.isEmpty) {
      messages = ChatConversationNotice(
        title: 'No se pudo cargar el chat',
        description: _error,
        icon: Icons.info_outline,
        onRetry: _load,
      );
    } else if (_items.isEmpty) {
      messages = ChatConversationNotice(
        title: canReply
            ? '¿Tienes una duda sobre este pedido?'
            : 'Este pedido aún no tiene mensajes',
        description: widget.emptyHint ??
            (canReply ? 'Escribe aquí para iniciar la conversación.' : null),
      );
    } else if (widget.expandMessages) {
      messages = ChatTimeline(
        itemCount: _items.length,
        dateAt: (i) => _items[i].createdAt,
        messageAt: (i) => _messageTile(uid, i),
      );
    } else {
      messages = ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) => _messageTile(uid, i),
      );
    }
    return Column(
      mainAxisSize: widget.expandMessages ? MainAxisSize.max : MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 14, end: 6),
          child: Row(
            children: [
              Expanded(
                child: widget.conversationContext ??
                    (widget.suppressBuiltinTitle
                        ? const SizedBox.shrink()
                        : const Text('Chat del pedido',
                            style: TextStyle(fontWeight: FontWeight.w700))),
              ),
              PopupMenuButton<_ChatAction>(
                tooltip: 'Opciones del chat',
                onSelected: _handleChatAction,
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: _ChatAction.refresh,
                    enabled: !_loading,
                    child: const Text('Actualizar mensajes'),
                  ),
                  if (!widget.suppressInlineHelp)
                    const PopupMenuItem(
                      value: _ChatAction.help,
                      child: Text('Ayuda del chat'),
                    ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        if (_loading && _items.isNotEmpty)
          const LinearProgressIndicator(minHeight: 2),
        if (_error != null && _items.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(8),
            child:
                Text(_error!, style: TextStyle(color: AppColors.textSecondary)),
          ),
        if (widget.expandMessages) Expanded(child: messages) else messages,
        if (canReply)
          ChatComposer(
            controller: _ctrl,
            onSend: _send,
            sending: _sending || _pickingAttachment,
            hasAttachment: attachment != null,
            hint: widget.allowReplyAsAdmin
                ? 'Respuesta a la tienda minorista…'
                : 'Escribe un mensaje…',
            leading: _attachmentMenu(),
            contextNote: !widget.deliveryGrace && attachment == null
                ? null
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.deliveryGrace)
                        Text(
                          orderChatDeliveryGraceHint,
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textSecondary),
                        ),
                      if (attachment != null)
                        Row(
                          children: [
                            const Icon(Icons.attach_file_rounded, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                attachment.fileName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Quitar adjunto',
                              onPressed: _sending || _pickingAttachment
                                  ? null
                                  : () => setState(() => _attachment = null),
                              icon: const Icon(Icons.close, size: 18),
                            ),
                          ],
                        ),
                    ],
                  ),
          )
        else
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              'Solo lectura',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
      ],
    );
  }
}
