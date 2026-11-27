part of 'support_tickets_screen.dart';

enum SupportTicketFilter { all, open, closed }

extension _MobileSupportTickets on _SupportTicketsScreenState {
  Future<void> _openMobileCreate() async {
    if (_loading || _error != null || _openCount >= supportOpenLimit) return;
    final ticket = await Navigator.of(context).push<SupportTicketModel>(
        MaterialPageRoute(
            builder: (_) => MobileCreateSupportTicketScreen(
                relatedTransactionRequestId:
                    widget.relatedTransactionRequestId)));
    if (!mounted) return;
    if (ticket != null) {
      await _openMobileTicket(ticket);
    } else {
      await _load();
    }
  }

  Future<void> _openMobileTicket(SupportTicketModel ticket) async {
    await Navigator.of(context).push<void>(MaterialPageRoute(
        builder: (_) =>
            SupportTicketDetailScreen(ticket: ticket, isAdminView: false)));
    if (mounted) await _load();
  }

  Widget _buildMobile() {
    final theme = B2BThemeExtension.of(context);
    final filtered = _rows
        .where((ticket) => switch (_mobileFilter) {
              SupportTicketFilter.all => true,
              SupportTicketFilter.open => !ticket.isClosed,
              SupportTicketFilter.closed => ticket.isClosed,
            })
        .toList();
    final canCreate =
        !_loading && _error == null && _openCount < supportOpenLimit;
    return Scaffold(
      backgroundColor: theme.background,
      appBar: mobileSupportAppBar(context, 'Atención al cliente', actions: [
        IconButton(
            tooltip: 'Actualizar reclamos',
            onPressed: _loading ? null : _load,
            icon: const LucideIcon(LucideGlyph.refreshCw,
                color: Colors.white, size: 20)),
      ]),
      body: SafeArea(
          top: false,
          bottom: false,
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                            color: theme.brandContainer,
                            shape: BoxShape.circle),
                        child: Center(
                            child: LucideIcon(LucideGlyph.headset,
                                color: theme.brand, size: 28))),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          const Text('¿En qué podemos ayudarte?',
                              style: TextStyle(
                                  fontSize: 22,
                                  height: 1.2,
                                  fontWeight: FontWeight.w800)),
                          const SizedBox(height: 6),
                          Text('Consulta tus reclamos o abre uno nuevo.',
                              style: TextStyle(
                                  color: theme.textSecondary, height: 1.35)),
                        ])),
                  ]),
                  const SizedBox(height: 16),
                  const Text(
                      'Soporte para tu cuenta, pagos y uso de B2B Conecta. Los problemas con un producto o entrega se reportan al proveedor desde el pedido.',
                      style: TextStyle(fontSize: 13, height: 1.4)),
                  const SizedBox(height: 14),
                  if (!_loading && _error == null) ...[
                    Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: theme.brandContainer,
                            borderRadius: BorderRadius.circular(12)),
                        child: Row(children: [
                          Expanded(
                              child: Text(
                                  'Abiertos: $_openCount de $supportOpenLimit',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700))),
                          ExcludeSemantics(
                              child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                for (var i = 0; i < supportOpenLimit; i++)
                                  Container(
                                      width: 10,
                                      height: 10,
                                      margin: const EdgeInsets.only(left: 6),
                                      decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: i < _openCount
                                              ? theme.brand
                                              : theme.borderSubtle)),
                              ])),
                        ])),
                    if (_openCount >= supportOpenLimit) ...[
                      const SizedBox(height: 10),
                      const SupportInfoNotice(
                          'Tienes tres reclamos abiertos. Continúa en uno de ellos o cierra un caso que ya no necesites antes de abrir otro.'),
                    ],
                  ],
                  const SizedBox(height: 14),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final entry in const {
                      SupportTicketFilter.all: 'Todos',
                      SupportTicketFilter.open: 'Abiertos',
                      SupportTicketFilter.closed: 'Cerrados'
                    }.entries)
                      ChoiceChip(
                          label: Text(entry.value),
                          selected: _mobileFilter == entry.key,
                          showCheckmark: false,
                          selectedColor: supportMobileBlue,
                          labelStyle: TextStyle(
                              color: _mobileFilter == entry.key
                                  ? Colors.white
                                  : theme.textPrimary,
                              fontWeight: FontWeight.w600),
                          onSelected: (_) => _setMobileFilter(entry.key)),
                  ]),
                  const SizedBox(height: 16),
                  if (_loading)
                    const LinearProgressIndicator(
                        semanticsLabel: 'Cargando reclamos'),
                  if (_error != null)
                    _messagePanel(
                        icon: Icons.error_outline,
                        title: 'No pudimos cargar tus reclamos',
                        description:
                            'Revisa tu conexión y vuelve a intentarlo.',
                        action: TextButton(
                            onPressed: _load, child: const Text('Reintentar')))
                  else if (!_loading && filtered.isEmpty)
                    _messagePanel(
                        title: _rows.isEmpty
                            ? 'Aún no tienes reclamos'
                            : _mobileFilter == SupportTicketFilter.closed
                                ? 'No tienes reclamos cerrados'
                                : 'No tienes reclamos abiertos',
                        description: _rows.isEmpty
                            ? 'Puedes abrir uno para recibir ayuda del equipo B2B Conecta.'
                            : 'Puedes consultar los demás casos en Todos.')
                  else
                    for (final ticket in filtered) _mobileTicketRow(ticket),
                ]),
          )),
      bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: FilledButton.icon(
                  onPressed: canCreate ? _openMobileCreate : null,
                  style: FilledButton.styleFrom(
                      backgroundColor: supportMobileBlue,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 48),
                      padding: const EdgeInsets.all(12)),
                  icon: const Icon(Icons.add),
                  label: const Text('Nuevo reclamo')))),
    );
  }

  Widget _mobileTicketRow(SupportTicketModel ticket) {
    final theme = B2BThemeExtension.of(context);
    return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Material(
          color: ticket.isClosed ? theme.surfaceCard : theme.brandContainer,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: theme.borderSubtle)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
              onTap: () => _openMobileTicket(ticket),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LucideIcon(LucideGlyph.fileText,
                          size: 24, color: theme.brand),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Wrap(
                                spacing: 7,
                                runSpacing: 5,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  SupportStatusChip(status: ticket.status),
                                  Text(ticket.categoryLabel,
                                      style: TextStyle(
                                          color: theme.textSecondary,
                                          fontSize: 12))
                                ]),
                            const SizedBox(height: 8),
                            Text(ticket.subject,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 6),
                            Text(
                                '${supportReference(ticket.id)}${ticket.createdAt == null ? '' : ' · ${formatEsShortDate(ticket.createdAt!)}'}',
                                style: TextStyle(
                                    fontSize: 12, color: theme.textSecondary)),
                          ])),
                      const SizedBox(width: 4),
                      Icon(Icons.chevron_right, color: theme.brand),
                    ]),
              )),
        ));
  }
}
