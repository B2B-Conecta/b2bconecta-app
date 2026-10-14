import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/utils/app_date_format.dart';
import 'package:motolink_pro_app/core/utils/ves_amount_format.dart';
import 'order_motolink_thread_section.dart';
import 'order_return_rules.dart';
import 'orders_service.dart';
import 'transaction_request_model.dart';

abstract final class OrderPostventaKind {
  static const devolucion = 'devolucion';
  static const queja = 'queja';
  static const cambio = 'cambio';
  static const credito = 'credito';

  static String actionLabel(String kind) =>
      kind == queja ? 'Presentar una queja' : 'Pedir devolución';

  static String viewLabel(String kind) =>
      kind == queja ? 'Ver queja' : 'Ver devolución';

  static String registeredTitle(String kind) =>
      kind == queja ? 'Queja registrada' : 'Devolución registrada';
}

/// Registra una devolución o una queja y la deja anotada en el pedido.
class OrderReturnRequestScreen extends StatefulWidget {
  const OrderReturnRequestScreen({
    super.key,
    required this.request,
    required this.kind,
    required this.alreadyRegistered,
    required this.allowReplyAsAliado,
    required this.allowReplyAsImportador,
    this.mergedThreadRequestIds,
  });

  final TransactionRequestModel request;
  final String kind;
  final bool alreadyRegistered;
  final bool allowReplyAsAliado;
  final bool allowReplyAsImportador;
  final List<String>? mergedThreadRequestIds;

  @override
  State<OrderReturnRequestScreen> createState() =>
      _OrderReturnRequestScreenState();
}

class _OrderReturnRequestScreenState extends State<OrderReturnRequestScreen> {
  final _noteCtrl = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  bool _resolving = false;
  bool _registered = false;
  bool _changed = false;
  String? _savedBody;
  DateTime? _savedAt;
  String? _productName;
  int _affectedQty = 1;
  int? _savedQty;
  String? _resolution;
  double? _creditAmount;
  String? _formError;

  bool get _canRegister =>
      widget.allowReplyAsAliado || widget.allowReplyAsImportador;

  bool get _canResolve =>
      widget.kind == OrderPostventaKind.devolucion &&
      widget.allowReplyAsImportador &&
      _registered &&
      _resolution == null;

  bool get _windowOpen => OrderReturnRules.isAvailable(
        status: widget.request.status,
        updatedAt: widget.request.updatedAt,
        deliveredAt: widget.request.atEntregado,
      );

  int get _lineQty =>
      widget.request.cantidad < 1 ? 1 : widget.request.cantidad;

  @override
  void initState() {
    super.initState();
    _registered = widget.alreadyRegistered;
    _affectedQty = OrderReturnRules.clampAffectedQty(1, _lineQty);
    _load();
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final row = await OrdersService.fetchOrderPostventaCaso(
        transactionRequestId: widget.request.id,
        kind: widget.kind,
      );
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (row != null) {
          _registered = true;
          _savedBody = row['body']?.toString();
          _savedAt = DateTime.tryParse(row['created_at']?.toString() ?? '')
              ?.toLocal();
          final name = row['product_name']?.toString().trim();
          if (name != null && name.isNotEmpty) _productName = name;
          final qty = int.tryParse(row['affected_qty']?.toString() ?? '');
          if (qty != null && qty > 0) _savedQty = qty;
          final resolution = row['resolution']?.toString().trim();
          if (resolution != null && resolution.isNotEmpty) {
            _resolution = resolution;
          }
          final credit = row['credit_amount'];
          if (credit != null) {
            _creditAmount = double.tryParse(credit.toString());
          }
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _register() async {
    final note = _noteCtrl.text.trim();
    if (note.length < 3) {
      setState(() {
        _formError = 'Escriba qué ocurrió antes de registrarlo.';
      });
      return;
    }
    final qty = OrderReturnRules.clampAffectedQty(_affectedQty, _lineQty);
    setState(() {
      _saving = true;
      _formError = null;
    });
    try {
      final at = await OrdersService.registerOrderPostventaCaso(
        transactionRequestId: widget.request.id,
        kind: widget.kind,
        body: note,
        affectedQty: qty,
      );
      if (!mounted) return;
      setState(() {
        _registered = true;
        _changed = true;
        _savedBody = note;
        _savedAt = at;
        _savedQty = qty;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${OrderPostventaKind.registeredTitle(widget.kind)}: '
            '${_displayProduct()}. ${_unitsLabel(qty)}. '
            'La otra parte la verá aquí y en el chat.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _formError = _friendlyError(e);
      });
    }
  }

  Future<void> _resolve(String resolution) async {
    final credit = _previewCredit;
    final product = _displayProduct();
    final qty = _savedQty ?? _affectedQty;
    final isCredit = resolution == OrderPostventaKind.credito;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isCredit ? 'Dejarlo como crédito' : 'Cambiar el producto'),
        content: Text(
          isCredit
              ? 'Quedará anotado un crédito de ${formatRefAmount(credit)} REF '
                  'por ${_unitsLabel(qty)} de $product. Sirve para el próximo '
                  'pedido de esta tienda con usted. No se descuenta solo y este '
                  'pedido sigue entregado.'
              : 'Quedará anotado que atenderá ${_unitsLabel(qty)} de $product '
                  'con un cambio. Este pedido sigue entregado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(isCredit ? 'Anotar el crédito' : 'Anotar el cambio'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    setState(() {
      _resolving = true;
      _formError = null;
    });
    try {
      final result = await OrdersService.resolveOrderPostventaCaso(
        transactionRequestId: widget.request.id,
        resolution: resolution,
      );
      if (!mounted) return;
      setState(() {
        _resolution = result.resolution;
        _creditAmount = result.creditAmount;
        _changed = true;
        _resolving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isCredit
                ? 'Crédito de ${formatRefAmount(result.creditAmount ?? credit)} REF anotado para el próximo pedido.'
                : 'Cambio de producto anotado en este pedido.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _resolving = false;
        _formError = _friendlyError(e);
      });
    }
  }

  String _friendlyError(Object error) {
    final raw = error.toString();
    if (raw.contains('plazo de 7 días')) return OrderReturnRules.closedHint;
    if (raw.contains('ya quedó registrado')) {
      return 'Eso ya quedó registrado en este pedido.';
    }
    if (raw.contains('ya tiene una respuesta')) {
      return 'Esta devolución ya tiene una respuesta.';
    }
    if (raw.contains('no puede superar')) {
      return 'La cantidad no puede superar las unidades de este producto.';
    }
    return 'No se pudo registrar. Revise su conexión e intente de nuevo.';
  }

  String _displayProduct() {
    final saved = _productName?.trim();
    if (saved != null && saved.isNotEmpty) return saved;
    final live = widget.request.productName?.trim();
    if (live != null && live.isNotEmpty) return live;
    return 'Producto del pedido';
  }

  String _unitsLabel(int qty) => qty == 1 ? '1 unidad' : '$qty unidades';

  double get _previewCredit => OrderReturnRules.creditAmount(
        unitPrice: widget.request.precioUnitarioAliado,
        lineTotal: widget.request.precioTotal,
        lineQty: _lineQty,
        affectedQty: _savedQty ?? _affectedQty,
      );

  void _close() => Navigator.of(context).pop(_changed);

  @override
  Widget build(BuildContext context) {
    final until = OrderReturnRules.availableUntil(
      deliveredAt: widget.request.atEntregado,
      updatedAt: widget.request.updatedAt,
    );
    final untilLabel =
        until == null ? null : formatEsShortDateTime(until.toLocal());
    final title = _registered
        ? OrderPostventaKind.viewLabel(widget.kind)
        : OrderPostventaKind.actionLabel(widget.kind);
    final sku = widget.request.productSku?.trim();
    final showStepper = !_registered && _canRegister && _windowOpen && _lineQty > 1;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _close();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _close,
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _displayProduct(),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: AppColors.textPrimary,
                ),
              ),
              if (sku != null && sku.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  'SKU $sku',
                  style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                _registered
                    ? 'Quedó anotado en este pedido. El estado sigue siendo entregado.'
                    : _windowOpen
                        ? 'Este producto pertenece al pedido. '
                            'Puede registrarlo hasta ${untilLabel ?? 'dentro de 7 días'}. '
                            'Queda anotado aquí y no cambia el estado.'
                        : OrderReturnRules.closedHint,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              if (_loading)
                const LinearProgressIndicator(minHeight: 2)
              else if (_registered) ...[
                _SavedNote(
                  product: _displayProduct(),
                  qtyLabel: _unitsLabel(_savedQty ?? _lineQty),
                  body: _savedBody,
                  at: _savedAt,
                ),
                if (_resolution != null) ...[
                  const SizedBox(height: 8),
                  _ResolutionNote(
                    resolution: _resolution!,
                    creditAmount: _creditAmount ?? _previewCredit,
                    product: _displayProduct(),
                    qtyLabel: _unitsLabel(_savedQty ?? _lineQty),
                  ),
                ] else if (_canResolve) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Cómo atender esta devolución',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Elija una respuesta. Queda anotada en el pedido. '
                    'El crédito es para el próximo pedido de esta tienda con usted '
                    'y no se descuenta solo.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _resolving
                        ? null
                        : () => _resolve(OrderPostventaKind.cambio),
                    icon: const Icon(Icons.swap_horiz, size: 18),
                    label: const Text('Cambiar el producto'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.brand,
                      side: const BorderSide(color: AppColors.brand),
                      minimumSize: const Size.fromHeight(44),
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: _resolving
                        ? null
                        : () => _resolve(OrderPostventaKind.credito),
                    icon: const Icon(Icons.account_balance_wallet_outlined, size: 18),
                    label: Text(
                      'Dejar ${formatRefAmount(_previewCredit)} REF como crédito',
                    ),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                    ),
                  ),
                ],
              ] else if (_canRegister && _windowOpen) ...[
                Text(
                  'Unidades de este producto en el pedido: $_lineQty',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 8),
                if (showStepper)
                  _QtyStepper(
                    value: _affectedQty,
                    max: _lineQty,
                    enabled: !_saving,
                    onChanged: (value) => setState(() => _affectedQty = value),
                  )
                else
                  Text(
                    'Se registrará ${_unitsLabel(_lineQty)} de este producto.',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppColors.textPrimary,
                    ),
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: _noteCtrl,
                  enabled: !_saving,
                  minLines: 3,
                  maxLines: 5,
                  decoration: InputDecoration(
                    labelText: widget.kind == OrderPostventaKind.queja
                        ? 'Qué ocurrió con este producto'
                        : 'Qué inconveniente tuvo este producto',
                    hintText: 'Escríbalo con claridad.',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: _saving ? null : _register,
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(OrderPostventaKind.actionLabel(widget.kind)),
                ),
              ],
              if (_formError != null) ...[
                const SizedBox(height: 8),
                Text(
                  _formError!,
                  style: TextStyle(color: Colors.red.shade800, fontSize: 13),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                'El chat de este pedido sirve para agregar fotos o un video.',
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.35,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: OrderMotolinkThreadSection(
                  transactionRequestId: widget.request.id,
                  allowReplyAsAliado:
                      widget.allowReplyAsAliado && _windowOpen,
                  allowReplyAsImportador:
                      widget.allowReplyAsImportador && _windowOpen,
                  allowReplyAsAdmin: false,
                  deliveryGrace: _windowOpen,
                  suppressBuiltinTitle: true,
                  suppressInlineHelp: true,
                  expandMessages: true,
                  emptyHint: _registered
                      ? 'Si quiere, agregue una foto o un video como evidencia.'
                      : 'Después de registrarlo, puede adjuntar una foto o un video.',
                  mergedThreadRequestIds: widget.mergedThreadRequestIds,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QtyStepper extends StatelessWidget {
  const _QtyStepper({
    required this.value,
    required this.max,
    required this.enabled,
    required this.onChanged,
  });

  final int value;
  final int max;
  final bool enabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            value == 1
                ? '1 unidad con inconveniente'
                : '$value unidades con inconveniente',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        IconButton(
          onPressed: !enabled || value <= 1 ? null : () => onChanged(value - 1),
          icon: const Icon(Icons.remove_circle_outline),
          tooltip: 'Menos unidades',
        ),
        IconButton(
          onPressed: !enabled || value >= max ? null : () => onChanged(value + 1),
          icon: const Icon(Icons.add_circle_outline),
          tooltip: 'Más unidades',
        ),
      ],
    );
  }
}

class _SavedNote extends StatelessWidget {
  const _SavedNote({
    required this.product,
    required this.qtyLabel,
    required this.body,
    required this.at,
  });

  final String product;
  final String qtyLabel;
  final String? body;
  final DateTime? at;

  @override
  Widget build(BuildContext context) {
    final when = at == null ? null : formatEsShortDateTime(at!.toLocal());
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.brandBlueContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.brand.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              when == null
                  ? 'Quedó registrado en este pedido.'
                  : 'Quedó registrado en este pedido el $when.',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            ),
            const SizedBox(height: 6),
            Text(
              '$product · $qtyLabel',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            if (body != null && body!.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(body!.trim(), style: const TextStyle(fontSize: 13, height: 1.35)),
            ],
          ],
        ),
      ),
    );
  }
}

class _ResolutionNote extends StatelessWidget {
  const _ResolutionNote({
    required this.resolution,
    required this.creditAmount,
    required this.product,
    required this.qtyLabel,
  });

  final String resolution;
  final double creditAmount;
  final String product;
  final String qtyLabel;

  @override
  Widget build(BuildContext context) {
    final credit = resolution == OrderPostventaKind.credito;
    final text = credit
        ? 'Crédito de ${formatRefAmount(creditAmount)} REF para el próximo pedido con este proveedor. $product · $qtyLabel. No se descuenta solo.'
        : 'El proveedor atenderá esta devolución con un cambio de producto. $product · $qtyLabel.';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.brandBlueContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.brand.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          text,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, height: 1.35),
        ),
      ),
    );
  }
}
