import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/data/supabase_access.dart';
import 'package:motolink_pro_app/core/notifications/notification_provider.dart';
import 'package:motolink_pro_app/core/utils/app_date_format.dart';
import 'package:motolink_pro_app/features/catalog/store_supplier_chat.dart';
import 'package:motolink_pro_app/features/orders/shared/order_chat_launch.dart';
import 'package:motolink_pro_app/features/orders/shared/order_chat_thread.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_model.dart';
import 'package:motolink_pro_app/features/profile/app_home_role.dart';

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
  OrderChatInboxFilter _filter = OrderChatInboxFilter.all;
  _ChatKind _kind = _ChatKind.pedidos;
  _DatePreset _datePreset = _DatePreset.all;
  DateTime? _customFrom;
  DateTime? _customTo;
  List<OrderChatThread> _threads = const [];
  List<StoreSupplierInboxItem> _consultas = const [];
  bool _loading = true;
  String? _error;
  String? _consultasError;
  bool _signedOut = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool get _hasSession {
    if (widget.hasSession != null) return widget.hasSession!();
    return SupabaseAccess.currentUserId != null;
  }

  Future<void> _load() async {
    if (!_hasSession) {
      setState(() {
        _signedOut = true;
        _loading = false;
        _error = null;
        _threads = const [];
      });
      return;
    }
    setState(() {
      _signedOut = false;
      _loading = true;
      _error = null;
    });
    try {
      final fetch = widget.fetchOrders ?? () => fetchOrdersForChatInbox(widget.homeRole);
      final orders = await fetch();
      if (!mounted) return;
      List<StoreSupplierInboxItem> consultas = const [];
      String? consultasError;
      if (widget.homeRole != AppHomeRole.administrador) {
        try {
          consultas = await StoreSupplierChatService.listInbox();
        } catch (_) {
          consultasError = 'No se pudieron cargar las consultas de producto.';
        }
      }
      if (!mounted) return;
      setState(() {
        _threads = orderChatThreadsFromOrders(orders, role: widget.homeRole);
        _consultas = consultas;
        _consultasError = consultasError;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'No se pudieron cargar los mensajes. Intente de nuevo.';
      });
    }
  }

  int _unreadFor(List<String> ids) {
    return NotificationProvider.active?.unreadMensajeCountFor(ids) ?? 0;
  }

  void _openThread(OrderChatThread thread) {
    openOrderChatFromInbox(
      context: context,
      role: widget.homeRole,
      thread: thread,
      onThreadChanged: () {
        NotificationProvider.active?.reload();
      },
    );
  }

  (DateTime?, DateTime?) get _range {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (_datePreset) {
      case _DatePreset.all:
        return (null, null);
      case _DatePreset.today:
        return (today, today);
      case _DatePreset.days7:
        return (today.subtract(const Duration(days: 6)), today);
      case _DatePreset.days30:
        return (today.subtract(const Duration(days: 29)), today);
      case _DatePreset.custom:
        return (_customFrom, _customTo);
    }
  }

  Future<void> _pickDates() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      initialDateRange: _customFrom != null && _customTo != null
          ? DateTimeRange(start: _customFrom!, end: _customTo!)
          : null,
    );
    if (range == null || !mounted) return;
    setState(() {
      _datePreset = _DatePreset.custom;
      _customFrom = range.start;
      _customTo = range.end;
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = NotificationProvider.active;
    final listenable = provider ?? _silent;
    final height = MediaQuery.sizeOf(context).height * 0.82;
    final page = ListenableBuilder(
        listenable: listenable,
        builder: (context, _) {
          final range = _range;
          final visible = filterOrderChatThreads(
            threads: _threads,
            query: _search.text,
            filter: _filter,
            unreadFor: _unreadFor,
          ).where((thread) {
            return chatActivityInRange(
              at: thread.updatedAt,
              from: range.$1,
              to: range.$2,
            );
          }).toList();
          final uid = SupabaseAccess.currentUserId;
          final query = _search.text.trim().toLowerCase();
          final consultas = _consultas.where((item) {
            if (query.isNotEmpty) {
              final blob =
                  '${item.thread.titleFor(uid)} ${item.lastBody ?? ''}'
                      .toLowerCase();
              if (!blob.contains(query)) return false;
            }
            return chatActivityInRange(
              at: item.lastAt,
              from: range.$1,
              to: range.$2,
            );
          }).toList();
          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 8,
              bottom: MediaQuery.viewInsetsOf(context).bottom + 12,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!widget.asPage) ...[
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: AppColors.borderSubtle,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Chats',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Cerrar',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ],
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Pedidos y consultas de producto. El soporte va en otra bandeja.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          height: 1.3,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Actualizar',
                      onPressed: _loading ? null : _load,
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _search,
                  textInputAction: TextInputAction.search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: widget.homeRole == AppHomeRole.administrador
                        ? 'Buscar tienda, mayorista, producto o SKU'
                        : 'Buscar producto, SKU o contraparte',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                if (widget.homeRole != AppHomeRole.administrador)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _kindChip('Pedidos', _ChatKind.pedidos),
                        _kindChip(
                          'Consultas de producto / Catálogo',
                          _ChatKind.consultas,
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _dateChip('Todas', _DatePreset.all),
                      _dateChip('Hoy', _DatePreset.today),
                      _dateChip('7 días', _DatePreset.days7),
                      _dateChip('30 días', _DatePreset.days30),
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ActionChip(
                          label: Text(
                            _datePreset == _DatePreset.custom &&
                                    _customFrom != null &&
                                    _customTo != null
                                ? '${formatEsShortDateTime(_customFrom)} – ${formatEsShortDateTime(_customTo)}'
                                : 'Fechas',
                          ),
                          onPressed: _pickDates,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_kind == _ChatKind.pedidos) ...[
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final f in OrderChatInboxFilter.values) ...[
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(_filterLabel(f)),
                              selected: _filter == f,
                              onSelected: (_) => setState(() => _filter = f),
                              visualDensity: VisualDensity.compact,
                              selectedColor: AppColors.brand.withOpacity(0.16),
                              checkmarkColor: AppColors.brand,
                              labelStyle: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                color: _filter == f
                                    ? AppColors.brand
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Expanded(
                  child: _kind == _ChatKind.consultas
                      ? _consultasBody(consultas)
                      : _body(visible),
                ),
              ],
            ),
          );
        },
      );
    if (widget.asPage) return page;
    return SizedBox(height: height, child: page);
  }

  Widget _kindChip(String label, _ChatKind kind) {
    final selected = _kind == kind;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _kind = kind),
        visualDensity: VisualDensity.compact,
        selectedColor: AppColors.brand.withOpacity(0.16),
        labelStyle: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 12,
          color: selected ? AppColors.brand : AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _dateChip(String label, _DatePreset preset) {
    final selected = _datePreset == preset;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _datePreset = preset),
        visualDensity: VisualDensity.compact,
        selectedColor: AppColors.brand.withOpacity(0.16),
        checkmarkColor: AppColors.brand,
        labelStyle: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 12,
          color: selected ? AppColors.brand : AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _consultasBody(List<StoreSupplierInboxItem> visible) {
    if (_signedOut) {
      return _statePane(
        icon: Icons.lock_outline,
        title: 'Sesión vencida',
        body: 'Vuelva a iniciar sesión para ver sus mensajes.',
      );
    }
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_consultasError != null) {
      return _statePane(
        icon: Icons.error_outline,
        title: 'No se pudo cargar',
        body: _consultasError!,
        action: TextButton(onPressed: _load, child: const Text('Reintentar')),
      );
    }
    if (_consultas.isEmpty) {
      return _statePane(
        icon: Icons.storefront_outlined,
        title: 'Sin consultas',
        body: 'Las consultas de producto se abren desde el catálogo.',
      );
    }
    if (visible.isEmpty) {
      return _statePane(
        icon: Icons.filter_alt_off_outlined,
        title: 'Ninguna consulta coincide',
        body: 'Pruebe otra búsqueda o quite el filtro de fechas.',
      );
    }
    final uid = SupabaseAccess.currentUserId;
    return ListView.separated(
      itemCount: visible.length,
      separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.divider),
      itemBuilder: (context, i) {
        final item = visible[i];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          leading: CircleAvatar(
            backgroundColor: AppColors.brand.withOpacity(0.12),
            child: const Icon(Icons.storefront_outlined, color: AppColors.brand, size: 20),
          ),
          title: Text(
            item.thread.titleFor(uid),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          subtitle: Text(
            [
              if ((item.lastBody ?? '').trim().isNotEmpty) item.lastBody!.trim(),
              if (item.lastAt != null) formatEsShortDateTime(item.lastAt),
            ].join(' · '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              height: 1.3,
              color: AppColors.textSecondary,
            ),
          ),
          trailing: Icon(Icons.chevron_right, color: AppColors.textSecondary),
          onTap: () => openStoreSupplierChat(item.thread.id),
        );
      },
    );
  }

  Widget _body(List<OrderChatThread> visible) {
    if (_signedOut) {
      return _statePane(
        icon: Icons.lock_outline,
        title: 'Sesión vencida',
        body: 'Vuelva a iniciar sesión para ver sus mensajes.',
      );
    }
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _statePane(
        icon: Icons.error_outline,
        title: 'No se pudo cargar',
        body: _error!,
        action: TextButton(onPressed: _load, child: const Text('Reintentar')),
      );
    }
    if (_threads.isEmpty) {
      return _statePane(
        icon: Icons.chat_bubble_outline,
        title: 'Sin conversaciones',
        body:
            'El chat se abre cuando hay un pedido. Haga un pedido o espere uno para escribir.',
      );
    }
    if (visible.isEmpty) {
      return _statePane(
        icon: Icons.filter_alt_off_outlined,
        title: 'Ningún hilo coincide',
        body: 'Pruebe otra búsqueda o quite el filtro.',
        action: TextButton(
          onPressed: () => setState(() {
            _search.clear();
            _filter = OrderChatInboxFilter.all;
          }),
          child: const Text('Limpiar filtros'),
        ),
      );
    }
    return ListView.separated(
      itemCount: visible.length,
      separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.divider),
      itemBuilder: (context, i) {
        final t = visible[i];
        final unread = _unreadFor(t.requestIds);
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          leading: CircleAvatar(
            backgroundColor: AppColors.brand.withOpacity(0.12),
            child: Icon(
              unread > 0 ? Icons.chat_bubble : Icons.chat_bubble_outline,
              color: AppColors.brand,
              size: 20,
            ),
          ),
          title: Text(
            t.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: unread > 0 ? FontWeight.w800 : FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          subtitle: Text(
            [
              t.counterpartName,
              t.statusLabel,
              if (!t.canReply) 'Solo lectura',
              if (t.updatedAt != null) formatEsShortDateTime(t.updatedAt),
            ].join(' · '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              height: 1.3,
              color: AppColors.textSecondary,
            ),
          ),
          trailing: unread > 0
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.brand,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    unread > 9 ? '9+' : '$unread',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                )
              : Icon(Icons.chevron_right, color: AppColors.textSecondary),
          onTap: () => _openThread(t),
        );
      },
    );
  }

  Widget _statePane({
    required IconData icon,
    required String title,
    required String body,
    Widget? action,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 36, color: AppColors.textSecondary),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              body,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                color: AppColors.textSecondary,
              ),
            ),
            if (action != null) ...[const SizedBox(height: 8), action],
          ],
        ),
      ),
    );
  }

  String _filterLabel(OrderChatInboxFilter f) {
    return switch (f) {
      OrderChatInboxFilter.all => 'Todos',
      OrderChatInboxFilter.active => 'Activos',
      OrderChatInboxFilter.closed => 'Cerrados',
      OrderChatInboxFilter.unread => 'No leídos',
    };
  }
}

final ChangeNotifier _silent = ChangeNotifier();
