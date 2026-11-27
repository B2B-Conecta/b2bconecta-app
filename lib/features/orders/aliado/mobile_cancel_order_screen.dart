import 'package:flutter/material.dart';

import '../../../core/layout/app_breakpoints.dart';
import '../../../app/theme/b2b_theme_extension.dart';
import '../../../core/widgets/desktop_workflow.dart';
import '../shared/mobile_order_action_widgets.dart';
import '../shared/transaction_request_model.dart';

/// Returns after explicit cancellation; each successful line is retained on retry.
class MobileCancelOrderScreen extends StatefulWidget {
  const MobileCancelOrderScreen({
    super.key,
    required this.lines,
    required this.cancelLine,
    required this.loadLines,
    this.onRate,
    this.onExplore,
  });
  final List<TransactionRequestModel> lines;
  final Future<void> Function(TransactionRequestModel line, String reason)
      cancelLine;
  final Future<List<TransactionRequestModel>> Function() loadLines;
  final Future<void> Function(BuildContext context,
      List<TransactionRequestModel> cancelled, String reason)? onRate;
  final VoidCallback? onExplore;
  @override
  State<MobileCancelOrderScreen> createState() =>
      _MobileCancelOrderScreenState();
}

class _MobileCancelOrderScreenState extends State<MobileCancelOrderScreen> {
  final _reason = TextEditingController();
  final _form = GlobalKey<FormState>();
  final _scroll = ScrollController();
  final _done = <String>{};
  bool _saving = false, _confirmed = false, _attempted = false;
  String? _error;
  List<TransactionRequestModel>? _saved;

  @override
  void dispose() {
    _reason.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _back() {
    if (!_saving) Navigator.pop(context, _done.isNotEmpty);
  }

  Future<void> _cancel() async {
    if (_saving) return;
    if (!_form.currentState!.validate()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Scrollable.ensureVisible(_form.currentContext!, alignment: .2);
        }
      });
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _attempted = true;
      _error = null;
    });
    try {
      // Re-read before every attempt: an invoice or a closed line can change meanwhile.
      final current = await widget.loadLines();
      for (final original in widget.lines) {
        if (_done.contains(original.id)) continue;
        final matches = current.where((line) => line.id == original.id);
        if (matches.isEmpty) {
          throw StateError(
              'No se pudo verificar el estado de todos los productos.');
        }
        final line = matches.first;
        if (line.canceladoPorAliado) {
          if (line.aliadoCancelacionMotivo?.trim() != _reason.text.trim()) {
            throw StateError(
                'Este producto ya fue cancelado con otro motivo. Vuelve al pedido para consultarlo.');
          }
          _done.add(line.id);
          continue;
        }
        if (!line.aliadoPuedeCancelarHastaFacturaProveedor) {
          throw StateError(line.tieneProveedorFacturaEmitida
              ? 'El proveedor ya adjuntó su factura para ${line.productName ?? 'este producto'}. No se puede cancelar.'
              : 'El estado de ${line.productName ?? 'este producto'} cambió. Vuelve al pedido para revisarlo.');
        }
        await widget.cancelLine(line, _reason.text.trim());
        _done.add(line.id);
      }
      // Reload is best effort only after all writes succeeded. Never show a failed
      // cancellation merely because the confirmation could not be refreshed.
      try {
        _saved = await widget.loadLines();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _confirmed = true;
        _saving = false;
      });
      if (_scroll.hasClients) _scroll.jumpTo(0);
    } catch (error) {
      if (!mounted) return;
      final raw = error.toString();
      final message = error is StateError
          ? error.message.toString()
          : raw.contains('factura')
              ? 'El proveedor ya adjuntó su factura. Revisa el pedido antes de continuar.'
              : raw.contains('propuesta de cantidad')
                  ? 'Responde primero a la propuesta de cantidad del proveedor.'
                  : 'No se pudo completar la cancelación. Reintenta para comprobar el estado y continuar.';
      setState(() {
        _saving = false;
        _error =
            '${_done.isEmpty ? '' : '${_done.length} de ${widget.lines.length} productos ya fueron cancelados. '}$message';
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scroll.hasClients) {
          _scroll.animateTo(0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut);
        }
      });
    }
  }

  List<TransactionRequestModel> get _cancelled => widget.lines
      .map((line) =>
          _saved?.where((saved) => saved.id == line.id).firstOrNull ?? line)
      .toList();

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final danger = Theme.of(context).colorScheme.error;
    final suppliers = _cancelled.map((line) => line.ownerId).toSet();
    final dates = _cancelled
        .map((line) => line.atRechazado)
        .whereType<DateTime>()
        .toList()
      ..sort();
    final desktop =
        MediaQuery.sizeOf(context).width >= AppBreakpoints.mobileMenu;
    final actions = Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (!_confirmed) ...[
                          OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(44, 44),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14))),
                              onPressed: _saving ? null : _back,
                              child: Text(_attempted
                                  ? 'Volver al pedido'
                                  : 'Conservar pedido')),
                          const SizedBox(height: 8),
                        ],
                        FilledButton(
                            style: FilledButton.styleFrom(
                                backgroundColor:
                                    _confirmed ? mobileOrderActionBlue : danger,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                                minimumSize: const Size(44, 48)),
                            onPressed: _saving
                                ? null
                                : _confirmed
                                    ? _back
                                    : _cancel,
                            child: Text(
                                _saving
                                    ? 'Cancelando…'
                                    : _confirmed
                                        ? 'Volver a pedidos'
                                        : _attempted
                                            ? 'Reintentar cancelación'
                                            : 'Confirmar cancelación',
                                textAlign: TextAlign.center)),
                        if (_confirmed && widget.onExplore != null)
                          TextButton(
                              onPressed: () {
                                _back();
                                widget.onExplore!();
                              },
                              child: const Text('Explorar catálogo')),
                      ]));
    final content = ListView(
                      controller: _scroll,
                      padding: const EdgeInsets.all(16),
                      children: [
                    if (_confirmed) ...[
                      Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Icon(Icons.cancel_outlined,
                              color: danger, size: 68)),
                      Text('Cancelación registrada',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 23,
                              fontWeight: FontWeight.w800,
                              color: theme.textPrimary)),
                      const SizedBox(height: 8),
                      const Text('El proveedor podrá ver el motivo.',
                          textAlign: TextAlign.center),
                      const SizedBox(height: 20),
                    ],
                    MobileOrderActionProducts(
                        lines: _confirmed ? _cancelled : widget.lines,
                        cancelled: _confirmed,
                        footer: _confirmed
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                    const Text('Motivo de la cancelación',
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 5),
                                    Text(_reason.text.trim()),
                                    if (dates.isNotEmpty) ...[
                                      const SizedBox(height: 12),
                                      Row(children: [
                                        Icon(Icons.calendar_today_outlined,
                                            size: 16,
                                            color: theme.textSecondary),
                                        const SizedBox(width: 7),
                                        Expanded(
                                            child: Text(
                                                mobileOrderActionDate(
                                                    dates.last),
                                                style: TextStyle(
                                                    fontSize: 12,
                                                    color:
                                                        theme.textSecondary))),
                                      ]),
                                    ],
                                  ])
                            : null),
                    if (!_confirmed)
                      const MobileOrderActionNotice(
                          'Puedes cancelar antes de que el proveedor adjunte su factura. Se cancelarán únicamente los productos que aparecen aquí.'),
                    if (_error != null)
                      MobileOrderActionNotice(_error!, error: true),
                    if (!_confirmed)
                      Form(
                          key: _form,
                          child: TextFormField(
                            key: const ValueKey('cancel-reason'),
                            controller: _reason,
                            minLines: 3,
                            maxLines: 5,
                            maxLength: 4000,
                            readOnly: _attempted,
                            enabled: !_saving,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: const InputDecoration(
                                labelText: 'Motivo de la cancelación',
                                helperText:
                                    'El motivo quedará registrado en el pedido.',
                                border: OutlineInputBorder()),
                            validator: (value) =>
                                (value?.trim().length ?? 0) < 3
                                    ? 'Escribe el motivo (mínimo 3 caracteres).'
                                    : null,
                          )),
                    if (_confirmed && widget.onRate != null)
                      for (final supplier in suppliers)
                        MobileOrderActionPanel(
                            child: ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(Icons.star_border,
                                    color: theme.warningFg),
                                title: const Text('Valorar el servicio'),
                                subtitle: Text(suppliers.length > 1
                                    ? _cancelled
                                            .firstWhere((line) =>
                                                line.ownerId == supplier)
                                            .ownerBusinessName ??
                                        'Proveedor'
                                    : 'Comparte tu experiencia'),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => widget.onRate!(
                                    context,
                                    _cancelled
                                        .where(
                                            (line) => line.ownerId == supplier)
                                        .toList(),
                                    _reason.text.trim()))),
                    if (desktop) ...[
                      const SizedBox(height: 12),
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 332),
                          child: actions,
                        ),
                      ),
                    ],
                  ]);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: theme.background,
        appBar: mobileOrderActionBar(
            context, _confirmed ? 'Pedido cancelado' : 'Cancelar pedido',
            onBack: _saving ? () {} : _back),
        body: SafeArea(
          top: false,
          child: desktop
              ? Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 802),
                    child: content,
                  ),
                )
              : DesktopWorkflow(body: content, actions: actions),
        ),
      ),
    );
  }
}
