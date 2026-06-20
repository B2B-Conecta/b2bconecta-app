import 'package:flutter/material.dart';

import '../models/support_ticket_model.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_date_format.dart';
import '../widgets/support_ticket_thread_section.dart';

/// Detalle de un reclamo (aliado, importador o admin).
class SupportTicketDetailScreen extends StatefulWidget {
  const SupportTicketDetailScreen({
    super.key,
    required this.ticket,
    required this.isAdminView,
  });

  final SupportTicketModel ticket;
  final bool isAdminView;

  @override
  State<SupportTicketDetailScreen> createState() =>
      _SupportTicketDetailScreenState();
}

class _SupportTicketDetailScreenState extends State<SupportTicketDetailScreen> {
  late SupportTicketModel _ticket;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _ticket = widget.ticket;
  }

  Future<void> _reloadTicket() async {
    final fresh = await SupabaseService.fetchSupportTicketById(_ticket.id);
    if (!mounted || fresh == null) return;
    setState(() => _ticket = fresh);
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
      await _reloadTicket();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reclamo cerrado.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo cerrar: $e')),
      );
    } finally {
      if (mounted) setState(() => _closing = false);
    }
  }

  Color _statusColor() {
    if (_ticket.isClosed) return Colors.grey.shade700;
    if (_ticket.status == 'en_revision') return AppColors.brandBlue;
    return AppColors.brandOrange;
  }

  @override
  Widget build(BuildContext context) {
    final uid = SupabaseService.currentUserId;
    final isOwner = uid != null && _ticket.createdBy == uid;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('Reclamo'),
        actions: [
          if (!_ticket.isClosed)
            TextButton(
              onPressed: _closing ? null : _closeTicket,
              child: _closing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Cerrar'),
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _statusColor().withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _ticket.statusLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: _statusColor(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _ticket.categoryLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _ticket.subject,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    if (widget.isAdminView) ...[
                      const SizedBox(height: 6),
                      Text(
                        '${_ticket.authorRole == 'importador' ? 'Importador' : 'Aliado'} · '
                        '${_ticket.creatorDisplayName}',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ],
                    if (widget.isAdminView &&
                        _ticket.relatedTransactionRequestId != null &&
                        _ticket.relatedTransactionRequestId!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Pedido vinculado: ${_ticket.relatedTransactionRequestId}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      'Creado ${formatEsShortDateTime(_ticket.createdAt)}',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SupportTicketThreadSection(
                key: ValueKey<String>('stm-${_ticket.id}-${_ticket.status}'),
                ticketId: _ticket.id,
                canReplyAsOwner: isOwner && !widget.isAdminView,
                canReplyAsAdmin: widget.isAdminView,
                isTicketClosed: _ticket.isClosed,
                onThreadChanged: _reloadTicket,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
