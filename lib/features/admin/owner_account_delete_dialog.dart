import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/features/admin/admin_service.dart';
import 'package:motolink_pro_app/features/admin/owner_account_rules.dart';
import 'package:motolink_pro_app/features/admin/owner_related_orders.dart';
import 'package:motolink_pro_app/features/orders/shared/order_flow_copy/order_status_flow_copy.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';
import 'package:motolink_pro_app/features/profile/profile_role_labels.dart';

enum OwnerAccountDeleteKind { soft, hard }

/// Popup de confirmación para baja lógica o borrado de Auth.
Future<String?> showOwnerAccountDeleteDialog({
  required BuildContext context,
  required ProfileModel profile,
  required OwnerAccountDeleteKind kind,
}) {
  return showDialog<String>(
    context: context,
    builder: (ctx) => _OwnerAccountDeleteDialog(
      profile: profile,
      kind: kind,
    ),
  );
}

class _OwnerAccountDeleteDialog extends StatefulWidget {
  const _OwnerAccountDeleteDialog({
    required this.profile,
    required this.kind,
  });

  final ProfileModel profile;
  final OwnerAccountDeleteKind kind;

  @override
  State<_OwnerAccountDeleteDialog> createState() =>
      _OwnerAccountDeleteDialogState();
}

class _OwnerAccountDeleteDialogState extends State<_OwnerAccountDeleteDialog> {
  final _ctrl = TextEditingController();
  bool _loadingOrders = false;
  String? _ordersError;
  OwnerRelatedOrders _related = OwnerRelatedOrders.empty;
  bool _showOrders = false;

  @override
  void initState() {
    super.initState();
    if (_isHard) _loadOrders();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _loadingOrders = true;
      _ordersError = null;
    });
    try {
      final related = await AdminService.ownerProfileRelatedOrders(
        widget.profile.id,
      );
      if (!mounted) return;
      setState(() {
        _related = related;
        _loadingOrders = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingOrders = false;
        _ordersError =
            'No se pudo revisar si esta cuenta tiene pedidos. Puede continuar.';
      });
    }
  }

  bool get _isHard => widget.kind == OwnerAccountDeleteKind.hard;

  String get _who {
    final name = widget.profile.businessName?.trim();
    final email = widget.profile.email?.trim();
    if (name != null && name.isNotEmpty && email != null && email.isNotEmpty) {
      return '$name ($email)';
    }
    return email ?? name ?? widget.profile.id;
  }

  bool get _canConfirm {
    if (_isHard) {
      return OwnerAccountRules.hardDeleteConfirmMatches(
        typed: _ctrl.text,
        email: widget.profile.email,
      );
    }
    return _ctrl.text.trim().length >= 3;
  }

  @override
  Widget build(BuildContext context) {
    final role = ProfileRoleLabels.labelEs(widget.profile.role);
    return AlertDialog(
      title: Text(_isHard ? 'Borrar definitivo' : 'Eliminar cuenta'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isHard
                  ? 'Se borra la cuenta y se libera el correo. '
                      'No se puede deshacer.\n\n$_who · $role'
                  : 'La cuenta deja de entrar. El historial se conserva '
                      'y el correo no se libera.\n\n$_who · $role',
            ),
            if (_isHard) ...[
              const SizedBox(height: 14),
              _ordersNotice(),
            ],
            const SizedBox(height: 14),
            TextField(
              controller: _ctrl,
              autofocus: true,
              maxLines: _isHard ? 1 : 3,
              keyboardType:
                  _isHard ? TextInputType.emailAddress : TextInputType.text,
              decoration: InputDecoration(
                hintText: _isHard
                    ? 'Escriba el correo para confirmar…'
                    : 'Motivo (visible en la cuenta)…',
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
          onPressed: _canConfirm ? _submit : null,
          child: Text(
            _isHard
                ? (_related.count > 0 ? 'Borrar de todas maneras' : 'Borrar')
                : 'Eliminar',
          ),
        ),
      ],
    );
  }

  void _submit() {
    if (!_canConfirm) return;
    Navigator.of(context).pop(_ctrl.text.trim());
  }

  Widget _ordersNotice() {
    if (_loadingOrders) {
      return const Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 10),
          Expanded(child: Text('Revisando si tiene pedidos…')),
        ],
      );
    }
    if (_ordersError != null) {
      return Text(
        _ordersError!,
        style: TextStyle(color: AppColors.textSecondary, height: 1.35),
      );
    }
    if (_related.count == 0) {
      return Text(
        'Esta cuenta no tiene pedidos asociados.',
        style: TextStyle(color: AppColors.textSecondary, height: 1.35),
      );
    }
    final n = _related.count;
    final noun = n == 1 ? 'pedido asociado' : 'pedidos asociados';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Esta cuenta tiene $n $noun. Si la borra, esos pedidos '
              'también se eliminan y no se pueden recuperar. El inventario '
              'del otro negocio no cambia.',
              style: TextStyle(
                color: Colors.red.shade900,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => setState(() => _showOrders = !_showOrders),
                child: Text(_showOrders ? 'Ocultar pedidos' : 'Ver pedidos'),
              ),
            ),
            if (_showOrders) ...[
              for (final order in _related.orders) _orderLine(order),
              if (_related.count > _related.orders.length)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Se muestran ${_related.orders.length} de ${_related.count}.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _orderLine(OwnerRelatedOrder order) {
    final when = _formatDate(order.createdAt);
    final status = OrderStatusFlowCopy.labelEs(order.status);
    final bits = <String>[
      order.side,
      if (when.isNotEmpty) when,
      status,
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            order.productName,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          Text(
            '${bits.join(' · ')} · ${order.counterpartyName}',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.3,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? value) {
    if (value == null) return '';
    final local = value.toLocal();
    final dd = local.day.toString().padLeft(2, '0');
    final mm = local.month.toString().padLeft(2, '0');
    return '$dd/$mm/${local.year}';
  }
}
