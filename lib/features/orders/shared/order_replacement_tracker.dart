import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/features/inventory/product_images.dart';
import 'order_product_thumb.dart';
import 'order_return_request_screen.dart';
import 'order_return_rules.dart';
import 'orders_service.dart';
import 'transaction_request_model.dart';

class _Track {
  const _Track({
    required this.line,
    required this.casoId,
    required this.status,
    required this.qty,
  });

  final TransactionRequestModel line;
  final String casoId;
  final String status;
  final int qty;
}

/// Seguimiento del cambio de producto, visible para la tienda y el proveedor.
class OrderReplacementTracker extends StatefulWidget {
  const OrderReplacementTracker({
    super.key,
    required this.lines,
    required this.allowAdvance,
    this.onChanged,
  });

  final List<TransactionRequestModel> lines;
  final bool allowAdvance;
  final VoidCallback? onChanged;

  @override
  State<OrderReplacementTracker> createState() =>
      _OrderReplacementTrackerState();
}

class _OrderReplacementTrackerState extends State<OrderReplacementTracker> {
  List<_Track> _items = const [];
  bool _loading = false;
  String? _busyId;

  bool get _hasChange =>
      widget.lines.any((line) => line.postventaResolucion == 'cambio');

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(OrderReplacementTracker oldWidget) {
    super.didUpdateWidget(oldWidget);
    final before = oldWidget.lines.map((line) => line.postventaResolucion).join();
    final after = widget.lines.map((line) => line.postventaResolucion).join();
    if (before != after) _load();
  }

  Future<void> _load() async {
    final targets =
        widget.lines.where((line) => line.postventaResolucion == 'cambio');
    if (targets.isEmpty) {
      if (mounted) setState(() => _items = const []);
      return;
    }
    setState(() => _loading = true);
    final items = <_Track>[];
    for (final line in targets) {
      try {
        final caso = await OrdersService.fetchOrderPostventaCaso(
          transactionRequestId: line.id,
          kind: OrderPostventaKind.devolucion,
        );
        final casoId = caso?['id']?.toString() ?? '';
        if (casoId.isEmpty) continue;
        final replacement = await OrdersService.fetchReplacementOrder(casoId);
        items.add(
          _Track(
            line: line,
            casoId: casoId,
            status: replacement?['status']?.toString() ?? '',
            qty: int.tryParse(replacement?['qty']?.toString() ?? '') ??
                int.tryParse(caso?['affected_qty']?.toString() ?? '') ??
                1,
          ),
        );
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _advance(_Track item, String next) async {
    final label = OrderReturnRules.replacementStatusLabel(next);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Actualizar a $label'),
        content: const Text(
          'La tienda recibe el aviso de este cambio.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busyId = item.casoId);
    try {
      final status = await OrdersService.advanceReplacementOrder(
        casoId: item.casoId,
        status: next,
      );
      if (!mounted) return;
      setState(() {
        _items = [
          for (final current in _items)
            if (current.casoId == item.casoId)
              _Track(
                line: current.line,
                casoId: current.casoId,
                status: status,
                qty: current.qty,
              )
            else
              current,
        ];
        _busyId = null;
      });
      widget.onChanged?.call();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busyId = null);
      final raw = e.toString();
      final message = RegExp(r'message:\s*([^,\n]+)')
              .firstMatch(raw)
              ?.group(1)
              ?.trim() ??
          'No se pudo actualizar el cambio.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasChange) return const SizedBox.shrink();
    if (_loading && _items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 8),
        child: LinearProgressIndicator(minHeight: 2),
      );
    }
    if (_items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        children: [
          for (final item in _items) ...[
            _TrackCard(
              item: item,
              allowAdvance: widget.allowAdvance,
              busy: _busyId == item.casoId,
              onAdvance: _advance,
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _TrackCard extends StatelessWidget {
  const _TrackCard({
    required this.item,
    required this.allowAdvance,
    required this.busy,
    required this.onAdvance,
  });

  final _Track item;
  final bool allowAdvance;
  final bool busy;
  final void Function(_Track item, String next) onAdvance;

  static const _steps = ['pendiente_retiro', 'en_transito', 'entregado'];

  @override
  Widget build(BuildContext context) {
    final name = (item.line.productName ?? 'Producto').trim();
    final index = _steps.indexOf(item.status);
    final next = item.status == 'pendiente_retiro'
        ? 'en_transito'
        : (item.status == 'en_transito' ? 'entregado' : null);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              OrderProductThumb(
                size: 44,
                url: productCoverImageUrl(item.line.productImageUrls),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cambio de producto',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      item.qty == 1 ? '$name · 1 unidad' : '$name · ${item.qty} unidades',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (index < 0)
            Text(
              item.status.isEmpty
                  ? 'El cambio está acordado.'
                  : OrderReturnRules.replacementStatusLabel(item.status),
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            )
          else
            Row(
              children: [
                for (var i = 0; i < _steps.length; i++) ...[
                  if (i > 0)
                    Expanded(
                      child: Container(
                        height: 2,
                        color: i <= index
                            ? AppColors.brand
                            : AppColors.borderSubtle,
                      ),
                    ),
                  _StepDot(
                    label: OrderReturnRules.replacementStatusLabel(_steps[i]),
                    done: i <= index,
                    current: i == index,
                  ),
                ],
              ],
            ),
          if (allowAdvance && next != null) ...[
            const SizedBox(height: 12),
            FilledButton(
              onPressed: busy ? null : () => onAdvance(item, next),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 44),
              ),
              child: Text(
                next == 'en_transito'
                    ? 'Marcar en tránsito'
                    : 'Marcar como entregado',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({
    required this.label,
    required this.done,
    required this.current,
  });

  final String label;
  final bool done;
  final bool current;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done ? AppColors.brand : AppColors.card,
            border: Border.all(
              color: done ? AppColors.brand : AppColors.borderSubtle,
              width: 2,
            ),
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: 78,
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: TextStyle(
              fontSize: 10,
              height: 1.15,
              fontWeight: current ? FontWeight.w800 : FontWeight.w600,
              color: done ? AppColors.brand : AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
