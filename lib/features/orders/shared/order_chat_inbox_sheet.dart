import 'dart:async';

import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/app/main_shell_tab.dart';
import 'package:motolink_pro_app/core/data/supabase_access.dart';
import 'package:motolink_pro_app/core/notifications/notification_provider.dart';
import 'package:motolink_pro_app/core/utils/app_date_format.dart';
import 'package:motolink_pro_app/core/widgets/app_date_picker.dart';
import 'package:motolink_pro_app/features/catalog/store_supplier_chat.dart';
import 'package:motolink_pro_app/features/orders/shared/order_chat_launch.dart';
import 'package:motolink_pro_app/features/orders/shared/order_chat_thread.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_model.dart';
import 'package:motolink_pro_app/features/profile/app_home_role.dart';

import 'order_motolink_thread_section.dart';
import 'order_return_rules.dart';
import 'orders_service.dart';
import 'transaction_request_message_model.dart';

/// Abre la bandeja de chats desde Pedidos. El encabezado ya no lleva el icono.
class OrderChatsEntryButton extends StatelessWidget {
  const OrderChatsEntryButton({super.key, required this.homeRole});

  final AppHomeRole homeRole;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => showOrderChatInboxSheet(
        context: context,
        homeRole: homeRole,
      ),
      icon: const Icon(Icons.forum_outlined, size: 18),
      label: const Text('Chats'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.brand,
        side: const BorderSide(color: AppColors.brand),
        visualDensity: VisualDensity.compact,
        minimumSize: const Size(0, 36),
      ),
    );
  }
}

enum _ChatKind { pedidos, consultas }

enum _DatePreset { all, today, days7, days30, custom }

Future<void> showOrderChatInboxSheet({
  required BuildContext context,
  required AppHomeRole homeRole,
  Future<List<TransactionRequestModel>> Function()? fetchOrders,
  bool Function()? hasSession,
}) {
  return Navigator.of(context)
      .push<void>(
    MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Chats'),
          backgroundColor: AppColors.card,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
        ),
        body: OrderChatInboxSheet(
          homeRole: homeRole,
          fetchOrders: fetchOrders,
          hasSession: hasSession,
          asPage: true,
        ),
      ),
    ),
  )
      .whenComplete(() {
    NotificationProvider.active?.reload();
  });
}

/// Bandeja de hilos de pedido (no incluye tickets de soporte).
class OrderChatInboxSheet extends StatefulWidget {
  const OrderChatInboxSheet({
    super.key,
    required this.homeRole,
    this.fetchOrders,
    this.hasSession,
    this.asPage = false,
  });

  final AppHomeRole homeRole;
  final Future<List<TransactionRequestModel>> Function()? fetchOrders;
  final bool Function()? hasSession;
  final bool asPage;

  @override
  State<OrderChatInboxSheet> createState() => _OrderChatInboxSheetState();
}

class _OrderChatInboxSheetState extends State<OrderChatInboxSheet> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  final _provider = NotificationProvider.active;
  OrderChatInboxFilter _filter = OrderChatInboxFilter.all;
  _ChatKind _kind = _ChatKind.pedidos;
  _DatePreset _datePreset = _DatePreset.all;
  DateTime? _customFrom;
  DateTime? _customTo;
  List<OrderChatThread> _threads = [];
  List<StoreSupplierInboxItem> _consultas = [];
  Map<String, TransactionRequestMessageModel> _latest = {};
  bool _loading = true;
  bool _ordersError = false;
  bool _consultasError = false;
  bool _previewError = false;
  bool _signedOut = false;
  bool _unreadOnly = false;
  String? _selectedId;
  Timer? _refreshTimer;
  Set<String> _seenMessageNotifications = {};

  bool get _hasSession =>
      widget.hasSession?.call() ?? SupabaseAccess.currentUserId != null;
  bool get _hasFilters =>
      _datePreset != _DatePreset.all ||
      (_kind == _ChatKind.pedidos && _filter != OrderChatInboxFilter.all);
  bool get _isAdmin => widget.homeRole == AppHomeRole.administrador;

  @override
  void initState() {
    super.initState();
    _seenMessageNotifications = _messageNotificationIds();
    _provider?.addListener(_onNotifications);
    _load();
  }

  @override
  void dispose() {
    _provider?.removeListener(_onNotifications);
    _refreshTimer?.cancel();
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  Set<String> _messageNotificationIds() => {
        for (final item in _provider?.items ?? const [])
          if (item.type.trim() == 'mensaje' ||
              item.type.trim() == 'mensaje_directo')
            item.id,
      };

  void _onNotifications() {
    final ids = _messageNotificationIds();
    final hasNewMessage = ids.difference(_seenMessageNotifications).isNotEmpty;
    _seenMessageNotifications = ids;
    if (hasNewMessage) _scheduleRefresh();
  }

  void _scheduleRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      if (_loading) {
        _scheduleRefresh();
      } else {
        unawaited(_load(quiet: true));
      }
    });
  }

  Future<void> _load({bool quiet = false}) async {
    if (!_hasSession) {
      setState(() {
        _signedOut = true;
        _loading = false;
        _threads = [];
        _consultas = [];
        _latest = {};
        _selectedId = null;
      });
      return;
    }
    setState(() {
      _signedOut = false;
      _loading = true;
    });
    final directFuture = _loadConsultas();
    final orders = await _loadOrders();
    final direct = await directFuture;
    if (!mounted) return;
    setState(() {
      _ordersError = orders == null;
      _consultasError = direct == null;
      if (orders != null) {
        _threads = orders.threads;
        _previewError = orders.latest == null;
        if (orders.latest != null) _latest = orders.latest!;
      }
      if (direct != null) _consultas = direct;
      _loading = false;
    });
    if (!quiet) unawaited(_provider?.reload());
  }

  Future<
      ({
        List<OrderChatThread> threads,
        Map<String, TransactionRequestMessageModel>? latest
      })?> _loadOrders() async {
    try {
      final rows = await (widget.fetchOrders?.call() ??
          fetchOrdersForChatInbox(widget.homeRole));
      final threads = orderChatThreadsFromOrders(rows, role: widget.homeRole);
      Map<String, TransactionRequestMessageModel>? latest;
      try {
        latest = await OrdersService.fetchOrderChatPreviews(
            threads.expand((t) => t.requestIds));
      } catch (_) {
        // The order list remains useful if previews are temporarily unavailable.
      }
      return (threads: threads, latest: latest);
    } catch (_) {
      return null;
    }
  }

  Future<List<StoreSupplierInboxItem>?> _loadConsultas() async {
    if (_isAdmin) return [];
    try {
      return await StoreSupplierChatService.listInbox();
    } catch (_) {
      return null;
    }
  }

  int _orderUnread(List<String> ids) =>
      _provider?.unreadMensajeCountFor(ids) ?? 0;
  int _directUnread(String id) => _provider?.unreadDirectChatCountFor(id) ?? 0;

  TransactionRequestMessageModel? _preview(OrderChatThread thread) {
    TransactionRequestMessageModel? latest;
    for (final id in thread.requestIds) {
      final message = _latest[id];
      if (message == null) continue;
      if (latest == null ||
          (message.createdAt != null &&
              (latest.createdAt == null ||
                  message.createdAt!.isAfter(latest.createdAt!)))) {
        latest = message;
      }
    }
    return latest;
  }

  DateTime? _activity(OrderChatThread thread) =>
      _preview(thread)?.createdAt ?? thread.lines.firstOrNull?.createdAt;

  (DateTime?, DateTime?) get _range {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return switch (_datePreset) {
      _DatePreset.all => (null, null),
      _DatePreset.today => (today, today),
      _DatePreset.days7 => (
          DateTime(today.year, today.month, today.day - 6),
          today
        ),
      _DatePreset.days30 => (
          DateTime(today.year, today.month, today.day - 29),
          today
        ),
      _DatePreset.custom => (_customFrom, _customTo),
    };
  }

  String _dateLabel(_DatePreset preset) => switch (preset) {
        _DatePreset.all => 'Cualquier fecha',
        _DatePreset.today => 'Hoy',
        _DatePreset.days7 => 'Últimos 7 días',
        _DatePreset.days30 => 'Últimos 30 días',
        _DatePreset.custom => 'Rango personalizado',
      };

  String _statusLabel(OrderChatInboxFilter filter) => switch (filter) {
        OrderChatInboxFilter.active => 'Activos',
        OrderChatInboxFilter.closed => 'Solo lectura',
        _ => 'Cualquier estado',
      };

  void _clear() {
    setState(() {
      _search.clear();
      _unreadOnly = false;
      _filter = OrderChatInboxFilter.all;
      _datePreset = _DatePreset.all;
      _customFrom = null;
      _customTo = null;
    });
  }

  Future<void> _editFilters() async {
    var status = _filter;
    var date = _datePreset;
    final result = await showDialog<(OrderChatInboxFilter, _DatePreset)>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Filtrar chats'),
          scrollable: true,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_kind == _ChatKind.pedidos)
                DropdownButtonFormField<OrderChatInboxFilter>(
                  value: status,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Estado'),
                  items: [
                    for (final value in [
                      OrderChatInboxFilter.all,
                      OrderChatInboxFilter.active,
                      OrderChatInboxFilter.closed
                    ])
                      DropdownMenuItem(
                          value: value, child: Text(_statusLabel(value))),
                  ],
                  onChanged: (value) => update(() => status = value!),
                ),
              DropdownButtonFormField<_DatePreset>(
                value: date,
                isExpanded: true,
                decoration:
                    const InputDecoration(labelText: 'Fecha de actividad'),
                items: [
                  for (final value in _DatePreset.values)
                    DropdownMenuItem(
                        value: value, child: Text(_dateLabel(value))),
                ],
                onChanged: (value) => update(() => date = value!),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, (status, date)),
                child: const Text('Aplicar filtros')),
          ],
        ),
      ),
    );
    if (result == null || !mounted) return;
    if (result.$2 == _DatePreset.custom) {
      final now = DateTime.now();
      final range = await showAppDateRangeDialog(
        context: context,
        firstDate: DateTime(now.year - 2),
        lastDate: now,
        initialFrom: _customFrom,
        initialTo: _customTo,
      );
      if (range == null || !mounted) return;
      _customFrom = range.from;
      _customTo = range.to;
    }
    setState(() {
      _filter = result.$1;
      _datePreset = result.$2;
    });
  }

  bool _matchesDate(DateTime? at) {
    final (from, to) = _range;
    return chatActivityInRange(at: at, from: from, to: to);
  }

  Future<void> _open(String id, bool wide) async {
    if (wide) {
      setState(() => _selectedId = id);
      return;
    }
    final kind = _kind;
    await Navigator.of(context).push<void>(MaterialPageRoute(
      builder: (_) => _conversation(id, kind, embedded: false),
    ));
    if (mounted) _scheduleRefresh();
  }

  Widget _conversation(String id, _ChatKind kind, {required bool embedded}) {
    if (kind == _ChatKind.consultas) {
      return StoreSupplierChatScreen(
        key: ValueKey('consulta-$id'),
        threadId: id,
        embedded: embedded,
        onActivity: _scheduleRefresh,
      );
    }
    final thread = _threads.where((t) => t.primaryRequestId == id).firstOrNull;
    if (thread == null) {
      return const Center(child: Text('Selecciona una conversación'));
    }
    final flags =
        orderChatInboxReplyFlags(role: widget.homeRole, thread: thread);
    return Scaffold(
      key: ValueKey('pedido-$id'),
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: !embedded,
        title: Text(thread.counterpartName,
            maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: SafeArea(
        top: false,
        child: OrderMotolinkThreadSection(
          transactionRequestId: id,
          mergedThreadRequestIds:
              thread.requestIds.length > 1 ? thread.requestIds : null,
          orderLines: thread.lines,
          allowReplyAsAliado: flags.aliado,
          allowReplyAsAdmin: flags.admin,
          allowReplyAsImportador: flags.importador,
          deliveryGrace: thread.inDeliveryGrace,
          expandMessages: true,
          onThreadChanged: _scheduleRefresh,
          conversationContext: Wrap(
            spacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '${thread.reference} · ${thread.statusLabel}',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              if (!_isAdmin)
                TextButton(
                  onPressed: () {
                    final navigator = Navigator.of(context);
                    if (!embedded) navigator.pop();
                    navigator.pop();
                    MainShellTabController.setPendingOpenOrderChat(false);
                    MainShellTabController.setPendingNotificationType(null);
                    MainShellTabController.setPendingNotificationRelatedId(id);
                    MainShellTabController.navigateToPedidosForNotification();
                  },
                  child: const Text('Ver pedido'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = ListenableBuilder(
      listenable: _provider ?? const AlwaysStoppedAnimation(0),
      builder: (context, _) => LayoutBuilder(builder: (context, constraints) {
        final wide = widget.asPage && constraints.maxWidth >= 960;
        final inbox = _inbox(wide);
        if (!wide) return inbox;
        return Row(
          children: [
            SizedBox(width: 410, child: inbox),
            const VerticalDivider(width: 1),
            Expanded(
              child: _selectedId == null
                  ? _notice('Selecciona una conversación',
                      'Elige un chat para leer o responder.',
                      icon: Icons.forum_outlined)
                  : _conversation(_selectedId!, _kind, embedded: true),
            ),
          ],
        );
      }),
    );
    return widget.asPage
        ? SafeArea(top: false, child: content)
        : SizedBox(
            height: MediaQuery.sizeOf(context).height * .82, child: content);
  }

  Widget _inbox(bool wide) {
    final orders = filterOrderChatThreads(
      threads: _threads,
      query: _search.text,
      filter: _filter,
      unreadFor: _orderUnread,
      activityFor: _activity,
    )
        .where((t) =>
            (!_unreadOnly || _orderUnread(t.requestIds) > 0) &&
            _matchesDate(_activity(t)))
        .toList();
    final query = _search.text.trim().toLowerCase();
    final direct = _consultas.where((item) {
      final uid = _consultas.isEmpty ? null : SupabaseAccess.currentUserId;
      final text =
          '${item.thread.titleFor(uid)} ${item.lastProduct ?? ''} ${item.lastBody ?? ''}';
      return text.toLowerCase().contains(query) &&
          (!_unreadOnly || _directUnread(item.thread.id) > 0) &&
          _matchesDate(item.lastAt);
    }).toList()
      ..sort((a, b) {
        final unread = (_directUnread(b.thread.id) > 0 ? 1 : 0)
            .compareTo(_directUnread(a.thread.id) > 0 ? 1 : 0);
        if (unread != 0) return unread;
        final byDate = (b.lastAt?.millisecondsSinceEpoch ?? 0)
            .compareTo(a.lastAt?.millisecondsSinceEpoch ?? 0);
        return byDate == 0 ? a.thread.id.compareTo(b.thread.id) : byDate;
      });
    final isOrders = _kind == _ChatKind.pedidos;
    final count = isOrders ? orders.length : direct.length;
    final hasData = isOrders ? _threads.isNotEmpty : _consultas.isNotEmpty;
    final failed = isOrders ? _ordersError : _consultasError;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!widget.asPage)
          ListTile(
              title: const Text('Chats'),
              trailing: CloseButton(onPressed: () => Navigator.pop(context))),
        if (!_signedOut)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!_isAdmin)
                  SegmentedButton<_ChatKind>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                          value: _ChatKind.pedidos, label: Text('Pedidos')),
                      ButtonSegment(
                          value: _ChatKind.consultas, label: Text('Consultas')),
                    ],
                    selected: {_kind},
                    onSelectionChanged: (selection) {
                      if (_scroll.hasClients) _scroll.jumpTo(0);
                      setState(() {
                        _kind = selection.single;
                        _selectedId = null;
                        _search.clear();
                      });
                    },
                  ),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                      child: TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: isOrders
                          ? 'Pedido, negocio, producto o SKU'
                          : 'Buscar negocio o producto',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      isDense: true,
                      filled: true,
                      fillColor: AppColors.fieldFill,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none),
                    ),
                  )),
                  IconButton(
                    tooltip: 'Actualizar chats',
                    onPressed: _loading ? null : _load,
                    icon: const Icon(Icons.refresh),
                  ),
                ]),
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    FilterChip(
                      label: const Text('No leídos'),
                      selected: _unreadOnly,
                      onSelected: (value) =>
                          setState(() => _unreadOnly = value),
                    ),
                    TextButton.icon(
                      onPressed: _editFilters,
                      icon: const Icon(Icons.tune, size: 18),
                      label: const Text('Filtros'),
                    ),
                    if (isOrders && _filter != OrderChatInboxFilter.all)
                      InputChip(
                          label: Text(_statusLabel(_filter)),
                          onDeleted: () => setState(
                              () => _filter = OrderChatInboxFilter.all)),
                    if (_datePreset != _DatePreset.all)
                      InputChip(
                          label: Text(_dateLabel(_datePreset)),
                          onDeleted: () => setState(() {
                                _datePreset = _DatePreset.all;
                                _customFrom = null;
                                _customTo = null;
                              })),
                  ],
                ),
              ],
            ),
          ),
        if (_loading)
          const LinearProgressIndicator(semanticsLabel: 'Actualizando chats')
        else
          const Divider(height: 1),
        if ((failed && hasData) || (isOrders && _previewError && !failed))
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Text(
                failed
                    ? 'No se pudo actualizar la lista.'
                    : 'No se pudieron actualizar las vistas previas.',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
        Expanded(
          child: _signedOut
              ? _notice('Sesión vencida',
                  'Vuelve a iniciar sesión para ver tus mensajes.',
                  icon: Icons.lock_outline)
              : _loading && !hasData
                  ? const Center(child: Text('Cargando conversaciones…'))
                  : failed && !hasData
                      ? _notice('No se pudo cargar',
                          'Intenta volver a cargar las conversaciones.',
                          action: TextButton(
                              onPressed: _load,
                              child: const Text('Reintentar')))
                      : count == 0
                          ? hasData ||
                                  _hasFilters ||
                                  query.isNotEmpty ||
                                  _unreadOnly
                              ? _notice('Ningún chat coincide',
                                  'Prueba otra búsqueda o limpia los filtros.',
                                  action: TextButton(
                                      onPressed: _clear,
                                      child: const Text('Limpiar filtros')))
                              : isOrders
                                  ? _notice('Sin conversaciones',
                                      'El chat se abre cuando hay un pedido.')
                                  : _notice('Sin consultas',
                                      'Las consultas de producto se abren desde el catálogo.')
                          : ListView.separated(
                              key: PageStorageKey(_kind),
                              controller: _scroll,
                              itemCount: count,
                              separatorBuilder: (_, __) => const Divider(
                                  height: 1, indent: 16, endIndent: 16),
                              itemBuilder: (_, i) => isOrders
                                  ? _orderTile(orders[i], wide)
                                  : _directTile(direct[i], wide),
                            ),
        ),
      ],
    );
  }

  Widget _orderTile(OrderChatThread thread, bool wide) {
    final message = _preview(thread);
    final body = message?.body.trim() ?? '';
    final preview = message == null
        ? (_previewError
            ? 'Vista previa no disponible'
            : 'Sin mensajes todavía')
        : OrderReturnRules.parseReturnRequestMessage(body) != null
            ? 'Solicitud de posventa'
            : body.isNotEmpty
                ? body
                : 'Archivo adjunto';
    return _tile(
      id: thread.primaryRequestId,
      title: thread.counterpartName,
      preview: preview,
      contextLabel:
          '${thread.reference} · ${thread.title}${!thread.canReply && !_isAdmin ? ' · Solo lectura' : ''}',
      at: _activity(thread),
      unread: _orderUnread(thread.requestIds),
      wide: wide,
    );
  }

  Widget _directTile(StoreSupplierInboxItem item, bool wide) => _tile(
        id: item.thread.id,
        title: item.thread.titleFor(SupabaseAccess.currentUserId),
        preview: item.lastBody?.trim().isNotEmpty == true
            ? item.lastBody!
            : 'Sin mensajes todavía',
        contextLabel: item.lastProduct ?? '',
        at: item.lastAt,
        unread: _directUnread(item.thread.id),
        wide: wide,
      );

  Widget _tile({
    required String id,
    required String title,
    required String preview,
    required String contextLabel,
    required DateTime? at,
    required int unread,
    required bool wide,
  }) {
    final selected = wide && id == _selectedId;
    final muted = TextStyle(color: AppColors.textSecondary, fontSize: 12);
    return Material(
      color:
          selected || unread > 0 ? AppColors.surfaceTinted : Colors.transparent,
      child: InkWell(
        onTap: () => _open(id, wide),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 17,
                backgroundColor: AppColors.brandBlueContainer,
                foregroundColor: AppColors.textPrimary,
                child: Text(title.trim().isEmpty
                    ? '?'
                    : title.trim().characters.first.toUpperCase()),
              ),
              const SizedBox(width: 10),
              Expanded(
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontWeight:
                              unread > 0 ? FontWeight.w800 : FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: unread > 0
                              ? AppColors.textPrimary
                              : AppColors.textSecondary)),
                  if (contextLabel.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(contextLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: muted),
                    ),
                ],
              )),
              if (at != null || unread > 0) ...[
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 82),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (at != null)
                        Tooltip(
                            message: formatEsShortDateTime(at),
                            child: Text(_shortTime(at),
                                style: muted, textAlign: TextAlign.end)),
                      if (unread > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 5),
                          child: Badge(
                              label: Text(unread > 99 ? '99+' : '$unread')),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _shortTime(DateTime at) {
    final local = at.toLocal();
    final now = DateTime.now();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    if (local.year != now.year) return '$day/$month/${local.year}';
    if (local.month != now.month || local.day != now.day) return '$day/$month';
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Widget _notice(String title, String description,
          {Widget? action, IconData icon = Icons.chat_bubble_outline}) =>
      Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 28, color: AppColors.textSecondary),
              const SizedBox(height: 8),
              Text(title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(description,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary)),
              if (action != null) action,
            ],
          ),
        ),
      );
}
