import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:motolink_pro_app/app/app_scaffold_messenger.dart';
import 'package:motolink_pro_app/app/main_shell_tab.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/data/supabase_access.dart';
import 'package:motolink_pro_app/core/widgets/chat_conversation_widgets.dart';
import '../../core/layout/app_breakpoints.dart';
import '../orders/shared/mobile_chat_widgets.dart';
import '../orders/shared/order_message_attachment.dart';
import '../orders/shared/order_message_pick.dart';
import 'consultation_media.dart';

/// El botón de la vitrina solo lo ve la tienda, y no sobre su propio usuario.
bool showStoreSupplierChatButton({
  required String? viewerRole,
  required String? viewerId,
  required String importerId,
}) {
  final role = viewerRole?.trim().toLowerCase();
  final viewer = viewerId?.trim() ?? '';
  final importer = importerId.trim();
  return role == 'aliado' && viewer.isNotEmpty && viewer != importer;
}

class StoreSupplierThread {
  const StoreSupplierThread({
    required this.id,
    required this.aliadoId,
    required this.importadorId,
    this.aliadoName,
    this.importadorName,
    this.aliadoLogo,
    this.importadorLogo,
  });

  final String id;
  final String aliadoId;
  final String importadorId;
  final String? aliadoName;
  final String? importadorName;
  final String? aliadoLogo, importadorLogo;

  String? logoFor(String? userId) =>
      userId == aliadoId ? importadorLogo : aliadoLogo;

  String titleFor(String? userId) {
    final mine = userId?.trim();
    if (mine == aliadoId) {
      final name = importadorName?.trim();
      return (name == null || name.isEmpty) ? 'Proveedor' : name;
    }
    final name = aliadoName?.trim();
    return (name == null || name.isEmpty) ? 'Tienda' : name;
  }
}

class StoreSupplierProductContext {
  const StoreSupplierProductContext({
    required this.id,
    required this.name,
    this.sku,
  });

  final String id;
  final String name;
  final String? sku;

  String get label {
    final title = name.trim();
    final code = sku?.trim();
    if (title.isEmpty) return code ?? '';
    if (code == null || code.isEmpty) return title;
    return '$title · $code';
  }
}

class StoreSupplierMessage {
  const StoreSupplierMessage({
    required this.id,
    required this.threadId,
    required this.authorId,
    required this.authorRole,
    required this.body,
    this.createdAt,
    this.productId,
    this.productName,
    this.productSku,
    this.attachments = const [],
    this.consultationModel,
  });

  final String id;
  final String threadId;
  final String authorId;
  final String authorRole;
  final String body;
  final DateTime? createdAt;
  final String? productId;
  final String? productName;
  final String? productSku;
  final List<OrderMessageAttachment> attachments;
  final String? consultationModel;

  String get productLabel {
    final title = productName?.trim() ?? '';
    final code = productSku?.trim() ?? '';
    if (title.isEmpty) return code;
    if (code.isEmpty) return title;
    return '$title · $code';
  }

  factory StoreSupplierMessage.fromJson(Map<String, dynamic> json) {
    return StoreSupplierMessage(
      id: json['id']?.toString() ?? '',
      threadId: json['thread_id']?.toString() ?? '',
      authorId: json['author_id']?.toString() ?? '',
      authorRole: json['author_role']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      productId: json['product_id']?.toString(),
      productName: json['product_name']?.toString(),
      productSku: json['product_sku']?.toString(),
      attachments: parseOrderMessageAttachments(json['attachments']),
      consultationModel: json['consultation_model']?.toString(),
    );
  }
}

class StoreSupplierChatService {
  StoreSupplierChatService._();

  /// Reutiliza el hilo de esta tienda con ese proveedor, o lo crea.
  static Future<String> openOrCreate({required String importadorId}) async {
    final id = importadorId.trim();
    if (id.isEmpty) {
      throw ArgumentError('Proveedor inválido.');
    }
    final raw = await SupabaseAccess.client.rpc(
      'open_store_supplier_thread',
      params: <String, dynamic>{'p_importador_id': id},
    );
    final threadId = raw?.toString().trim() ?? '';
    if (threadId.isEmpty) {
      throw StateError('No se pudo abrir la conversación.');
    }
    return threadId;
  }

  static Future<StoreSupplierThread?> fetchThread(String threadId) async {
    final id = threadId.trim();
    if (id.isEmpty) return null;
    final row = await SupabaseAccess.client
        .from('store_supplier_threads')
        .select(
          'id, aliado_id, importador_id, '
          'aliado:profiles!store_supplier_threads_aliado_id_fkey(business_name,logo_storage_path), '
          'importador:profiles!store_supplier_threads_importador_id_fkey(business_name,logo_storage_path)',
        )
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    return StoreSupplierThread(
      id: row['id']?.toString() ?? id,
      aliadoId: row['aliado_id']?.toString() ?? '',
      importadorId: row['importador_id']?.toString() ?? '',
      aliadoName: _embeddedName(row['aliado']),
      importadorName: _embeddedName(row['importador']),
      aliadoLogo: _embeddedLogo(row['aliado']),
      importadorLogo: _embeddedLogo(row['importador']),
    );
  }

  static const _messageSelect =
      'id, thread_id, author_id, author_role, body, created_at, '
      'product_id, product_name, product_sku, attachments, consultation_model';
  static const _messageSelectLegacy =
      'id, thread_id, author_id, author_role, body, created_at';

  static Future<List<StoreSupplierMessage>> fetchMessages(
      String threadId) async {
    final id = threadId.trim();
    if (id.isEmpty) return const [];
    final response = await _selectMessages(id);
    final list = response as List<dynamic>;
    return list
        .map(
          (row) => StoreSupplierMessage.fromJson(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList();
  }

  static Future<dynamic> _selectMessages(String threadId) async {
    try {
      return await SupabaseAccess.client
          .from('store_supplier_messages')
          .select(_messageSelect)
          .eq('thread_id', threadId)
          .order('created_at', ascending: true);
    } on PostgrestException catch (e) {
      if (!_missingProductColumn(e)) rethrow;
      return SupabaseAccess.client
          .from('store_supplier_messages')
          .select(_messageSelectLegacy)
          .eq('thread_id', threadId)
          .order('created_at', ascending: true);
    }
  }

  static Future<void> send({
    required String threadId,
    required String authorRole,
    required String body,
    StoreSupplierProductContext? aboutProduct,
  }) async {
    final uid = SupabaseAccess.currentUserId;
    if (uid == null) throw StateError('No hay sesión activa.');
    final text = body.trim();
    if (text.isEmpty) return;
    final productId = aboutProduct?.id.trim() ?? '';
    final payload = <String, dynamic>{
      'thread_id': threadId,
      'author_id': uid,
      'author_role': authorRole,
      'body': text,
    };
    if (productId.isNotEmpty) payload['product_id'] = productId;
    try {
      await SupabaseAccess.client
          .from('store_supplier_messages')
          .insert(payload);
    } on PostgrestException catch (e) {
      if (productId.isEmpty || !_missingProductColumn(e)) rethrow;
      final label = aboutProduct?.label.trim() ?? '';
      payload.remove('product_id');
      payload['body'] = label.isEmpty ? text : 'Sobre $label\n$text';
      await SupabaseAccess.client
          .from('store_supplier_messages')
          .insert(payload);
    }
  }

  static bool _missingProductColumn(PostgrestException error) {
    return error.code == '42703' || error.message.contains('product_id');
  }

  /// Stable message IDs make a retry safe even when the first response was lost.
  static Future<void> sendConsultation(
      {required String threadId,
      required String messageId,
      required String body,
      String? model,
      PreparedOrderAttachment? photo,
      String authorRole = 'aliado',
      StoreSupplierProductContext? aboutProduct}) async {
    final uid = SupabaseAccess.currentUserId;
    if (uid == null) throw StateError('Inicia sesión para enviar la consulta.');
    final text = body.trim();
    if (text.isEmpty || text.length > 4000) {
      throw ArgumentError('Escribe tu consulta (máximo 4000 caracteres).');
    }
    if ((model?.trim().length ?? 0) > 160) {
      throw ArgumentError('El código o modelo supera 160 caracteres.');
    }
    final existing = await SupabaseAccess.client
        .from('store_supplier_messages')
        .select('id')
        .eq('id', messageId)
        .eq('thread_id', threadId)
        .eq('author_id', uid)
        .maybeSingle();
    if (existing != null) return;
    final attachments = <OrderMessageAttachment>[];
    if (photo != null) {
      attachments.add(await uploadConsultationPhoto(
          threadId: threadId, messageId: messageId, photo: photo));
    }
    try {
      await SupabaseAccess.client.from('store_supplier_messages').insert({
        'id': messageId,
        'thread_id': threadId,
        'author_id': uid,
        'author_role': authorRole,
        'body': text,
        'consultation_model':
            model?.trim().isEmpty == true ? null : model?.trim(),
        'attachments': attachments.map((a) => a.toJson()).toList(),
        if (aboutProduct != null) 'product_id': aboutProduct.id,
      });
    } on PostgrestException catch (error) {
      if (error.code != '23505') rethrow;
      final saved = await SupabaseAccess.client
          .from('store_supplier_messages')
          .select('id')
          .eq('id', messageId)
          .eq('thread_id', threadId)
          .eq('author_id', uid)
          .maybeSingle();
      if (saved == null) rethrow;
    }
  }

  static Future<void> markRead(String threadId) async {
    final uid = SupabaseAccess.currentUserId;
    final id = threadId.trim();
    if (uid == null || id.isEmpty) return;
    await SupabaseAccess.client
        .from('notifications')
        .update(<String, dynamic>{'is_read': true})
        .eq('user_id', uid)
        .eq('type', 'mensaje_directo')
        .eq('related_id', id)
        .eq('is_read', false);
  }

  static RealtimeChannel subscribe({
    required String threadId,
    required void Function() onInsert,
  }) {
    final id = threadId.trim();
    final channel = SupabaseAccess.client.channel('ssm:$id');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'store_supplier_messages',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'thread_id',
        value: id,
      ),
      callback: (_) => onInsert(),
    );
    channel.subscribe();
    return channel;
  }

  static Future<List<StoreSupplierInboxItem>> listInbox() async {
    const relation = 'store_supplier_messages';
    Future<List<StoreSupplierInboxItem>> load(String messageColumns) async {
      final result = <StoreSupplierInboxItem>[];
      const pageSize = 100;
      for (var offset = 0;; offset += pageSize) {
        final rows = await SupabaseAccess.client
            .from('store_supplier_threads')
            .select(
              'id, aliado_id, importador_id, created_at, '
              'aliado:profiles!store_supplier_threads_aliado_id_fkey(business_name,logo_storage_path), '
              'importador:profiles!store_supplier_threads_importador_id_fkey(business_name,logo_storage_path), '
              '$relation($messageColumns)',
            )
            .order('id')
            .order('created_at', ascending: false, referencedTable: relation)
            .order('id', ascending: false, referencedTable: relation)
            .limit(1, referencedTable: relation)
            .range(offset, offset + pageSize - 1);
        for (final row in rows) {
          final messages = row[relation] as List;
          final latest = messages.isEmpty
              ? null
              : StoreSupplierMessage.fromJson(
                  Map<String, dynamic>.from(messages.first as Map));
          result.add(StoreSupplierInboxItem(
            thread: StoreSupplierThread(
              id: row['id'] as String,
              aliadoId: row['aliado_id'] as String,
              importadorId: row['importador_id'] as String,
              aliadoName: _embeddedName(row['aliado']),
              importadorName: _embeddedName(row['importador']),
              aliadoLogo: _embeddedLogo(row['aliado']),
              importadorLogo: _embeddedLogo(row['importador']),
            ),
            lastBody: latest?.body,
            lastProduct: latest?.productLabel,
            lastAt: latest?.createdAt ??
                DateTime.tryParse(row['created_at']?.toString() ?? ''),
          ));
        }
        if (rows.length < pageSize) return result;
      }
    }

    try {
      return await load(_messageSelect);
    } on PostgrestException catch (error) {
      if (!_missingProductColumn(error)) rethrow;
      return load('id, thread_id, author_id, author_role, body, created_at');
    }
  }

  static String? _embeddedName(dynamic raw) {
    if (raw is Map) {
      final name = raw['business_name']?.toString().trim();
      if (name != null && name.isNotEmpty) return name;
    }
    if (raw is List && raw.isNotEmpty && raw.first is Map) {
      return _embeddedName(raw.first);
    }
    return null;
  }

  static String? _embeddedLogo(dynamic raw) {
    if (raw is Map) return raw['logo_storage_path']?.toString();
    if (raw is List && raw.isNotEmpty) return _embeddedLogo(raw.first);
    return null;
  }
}

class StoreSupplierInboxItem {
  const StoreSupplierInboxItem({
    required this.thread,
    this.lastBody,
    this.lastProduct,
    this.lastAt,
  });

  final StoreSupplierThread thread;
  final String? lastBody;
  final String? lastProduct;
  final DateTime? lastAt;
}

/// Abre el hilo encima de la ruta actual. No cambia de pestaña.
void openStoreSupplierChat(String threadId) {
  final id = threadId.trim();
  final nav = rootNavigatorKey.currentState;
  if (id.isEmpty || nav == null) return;
  nav.push<void>(
    MaterialPageRoute<void>(
      builder: (_) => StoreSupplierChatScreen(threadId: id),
    ),
  );
}

class StoreSupplierChatScreen extends StatefulWidget {
  const StoreSupplierChatScreen({
    super.key,
    required this.threadId,
    this.aboutProduct,
    this.embedded = false,
    this.onActivity,
  });

  final String threadId;

  /// Si viene de la ficha, el próximo mensaje queda ligado a ese producto.
  final StoreSupplierProductContext? aboutProduct;
  final bool embedded;
  final VoidCallback? onActivity;

  @override
  State<StoreSupplierChatScreen> createState() =>
      _StoreSupplierChatScreenState();
}

class _StoreSupplierChatScreenState extends State<StoreSupplierChatScreen> {
  final _ctrl = TextEditingController();
  StoreSupplierThread? _thread;
  List<StoreSupplierMessage> _items = const [];
  bool _loading = true;
  bool _sending = false;
  PreparedOrderAttachment? _photo;
  String? _pendingMessageId;
  bool _pickingPhoto = false;
  String? _error;
  StoreSupplierProductContext? _aboutProduct;
  RealtimeChannel? _channel;

  String? get _myRole {
    final uid = SupabaseAccess.currentUserId;
    final thread = _thread;
    if (uid == null || thread == null) return null;
    if (uid == thread.aliadoId) return 'aliado';
    if (uid == thread.importadorId) return 'importador';
    return null;
  }

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_draftChanged);
    final about = widget.aboutProduct;
    if (about != null && about.id.trim().isNotEmpty) {
      _aboutProduct = about;
    }
    _channel = StoreSupplierChatService.subscribe(
      threadId: widget.threadId,
      onInsert: () {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _load();
            widget.onActivity?.call();
          }
        });
        SchedulerBinding.instance.ensureVisualUpdate();
      },
    );
    _load();
  }

  void _draftChanged() => _pendingMessageId = null;

  @override
  void dispose() {
    final channel = _channel;
    _channel = null;
    if (channel != null) {
      SupabaseAccess.unsubscribeChannel(channel);
    }
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final thread =
          await StoreSupplierChatService.fetchThread(widget.threadId);
      final items = thread == null
          ? const <StoreSupplierMessage>[]
          : await StoreSupplierChatService.fetchMessages(widget.threadId);
      if (!mounted) return;
      setState(() {
        _thread = thread;
        _items = items;
        _loading = false;
        _error =
            thread == null ? 'No tienes acceso a esta conversación.' : null;
      });
      if (thread != null) {
        try {
          await StoreSupplierChatService.markRead(widget.threadId);
          MainShellTabController.requestNotificationsReload();
        } catch (_) {
          // The conversation is still available if read receipts fail.
        }
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Revisa tu conexión e inténtalo de nuevo.';
      });
    }
  }

  Future<void> _send() async {
    final role = _myRole;
    final text = _ctrl.text.trim().isEmpty && _photo != null
        ? 'Foto de referencia'
        : _ctrl.text.trim();
    if (role == null || text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      if (_photo != null) {
        _pendingMessageId ??= newConsultationMessageId();
        await StoreSupplierChatService.sendConsultation(
            threadId: widget.threadId,
            messageId: _pendingMessageId!,
            authorRole: role,
            body: text,
            photo: _photo,
            aboutProduct: _aboutProduct);
      } else {
        await StoreSupplierChatService.send(
          threadId: widget.threadId,
          authorRole: role,
          body: text,
          aboutProduct: _aboutProduct,
        );
      }
      if (!mounted) return;
      _ctrl.clear();
      _photo = null;
      _pendingMessageId = null;
      await _load();
      if (mounted) widget.onActivity?.call();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo enviar. Inténtalo de nuevo.')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pickPhoto(bool camera) async {
    if (_sending || _pickingPhoto) return;
    setState(() => _pickingPhoto = true);
    try {
      final photo = await prepareOrderChatImage(fromCamera: camera);
      if (mounted && photo != null) {
        setState(() {
          _photo = photo;
          _pendingMessageId = null;
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'No se pudo adjuntar la foto. Usa JPG, PNG o WEBP de hasta 8 MB.')));
      }
    } finally {
      if (mounted) setState(() => _pickingPhoto = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = SupabaseAccess.currentUserId;
    final mobile = MediaQuery.sizeOf(context).width < AppBreakpoints.mobileMenu;
    final title = _thread?.titleFor(uid) ?? 'Mensajes';
    final product = _aboutProduct;
    final latestProduct = _items.lastOrNull?.productLabel ?? '';
    final reference = _items.where((m) => m.authorRole == 'aliado').lastOrNull;
    return Scaffold(
      appBar: mobile
          ? MobileChatAppBar(
              title: title,
              subtitle: 'Consulta de repuesto',
              showAvatar: _thread != null,
              logoPath: _thread?.logoFor(uid),
              automaticallyImplyLeading: !widget.embedded,
              actions: [
                  PopupMenuButton<void>(
                      tooltip: 'Opciones del chat',
                      itemBuilder: (_) => [
                            PopupMenuItem<void>(
                                onTap: _load,
                                enabled: !_loading,
                                child: const Text('Actualizar mensajes'))
                          ])
                ])
          : consultationAppBar(
              automaticallyImplyLeading: !widget.embedded,
              title: title,
              subtitle: 'Consulta de repuesto',
              actions: [
                  PopupMenuButton<void>(
                      tooltip: 'Opciones del chat',
                      itemBuilder: (_) => [
                            PopupMenuItem<void>(
                                onTap: _load,
                                enabled: !_loading,
                                child: const Text('Actualizar mensajes'))
                          ])
                ]),
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Divider(height: 1),
            Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text('Disponible en Chats → Consultas',
                    style:
                        TextStyle(fontSize: 12, color: AppColors.brandLink))),
            if (latestProduct.isNotEmpty)
              Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('Último producto: $latestProduct',
                      maxLines: 2, overflow: TextOverflow.ellipsis)),
            if (reference != null)
              Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: Material(
                      color: AppColors.surfaceTinted,
                      borderRadius: BorderRadius.circular(12),
                      child: ListTile(
                          dense: true,
                          title: Text(reference.body,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle:
                              reference.consultationModel?.isNotEmpty == true
                                  ? Text(reference.consultationModel!)
                                  : null,
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => showDialog<void>(
                              context: context,
                              builder: (context) => AlertDialog(
                                      title: const Text('Consulta de repuesto'),
                                      content: SingleChildScrollView(
                                          child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                            Text(reference.body),
                                            if (reference.consultationModel
                                                    ?.isNotEmpty ==
                                                true)
                                              Text(
                                                  reference.consultationModel!),
                                            for (final attachment
                                                in reference.attachments)
                                              ConsultationPhoto(
                                                  attachment: attachment)
                                          ])),
                                      actions: [
                                        TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context),
                                            child: const Text('Cerrar'))
                                      ]))))),
            if (_loading && _items.isNotEmpty)
              const LinearProgressIndicator(minHeight: 2),
            if (_error != null && _items.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(_error!,
                    style: TextStyle(color: AppColors.textSecondary)),
              ),
            Expanded(
              child: _items.isNotEmpty
                  ? ChatTimeline(
                      mobileStyle: mobile,
                      itemCount: _items.length,
                      dateAt: (i) => _items[i].createdAt,
                      messageAt: (i) => _messageBubble(_items[i], uid),
                    )
                  : _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _error != null
                          ? ChatConversationNotice(
                              title: 'No se pudo abrir la consulta',
                              description: _error,
                              icon: Icons.info_outline,
                              onRetry: _load,
                            )
                          : const ChatConversationNotice(
                              title: 'Inicia la conversación',
                              description: 'Escribe tu consulta aquí abajo.',
                            ),
            ),
            if (_photo != null)
              Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(children: [
                    Image.memory(_photo!.bytes,
                        width: 64, height: 64, fit: BoxFit.cover),
                    const SizedBox(width: 8),
                    const Expanded(child: Text('Foto de referencia')),
                    IconButton(
                        tooltip: 'Quitar foto',
                        onPressed: _sending
                            ? null
                            : () => setState(() {
                                  _photo = null;
                                  _pendingMessageId = null;
                                }),
                        icon: const Icon(Icons.close))
                  ])),
            if (_myRole != null)
              ChatComposer(
                mobileStyle: mobile,
                controller: _ctrl,
                sending: _sending,
                onSend: _send,
                hasAttachment: _photo != null,
                leading: PopupMenuButton<bool>(
                    tooltip: 'Adjuntar foto',
                    enabled: !_sending && !_pickingPhoto,
                    icon: const Icon(Icons.attach_file),
                    onSelected: _pickPhoto,
                    itemBuilder: (_) => [
                          const PopupMenuItem(
                              value: false, child: Text('Agregar foto')),
                          const PopupMenuItem(
                              value: true, child: Text('Tomar foto'))
                        ]),
                contextNote: product == null || product.label.isEmpty
                    ? null
                    : Row(
                        children: [
                          const Icon(Icons.inventory_2_outlined, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text('Sobre ${product.label}',
                                maxLines: 2, overflow: TextOverflow.ellipsis),
                          ),
                          IconButton(
                            tooltip: 'Quitar el producto',
                            onPressed: _sending
                                ? null
                                : () => setState(() => _aboutProduct = null),
                            icon: const Icon(Icons.close, size: 18),
                          ),
                        ],
                      ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _messageBubble(StoreSupplierMessage message, String? uid) {
    final product = message.productLabel;
    return ChatMessageBubble(
      mobileStyle: MediaQuery.sizeOf(context).width < AppBreakpoints.mobileMenu,
      key: ValueKey(message.id),
      mine: uid != null && message.authorId == uid,
      at: message.createdAt,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (product.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                'Sobre $product',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          Text(message.body, style: const TextStyle(height: 1.35)),
          if (message.consultationModel?.isNotEmpty == true)
            Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('Código o modelo: ${message.consultationModel}',
                    style: const TextStyle(fontWeight: FontWeight.w600))),
          for (final attachment in message.attachments)
            ConsultationPhoto(attachment: attachment),
        ],
      ),
    );
  }
}
