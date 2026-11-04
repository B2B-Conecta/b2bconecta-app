import 'package:flutter/material.dart';

import 'support_ticket_category.dart';
import 'support_ticket_model.dart';
import 'support_ticket_status.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/utils/app_date_format.dart';
import 'support_ticket_detail_screen.dart';

/// Listado y creación de reclamos (aliado / importador).
class SupportTicketsScreen extends StatefulWidget {
  const SupportTicketsScreen({
    super.key,
    this.relatedTransactionRequestId,
  });

  /// Si se abre desde un pedido, se vincula en backend sin pedir UUID al usuario.
  final String? relatedTransactionRequestId;

  @override
  State<SupportTicketsScreen> createState() => _SupportTicketsScreenState();
}

class _SupportTicketsScreenState extends State<SupportTicketsScreen> {
  static const _openLimit = 3;
  List<SupportTicketModel> _rows = [];
  int _openCount = 0;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        SupabaseService.listMySupportTickets(),
        SupabaseService.countMyOpenSupportTickets(),
      ]);
      if (!mounted) return;
      setState(() {
        _rows = results[0] as List<SupportTicketModel>;
        _openCount = results[1] as int;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _openCreateSheet() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      constraints: const BoxConstraints(maxWidth: 560),
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _CreateSupportTicketSheet(
        relatedTransactionRequestId: widget.relatedTransactionRequestId,
      ),
    );

    if (mounted && created == true) {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = _rows.where((ticket) => !ticket.isClosed).toList();
    final closed = _rows.where((ticket) => ticket.isClosed).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('Atención al cliente'),
        actions: [
          IconButton(
            tooltip: 'Actualizar reclamos',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: [
                  _supportSummary(),
                  const SizedBox(height: 24),
                  if (_loading)
                    const LinearProgressIndicator(
                      semanticsLabel: 'Cargando reclamos',
                    )
                  else if (_error != null)
                    _messagePanel(
                      icon: Icons.error_outline,
                      title: 'No pudimos cargar tus reclamos',
                      description:
                          'Intenta actualizar para volver a consultarlos.',
                      action: TextButton(
                        onPressed: _load,
                        child: const Text('Reintentar'),
                      ),
                    )
                  else if (_rows.isEmpty)
                    _messagePanel(
                      icon: Icons.forum_outlined,
                      title: 'Aún no tienes reclamos',
                      description:
                          'Cuando abras un reclamo, podrás seguirlo desde aquí.',
                    )
                  else ...[
                    if (active.isNotEmpty) ...[
                      _sectionHeading('Reclamos activos'),
                      for (final ticket in active) _ticketRow(ticket),
                    ],
                    if (closed.isNotEmpty) ...[
                      if (active.isNotEmpty) const SizedBox(height: 14),
                      _sectionHeading('Historial de reclamos'),
                      for (final ticket in closed) _ticketRow(ticket),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _supportSummary() {
    final atLimit = _openCount >= _openLimit;
    final canCreate = !_loading && _error == null && !atLimit;
    final summary = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.brandBlueContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.support_agent_outlined, color: _accent),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '¿Cómo podemos ayudarte?',
                style: TextStyle(
                    fontSize: 22, height: 1.2, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                'Consulta al equipo B2B Conecta sobre tu cuenta, pagos, pedidos, '
                'verificación o fallas de la plataforma.',
                style: TextStyle(height: 1.4, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
    final action = FilledButton.icon(
      onPressed: canCreate ? _openCreateSheet : null,
      icon: const Icon(Icons.add_comment_outlined, size: 19),
      label: const Text('Abrir reclamo'),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.fieldFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: LayoutBuilder(builder: (context, constraints) {
          final sideBySide = constraints.maxWidth >= 630 &&
              MediaQuery.textScalerOf(context).scale(14) <= 18;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (sideBySide)
                Row(children: [
                  Expanded(child: summary),
                  const SizedBox(width: 24),
                  action,
                ])
              else ...[
                summary,
                const SizedBox(height: 14),
                action,
              ],
              if (!_loading && _error == null) ...[
                Divider(height: 24, color: AppColors.borderSubtle),
                Text(
                  '$_openCount de $_openLimit reclamos abiertos',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (atLimit)
                  Text(
                    'Cierra un reclamo para poder abrir otro.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
              ],
            ],
          );
        }),
      ),
    );
  }

  Color get _accent =>
      AppColors.isDarkOf(context) ? const Color(0xFFB3C8FF) : AppColors.brand;

  Widget _sectionHeading(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Semantics(
          header: true,
          child: Text(title,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        ),
      );

  Widget _messagePanel({
    required IconData icon,
    required String title,
    required String description,
    Widget? action,
  }) =>
      Material(
        color: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: AppColors.borderSubtle),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(icon, color: _accent, size: 28),
              const SizedBox(height: 8),
              Text(title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 4),
              Text(description,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary)),
              if (action != null) action,
            ],
          ),
        ),
      );

  Widget _ticketRow(SupportTicketModel ticket) {
    final inReview = ticket.status.trim() == SupportTicketStatus.enRevision;
    final statusColor = ticket.isClosed
        ? AppColors.textSecondary
        : inReview
            ? (AppColors.isDarkOf(context)
                ? AppColors.warningAmberOnDark
                : AppColors.warningAmber)
            : _accent;
    final status = DecoratedBox(
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(ticket.statusLabel,
            style: TextStyle(
                color: statusColor, fontSize: 12, fontWeight: FontWeight.w700)),
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: AppColors.borderSubtle),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () async {
            await Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => SupportTicketDetailScreen(
                    ticket: ticket, isAdminView: false),
              ),
            );
            if (mounted) await _load();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(
                    ticket.isClosed
                        ? Icons.check_circle_outline
                        : Icons.forum_outlined,
                    color: ticket.isClosed ? AppColors.textSecondary : _accent,
                    size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ticket.subject,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 5),
                      Wrap(
                        spacing: 10,
                        runSpacing: 5,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          status,
                          Text(ticket.categoryLabel,
                              style: TextStyle(color: AppColors.textSecondary)),
                          if (ticket.createdAt != null)
                            Text(formatEsShortDateTime(ticket.createdAt),
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right, color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CreateSupportTicketSheet extends StatefulWidget {
  const _CreateSupportTicketSheet({this.relatedTransactionRequestId});

  final String? relatedTransactionRequestId;

  @override
  State<_CreateSupportTicketSheet> createState() =>
      _CreateSupportTicketSheetState();
}

class _CreateSupportTicketSheetState extends State<_CreateSupportTicketSheet> {
  final _subjectCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  String _category = SupportTicketCategory.plataforma;
  bool _saving = false;

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await SupabaseService.createSupportTicket(
        subject: _subjectCtrl.text,
        category: _category,
        body: _bodyCtrl.text,
        relatedTransactionRequestId: widget.relatedTransactionRequestId,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Nuevo reclamo',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _category,
              decoration: const InputDecoration(
                labelText: 'Categoría',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final c in SupportTicketCategory.all)
                  DropdownMenuItem(
                    value: c,
                    child: Text(SupportTicketCategory.labelEs(c)),
                  ),
              ],
              onChanged: _saving
                  ? null
                  : (v) {
                      if (v != null) setState(() => _category = v);
                    },
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _subjectCtrl,
              decoration: const InputDecoration(
                labelText: 'Asunto',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _bodyCtrl,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Describa su incidencia',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    child: Text(_saving ? 'Enviando…' : 'Enviar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
