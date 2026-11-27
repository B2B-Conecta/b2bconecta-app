import 'package:flutter/material.dart';

import 'support_ticket_model.dart';
import 'package:motolink_pro_app/app/main_shell_tab.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'package:motolink_pro_app/core/layout/app_breakpoints.dart';
import 'package:motolink_pro_app/core/utils/app_date_format.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';
import 'package:motolink_pro_app/features/admin/admin_users_hub_section.dart';
import 'support_ticket_status.dart';
import 'support_ticket_thread_section.dart';
import 'mobile_support_widgets.dart';

enum _SupportAction { refresh, details, dossier, close }

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
            Text('Creado el ${_stamp(_ticket.createdAt)}'),
            if (_ticket.closedAt != null) ...[
              const SizedBox(height: 8),
              Text('Cerrado el ${_stamp(_ticket.closedAt)}'),
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

  bool get _desktop =>
      MediaQuery.sizeOf(context).width >= AppBreakpoints.mobileMenu;

  String _stamp(DateTime? at) =>
      _desktop ? formatEsShortDateTime12h(at) : formatEsShortDateTime(at);

  void _openUserDossier() {
    final id = _ticket.createdBy.trim();
    if (id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Este reclamo no tiene un usuario asociado.'),
        ),
      );
      return;
    }
    MainShellTabController.navigateToAdminUsers(
      section: AdminUsersHubSection.cuentas,
      userId: id,
    );
  }

  void _onAction(_SupportAction action) {
    switch (action) {
      case _SupportAction.refresh:
        _reloadTicket(refreshMessages: true);
      case _SupportAction.details:
        _showDetails();
      case _SupportAction.dossier:
        _openUserDossier();
      case _SupportAction.close:
        _closeTicket();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_desktop && !widget.isAdminView && !widget.embedded) {
      return _mobileCustomerDetail();
    }
    final theme = B2BThemeExtension.of(context);
    final uid = SupabaseService.currentUserId;
    final isOwner = uid != null && _ticket.createdBy == uid;
    final statusFg = _isClosed
        ? theme.successFg
        : (_ticket.status == SupportTicketStatus.enRevision
            ? theme.textPrimary
            : theme.brand);
    final statusBg = _isClosed
        ? theme.successBg
        : (_ticket.status == SupportTicketStatus.enRevision
            ? theme.surfaceSubtle
            : theme.brandContainer);
    final desktop = _desktop;
    final webAdmin = desktop && widget.isAdminView;
    final roleLabel =
        _ticket.authorRole == 'importador' ? 'Mayorista' : 'Minorista';

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.isAdminView) ...[
                  Text(
                    _ticket.creatorDisplayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: theme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$roleLabel · ${_ticket.categoryLabel}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: theme.textSecondary,
                    ),
                  ),
                  if (webAdmin) ...[
                    const SizedBox(height: 4),
                    TextButton(
                      onPressed: _openUserDossier,
                      style: TextButton.styleFrom(
                        foregroundColor: theme.brand,
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        textStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: const Text('Ir al expediente del usuario'),
                    ),
                  ],
                  const SizedBox(height: 8),
                ],
                Tooltip(
                  message: _ticket.subject,
                  child: Text(
                    _ticket.subject,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: widget.embedded ? 14.5 : 18,
                      fontWeight: FontWeight.w700,
                      color: theme.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _isClosed ? 'Cerrado' : _ticket.statusLabel,
                        style: TextStyle(
                          color: statusFg,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (!webAdmin)
                      Text(
                        _ticket.categoryLabel,
                        style: TextStyle(
                          color: theme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    if (!webAdmin)
                      Text(
                        widget.isAdminView
                            ? _ticket.creatorDisplayName
                            : 'Soporte B2B Conecta',
                        style: TextStyle(
                          color: theme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    if (_ticket.relatedTransactionRequestId?.isNotEmpty == true)
                      TextButton(
                        onPressed: _showDetails,
                        style: TextButton.styleFrom(
                          foregroundColor: theme.brand,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Pedido vinculado',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: theme.brand,
                          ),
                        ),
                      ),
                    Text(
                      _stamp(_ticket.createdAt),
                      style: TextStyle(
                        fontSize: 11.5,
                        color: theme.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (!_isClosed && (isOwner || widget.isAdminView))
            Padding(
              padding: const EdgeInsets.only(top: 2, right: 4),
              child: OutlinedButton(
                onPressed: _closing ? null : _closeTicket,
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.textPrimary,
                  side: BorderSide(color: theme.borderStrong),
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: Text(
                  _closing ? 'Cerrando…' : 'Cerrar',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                    color: theme.textPrimary,
                  ),
                ),
              ),
            ),
          PopupMenuButton<_SupportAction>(
            tooltip: 'Opciones del reclamo',
            enabled: !_closing,
            onSelected: _onAction,
            icon: LucideIcon(
              LucideGlyph.slidersHorizontal,
              size: 18,
              color: theme.textSecondary,
            ),
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
              if (webAdmin)
                const PopupMenuItem(
                  value: _SupportAction.dossier,
                  child: Text('Ir al expediente del usuario'),
                ),
              if (!_isClosed && (isOwner || widget.isAdminView))
                const PopupMenuItem(
                  value: _SupportAction.close,
                  child: Text('Cerrar reclamo'),
                ),
            ],
          ),
        ],
      ),
    );

    final thread = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        Divider(height: 1, color: theme.borderSubtle),
        if (_closing || _refreshing)
          LinearProgressIndicator(
            minHeight: 2,
            color: theme.brand,
            backgroundColor: theme.brandContainer,
          ),
        Expanded(
          child: SupportTicketThreadSection(
            key: ValueKey('stm-${_ticket.id}'),
            ticketId: _ticket.id,
            canReplyAsOwner: isOwner && !widget.isAdminView,
            canReplyAsAdmin: widget.isAdminView,
            isTicketClosed: _isClosed,
            counterpartName: webAdmin ? _ticket.creatorDisplayName : null,
            refreshVersion: _refreshVersion,
            onThreadChanged: () => _reloadTicket(),
          ),
        ),
      ],
    );

    if (widget.embedded) {
      return ColoredBox(
        color: theme.surfaceCard,
        child: thread,
      );
    }

    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        backgroundColor: theme.surfaceCard,
        foregroundColor: theme.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Reclamo',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: theme.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: ColoredBox(
              color: theme.surfaceCard,
              child: thread,
            ),
          ),
        ),
      ),
    );
  }

  Widget _mobileCustomerDetail() {
    final theme = B2BThemeExtension.of(context);
    final owner = SupabaseService.currentUserId == _ticket.createdBy;
    final status = _isClosed ? SupportTicketStatus.cerrado : _ticket.status;
    return Scaffold(
      backgroundColor: theme.background,
      appBar: mobileSupportAppBar(context, 'Soporte B2B Conecta',
          avatar: true,
          actions: [
            PopupMenuButton<_SupportAction>(
                tooltip: 'Opciones del reclamo',
                enabled: !_closing,
                onSelected: _onAction,
                icon: const Icon(Icons.more_vert, color: Colors.white),
                itemBuilder: (_) => [
                      PopupMenuItem(
                          value: _SupportAction.refresh,
                          enabled: !_refreshing,
                          child: const Text('Actualizar conversación')),
                      if (owner && !_isClosed)
                        const PopupMenuItem(
                            value: _SupportAction.close,
                            child: Text('Cerrar reclamo')),
                    ]),
          ]),
      body: SafeArea(
          top: false,
          child: LayoutBuilder(
              builder: (context, bounds) => Column(children: [
                    ConstrainedBox(
                      constraints:
                          BoxConstraints(maxHeight: bounds.maxHeight * .42),
                      child: SingleChildScrollView(
                          child: Container(
                        margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                        decoration: BoxDecoration(
                            color: theme.brandContainer,
                            borderRadius: BorderRadius.circular(16)),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(supportReference(_ticket.id),
                                  style: TextStyle(
                                      color: theme.textSecondary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12)),
                              const SizedBox(height: 5),
                              Text(_ticket.subject,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(height: 8),
                              Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    SupportStatusChip(status: status),
                                    Text(_ticket.categoryLabel)
                                  ]),
                              Theme(
                                  data: Theme.of(context).copyWith(
                                      dividerColor: Colors.transparent),
                                  child: ExpansionTile(
                                    tilePadding: EdgeInsets.zero,
                                    childrenPadding:
                                        const EdgeInsets.only(bottom: 12),
                                    title: Text('Ver datos del reclamo',
                                        style: TextStyle(
                                            color: theme.brand,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600)),
                                    children: [
                                      Align(
                                          alignment: Alignment.centerLeft,
                                          child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                    'Creado el ${_stamp(_ticket.createdAt)}'),
                                                if (_ticket.closedAt != null)
                                                  Text(
                                                      'Cerrado el ${_stamp(_ticket.closedAt)}'),
                                                if (_ticket
                                                        .relatedTransactionRequestId
                                                        ?.isNotEmpty ==
                                                    true) ...[
                                                  const SizedBox(height: 8),
                                                  const Text('Pedido vinculado',
                                                      style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.w600)),
                                                  SelectableText(
                                                      '#${_ticket.relatedTransactionRequestId!.substring(0, _ticket.relatedTransactionRequestId!.length.clamp(0, 8)).toUpperCase()}'),
                                                ],
                                                const SizedBox(height: 8),
                                                const Text(
                                                    'Identificador completo',
                                                    style: TextStyle(
                                                        fontSize: 12)),
                                                SelectableText(_ticket.id,
                                                    style: TextStyle(
                                                        color:
                                                            theme.textSecondary,
                                                        fontSize: 12)),
                                              ])),
                                    ],
                                  )),
                            ]),
                      )),
                    ),
                    if (_closing || _refreshing)
                      const LinearProgressIndicator(minHeight: 2),
                    Expanded(
                        child: SupportTicketThreadSection(
                      key: ValueKey('stm-${_ticket.id}'),
                      ticketId: _ticket.id,
                      canReplyAsOwner: owner,
                      canReplyAsAdmin: false,
                      isTicketClosed: _isClosed,
                      refreshVersion: _refreshVersion,
                      onThreadChanged: () => _reloadTicket(),
                    )),
                  ]))),
    );
  }
}
