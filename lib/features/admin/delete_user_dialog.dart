import 'package:flutter/material.dart';

import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';
import 'package:motolink_pro_app/features/admin/admin_service.dart';
import 'package:motolink_pro_app/features/admin/admin_users_chrome.dart';
import 'package:motolink_pro_app/features/admin/owner_related_orders.dart';
import 'package:motolink_pro_app/features/admin/unified_action_dialog.dart';
import 'package:motolink_pro_app/features/orders/shared/order_flow_copy/order_status_flow_copy.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';

/// Confirmación de eliminación permanente (libera el correo).
Future<bool?> showDeleteUserDialog({
  required BuildContext context,
  required ProfileModel profile,
  Future<void> Function(String confirm)? onDelete,
  Future<OwnerRelatedOrders> Function(String profileId)? loadRelatedOrders,
}) {
  return UnifiedActionDialog.show<bool>(
    context: context,
    builder: (ctx) => DeleteUserDialog(
      profile: profile,
      onDelete: onDelete,
      loadRelatedOrders: loadRelatedOrders,
    ),
  );
}

class DeleteUserDialog extends StatefulWidget {
  const DeleteUserDialog({
    super.key,
    required this.profile,
    this.onDelete,
    this.loadRelatedOrders,
  });

  final ProfileModel profile;
  final Future<void> Function(String confirm)? onDelete;
  final Future<OwnerRelatedOrders> Function(String profileId)? loadRelatedOrders;

  @override
  State<DeleteUserDialog> createState() => _DeleteUserDialogState();
}

class _DeleteUserDialogState extends State<DeleteUserDialog> {
  bool _busy = false;
  bool _loadingOrders = true;
  String? _ordersError;
  OwnerRelatedOrders _related = OwnerRelatedOrders.empty;
  bool _showOrders = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  String get _displayName {
    final name = widget.profile.businessName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final email = widget.profile.email?.trim();
    if (email != null && email.isNotEmpty) return email;
    return 'esta cuenta';
  }

  String get _email {
    final email = widget.profile.email?.trim();
    if (email != null && email.isNotEmpty) return email;
    return widget.profile.id;
  }

  Future<void> _loadOrders() async {
    setState(() {
      _loadingOrders = true;
      _ordersError = null;
    });
    try {
      final loader = widget.loadRelatedOrders;
      final related = loader != null
          ? await loader(widget.profile.id)
          : await AdminService.ownerProfileRelatedOrders(widget.profile.id);
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

  Future<void> _confirm() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final onDelete = widget.onDelete;
    try {
      if (onDelete != null) await onDelete(_email);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return UnifiedActionDialog(
      title: '¿Eliminar a $_displayName?',
      subtitle:
          'Esta acción eliminará permanentemente su cuenta, expediente, datos '
          'fiscales y acceso, liberando el correo electrónico. No se puede '
          'deshacer.',
      glyph: LucideGlyph.trash2,
      tone: UnifiedActionTone.danger,
      profile: widget.profile,
      primaryLabel:
          _related.count > 0 ? 'Eliminar de todas maneras' : 'Eliminar y liberar correo',
      busy: _busy,
      onPrimary: _confirm,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ordersNotice(),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFFDC2626),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _ordersNotice() {
    if (_loadingOrders) {
      return Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AdminUsersChrome.brand,
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Revisando pedidos asociados…',
              style: TextStyle(fontSize: 12, color: AdminUsersChrome.muted),
            ),
          ),
        ],
      );
    }
    if (_ordersError != null) {
      return Text(
        _ordersError!,
        style: TextStyle(
          fontSize: 12,
          height: 1.35,
          color: AdminUsersChrome.muted,
        ),
      );
    }
    if (_related.count == 0) {
      return Text(
        'Esta cuenta no tiene pedidos asociados.',
        style: TextStyle(
          fontSize: 12,
          height: 1.35,
          color: AdminUsersChrome.muted,
        ),
      );
    }
    final n = _related.count;
    final noun = n == 1 ? 'pedido asociado' : 'pedidos asociados';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Esta cuenta tiene $n $noun. Al borrarla, esos pedidos '
              'también se eliminan.',
              style: const TextStyle(
                fontSize: 12,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: Color(0xFF991B1B),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: const Color(0xFFDC2626),
                ),
                onPressed: () => setState(() => _showOrders = !_showOrders),
                child: Text(
                  _showOrders ? 'Ocultar pedidos' : 'Ver pedidos',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
            if (_showOrders)
              for (final order in _related.orders) _orderLine(order),
          ],
        ),
      ),
    );
  }

  Widget _orderLine(OwnerRelatedOrder order) {
    final when = _formatDate(order.createdAt);
    final status = OrderStatusFlowCopy.labelEs(order.status);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            order.productName,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AdminUsersChrome.titleColor,
            ),
          ),
          Text(
            [
              order.side,
              if (when.isNotEmpty) when,
              status,
              order.counterpartyName,
            ].join(' · '),
            style: TextStyle(
              fontSize: 11,
              height: 1.3,
              color: AdminUsersChrome.muted,
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
