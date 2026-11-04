import 'package:flutter/material.dart';

import 'support_ticket_model.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/utils/app_date_format.dart';
import 'support_ticket_thread_section.dart';

enum _SupportAction { refresh, details, close }

/// Detalle de un reclamo (aliado, importador o admin).
class SupportTicketDetailScreen extends StatefulWidget {
  const SupportTicketDetailScreen({
    super.key,
    required this.ticket,
    required this.isAdminView,
    this.embedded = false,
    this.onTicketChanged,
  });

  final SupportTicketModel ticket;
  final bool isAdminView;
  final bool embedded;
  final VoidCallback? onTicketChanged;

  @override
  State<SupportTicketDetailScreen> createState() =>
      _SupportTicketDetailScreenState();
}

class _SupportTicketDetailScreenState extends State<SupportTicketDetailScreen> {
  late SupportTicketModel _ticket;
  bool _closing = false;
  bool _closedLocally = false;
  bool _refreshing = false;
  int _refreshVersion = 0;

  bool get _isClosed => _closedLocally || _ticket.isClosed;

  @override
  void initState() {
    super.initState();
    _ticket = widget.ticket;
  }

  Future<void> _reloadTicket({bool refreshMessages = false}) async {
    if (refreshMessages) setState(() => _refreshing = true);
    try {
      final fresh = await SupabaseService.fetchSupportTicketById(_ticket.id);
      if (!mounted || fresh == null) return;
      setState(() {
        _ticket = fresh;
        if (refreshMessages) _refreshVersion++;
      });
      widget.onTicketChanged?.call();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('No se pudo actualizar el reclamo. Inténtalo de nuevo.'),
        ),
      );
    } finally {
      if (mounted && refreshMessages) setState(() => _refreshing = false);
    }
  }

  Future<void> _closeTicket() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar reclamo'),
        content: const Text(
          '¿Confirma que desea cerrar este reclamo? '
          'Podrá consultarlo en el historial pero no enviar más mensajes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cerrar reclamo'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _closing = true);
    try {
      await SupabaseService.closeSupportTicket(_ticket.id);
      if (!mounted) return;
      setState(() => _closedLocally = true);
      widget.onTicketChanged?.call();
      await _reloadTicket();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reclamo cerrado.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo cerrar. Inténtalo de nuevo.')),
      );
    } finally {
      if (mounted) setState(() => _closing = false);
    }
  }

  Future<void> _showDetails() {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Datos del reclamo'),
        scrollable: true,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_ticket.subject,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Text('Creado el ${formatEsShortDateTime(_ticket.createdAt)}'),
            if (_ticket.closedAt != null) ...[
              const SizedBox(height: 8),
              Text('Cerrado el ${formatEsShortDateTime(_ticket.closedAt)}'),
            ],
            if (widget.isAdminView) ...[
              const SizedBox(height: 8),
              Text(_ticket.creatorDisplayName),
              Text(_ticket.authorRole == 'importador'
                  ? 'Importador'
                  : 'Tienda minorista'),
            ],
            if (_ticket.relatedTransactionRequestId?.isNotEmpty == true) ...[
              const SizedBox(height: 12),
              const Text('Pedido vinculado',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              SelectableText(_ticket.relatedTransactionRequestId!),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  void _onAction(_SupportAction action) {
    switch (action) {
      case _SupportAction.refresh:
        _reloadTicket(refreshMessages: true);
      case _SupportAction.details:
        _showDetails();
      case _SupportAction.close:
        _closeTicket();
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = SupabaseService.currentUserId;
    final isOwner = uid != null && _ticket.createdBy == uid;
    final statusColor =
        _isClosed ? AppColors.textSecondary : AppColors.brandLink;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: !widget.embedded,
        title: const Text('Reclamo'),
        actions: [
          PopupMenuButton<_SupportAction>(
            tooltip: 'Opciones del reclamo',
            enabled: !_closing,
            onSelected: _onAction,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: _SupportAction.refresh,
                enabled: !_refreshing,
                child: const Text('Actualizar conversación'),
              ),
              const PopupMenuItem(
                value: _SupportAction.details,
                child: Text('Datos del reclamo'),
              ),
              if (!_isClosed && (isOwner || widget.isAdminView))
                const PopupMenuItem(
                  value: _SupportAction.close,
                  child: Text('Cerrar reclamo'),
                ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Tooltip(
                        message: _ticket.subject,
                        child: Text(
                          _ticket.subject,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 10,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _isClosed ? 'Cerrado' : _ticket.statusLabel,
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(_ticket.categoryLabel,
                              style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12)),
                          Text(
                            widget.isAdminView
                                ? _ticket.creatorDisplayName
                                : 'Soporte B2B Conecta',
                            style: TextStyle(
                                color: AppColors.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                if (_closing || _refreshing)
                  const LinearProgressIndicator(minHeight: 2),
                Expanded(
                  child: SupportTicketThreadSection(
                    key: ValueKey('stm-${_ticket.id}'),
                    ticketId: _ticket.id,
                    canReplyAsOwner: isOwner && !widget.isAdminView,
                    canReplyAsAdmin: widget.isAdminView,
                    isTicketClosed: _isClosed,
                    refreshVersion: _refreshVersion,
                    onThreadChanged: () => _reloadTicket(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
