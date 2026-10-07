import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:motolink_pro_app/app/app_scaffold_messenger.dart';
import 'package:motolink_pro_app/app/main_shell_tab.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/data/supabase_access.dart';
import 'package:motolink_pro_app/core/utils/app_date_format.dart';

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
  });

  final String id;
  final String aliadoId;
  final String importadorId;
  final String? aliadoName;
  final String? importadorName;

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
          'aliado:profiles!store_supplier_threads_aliado_id_fkey(business_name), '
          'importador:profiles!store_supplier_threads_importador_id_fkey(business_name)',
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
    );
  }

  static const _messageSelect =
      'id, thread_id, author_id, author_role, body, created_at, '
      'product_id, product_name, product_sku';
  static const _messageSelectLegacy =
      'id, thread_id, author_id, author_role, body, created_at';

  static Future<List<StoreSupplierMessage>> fetchMessages(String threadId) async {
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
      await SupabaseAccess.client.from('store_supplier_messages').insert(payload);
    } on PostgrestException catch (e) {
      if (productId.isEmpty || !_missingProductColumn(e)) rethrow;
      final label = aboutProduct?.label.trim() ?? '';
      payload.remove('product_id');
      payload['body'] = label.isEmpty ? text : 'Sobre $label\n$text';
      await SupabaseAccess.client.from('store_supplier_messages').insert(payload);
    }
  }

  static bool _missingProductColumn(PostgrestException error) {
    return error.code == '42703' || error.message.contains('product_id');
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
  });

  final String threadId;

  /// Si viene de la ficha, el próximo mensaje queda ligado a ese producto.
  final StoreSupplierProductContext? aboutProduct;

  @override
  State<StoreSupplierChatScreen> createState() => _StoreSupplierChatScreenState();
}

class _StoreSupplierChatScreenState extends State<StoreSupplierChatScreen> {
  final _ctrl = TextEditingController();
  StoreSupplierThread? _thread;
  List<StoreSupplierMessage> _items = const [];
  bool _loading = true;
  bool _sending = false;
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
    final about = widget.aboutProduct;
    if (about != null && about.id.trim().isNotEmpty) {
      _aboutProduct = about;
    }
    _channel = StoreSupplierChatService.subscribe(
      threadId: widget.threadId,
      onInsert: () {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted) _load();
        });
      },
    );
    _load();
  }

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
    try {
      final thread = await StoreSupplierChatService.fetchThread(widget.threadId);
      final items = thread == null
          ? const <StoreSupplierMessage>[]
          : await StoreSupplierChatService.fetchMessages(widget.threadId);
      if (thread != null) {
        await StoreSupplierChatService.markRead(widget.threadId);
        MainShellTabController.requestNotificationsReload();
      }
      if (!mounted) return;
      setState(() {
        _thread = thread;
        _items = items;
        _loading = false;
        _error = thread == null ? 'No tienes acceso a esta conversación.' : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _send() async {
    final role = _myRole;
    final text = _ctrl.text.trim();
    if (role == null || text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await StoreSupplierChatService.send(
        threadId: widget.threadId,
        authorRole: role,
        body: text,
        aboutProduct: _aboutProduct,
      );
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
    final uid = SupabaseAccess.currentUserId;
    final title = _thread?.titleFor(uid) ?? 'Mensajes';
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.brand),
                  )
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(_error!, textAlign: TextAlign.center),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final m = _items[i];
                          final mine = uid != null && m.authorId == uid;
                          return Align(
                            alignment: mine
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 320),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: mine
                                      ? AppColors.brandBlue.withOpacity(0.12)
                                      : AppColors.card,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppColors.borderSubtle),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        formatEsShortDateTime(m.createdAt),
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      if (m.productLabel.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          'Sobre ${m.productLabel}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 2),
                                      Text(m.body),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
          if (_myRole != null)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_aboutProduct != null &&
                        _aboutProduct!.label.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Material(
                          color: AppColors.brand.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                          child: ListTile(
                            dense: true,
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 12),
                            title: Text(
                              'Pregunta sobre ${_aboutProduct!.label}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            trailing: IconButton(
                              tooltip: 'Quitar el producto',
                              onPressed: () =>
                                  setState(() => _aboutProduct = null),
                              icon: const Icon(Icons.close, size: 18),
                            ),
                          ),
                        ),
                      ),
                    Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _ctrl,
                        enabled: !_sending,
                        minLines: 1,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: _aboutProduct == null
                              ? 'Escriba su mensaje…'
                              : 'Pregunte sobre este producto…',
                          isDense: true,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _sending ? null : _send,
                      child: const Text('Enviar'),
                    ),
                  ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
