class OwnerRelatedOrder {
  const OwnerRelatedOrder({
    required this.id,
    required this.status,
    required this.productName,
    required this.counterpartyName,
    required this.side,
    this.createdAt,
  });

  final String id;
  final String status;
  final String productName;
  final String counterpartyName;
  final String side;
  final DateTime? createdAt;
}

class OwnerRelatedOrders {
  const OwnerRelatedOrders({
    required this.count,
    required this.orders,
  });

  static const empty = OwnerRelatedOrders(count: 0, orders: []);

  final int count;
  final List<OwnerRelatedOrder> orders;

  factory OwnerRelatedOrders.fromRpc(dynamic raw) {
    if (raw is! Map) return empty;
    final map = Map<String, dynamic>.from(raw);
    final count = int.tryParse('${map['count']}') ?? 0;
    final rawOrders = map['orders'];
    final orders = <OwnerRelatedOrder>[];
    if (rawOrders is List) {
      for (final row in rawOrders) {
        if (row is! Map) continue;
        final item = Map<String, dynamic>.from(row);
        final product = item['product_name']?.toString().trim();
        final other = item['counterparty_name']?.toString().trim();
        orders.add(
          OwnerRelatedOrder(
            id: item['id']?.toString() ?? '',
            status: item['status']?.toString() ?? '',
            productName:
                (product == null || product.isEmpty) ? 'Producto' : product,
            counterpartyName:
                (other == null || other.isEmpty) ? 'La otra cuenta' : other,
            side: item['side']?.toString().trim().isNotEmpty == true
                ? item['side'].toString().trim()
                : 'Pedido',
            createdAt: DateTime.tryParse(item['created_at']?.toString() ?? ''),
          ),
        );
      }
    }
    return OwnerRelatedOrders(
      count: count < orders.length ? orders.length : count,
      orders: orders,
    );
  }
}
