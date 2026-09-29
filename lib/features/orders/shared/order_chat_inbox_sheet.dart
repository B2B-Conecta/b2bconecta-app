import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/data/supabase_access.dart';
import 'package:motolink_pro_app/core/notifications/notification_provider.dart';
import 'package:motolink_pro_app/core/utils/app_date_format.dart';
import 'package:motolink_pro_app/features/orders/shared/order_chat_launch.dart';
import 'package:motolink_pro_app/features/orders/shared/order_chat_thread.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_model.dart';
import 'package:motolink_pro_app/features/profile/app_home_role.dart';

Future<void> showOrderChatInboxSheet({
  required BuildContext context,
  required AppHomeRole homeRole,
  Future<List<TransactionRequestModel>> Function()? fetchOrders,
  bool Function()? hasSession,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetContext) {
      return OrderChatInboxSheet(
        homeRole: homeRole,
        fetchOrders: fetchOrders,
        hasSession: hasSession,
      );
    },
  ).whenComplete(() {
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
  });

  final AppHomeRole homeRole;
  final Future<List<TransactionRequestModel>> Function()? fetchOrders;
  final bool Function()? hasSession;

  @override
  State<OrderChatInboxSheet> createState() => _OrderChatInboxSheetState();
}

class _OrderChatInboxSheetState extends State<OrderChatInboxSheet> {
  final _search = TextEditingController();
  OrderChatInboxFilter _filter = OrderChatInboxFilter.all;
  List<OrderChatThread> _threads = const [];
  bool _loading = true;
  String? _error;
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
      setState(() {
        _threads = orderChatThreadsFromOrders(orders, role: widget.homeRole);
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

  @override
  Widget build(BuildContext context) {
    final provider = NotificationProvider.active;
    final listenable = provider ?? _silent;
    final height = MediaQuery.sizeOf(context).height * 0.82;

    return SizedBox(
      height: height,
      child: ListenableBuilder(
        listenable: listenable,
        builder: (context, _) {
          final visible = filterOrderChatThreads(
            threads: _threads,
            query: _search.text,
            filter: _filter,
            unreadFor: _unreadFor,
          );
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
                    const Icon(
                      Icons.chat_bubble_outline,
                      color: AppColors.brand,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Mensajes',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Actualizar',
                      onPressed: _loading ? null : _load,
                      icon: const Icon(Icons.refresh),
                    ),
                    IconButton(
                      tooltip: 'Cerrar',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                Text(
                  'Chats de pedidos. El soporte va en otra bandeja.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.3,
                  ),
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
                const SizedBox(height: 8),
                Expanded(child: _body(visible)),
              ],
            ),
          );
        },
      ),
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
