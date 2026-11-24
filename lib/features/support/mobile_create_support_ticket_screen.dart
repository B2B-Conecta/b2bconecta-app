import 'package:flutter/material.dart';
import '../../app/theme/b2b_theme_extension.dart';
import '../../core/data/supabase_service.dart';
import 'mobile_support_widgets.dart';
import 'support_ticket_category.dart';

class MobileCreateSupportTicketScreen extends StatefulWidget {
  const MobileCreateSupportTicketScreen(
      {super.key, this.relatedTransactionRequestId});
  final String? relatedTransactionRequestId;
  @override
  State<MobileCreateSupportTicketScreen> createState() =>
      _MobileCreateSupportTicketScreenState();
}

class _MobileCreateSupportTicketScreenState
    extends State<MobileCreateSupportTicketScreen> {
  final _form = GlobalKey<FormState>();
  final _subject = TextEditingController();
  final _body = TextEditingController();
  String _category = SupportTicketCategory.plataforma;
  bool _saving = false;
  bool _allowPop = false;
  bool _limitReached = false;
  String? _createdId;
  String? _error;

  bool get _hasDraft =>
      _subject.text.trim().isNotEmpty || _body.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _subject.addListener(_draftChanged);
    _body.addListener(_draftChanged);
  }

  void _draftChanged() => setState(() {});

  @override
  void dispose() {
    _subject.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _cancel() async {
    if (_saving) return;
    if (_hasDraft && _createdId == null) {
      final discard = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
                  title: const Text('¿Descartar el reclamo?'),
                  content: const Text(
                      'Todavía no lo has enviado. Si sales, perderás lo que escribiste.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Seguir escribiendo')),
                    FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Descartar')),
                  ]));
      if (discard != true || !mounted) return;
    }
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  Future<void> _save() async {
    if (_saving || _limitReached) return;
    if (_createdId == null && !(_form.currentState?.validate() ?? false)) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (_createdId == null) {
        final id = await SupabaseService.createSupportTicket(
            subject: _subject.text.trim(),
            category: _category,
            body: _body.text.trim(),
            relatedTransactionRequestId: widget.relatedTransactionRequestId);
        if (id.trim().isEmpty) throw StateError('Missing ticket identifier');
        _createdId = id;
      }
      final ticket = await SupabaseService.fetchSupportTicketById(_createdId!);
      if (ticket == null) throw StateError('Ticket not available');
      if (!mounted) return;
      setState(() => _allowPop = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context, ticket);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _limitReached = supportLimitReached(error);
        _error = _createdId != null
            ? 'Tu reclamo ya se registró. No necesitas enviarlo de nuevo. Reintenta abrir la conversación o vuelve al listado.'
            : supportFailureMessage(error);
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _required(String? value, String name) {
    if ((value?.trim().length ?? 0) < 3) {
      return '$name debe tener al menos 3 caracteres.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final sent = _createdId != null;
    final linked = widget.relatedTransactionRequestId?.isNotEmpty == true;
    return PopScope(
      canPop: !_saving && (_allowPop || !_hasDraft || sent),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _cancel();
      },
      child: Scaffold(
        backgroundColor: theme.background,
        appBar: mobileSupportAppBar(context, 'Nuevo reclamo', onBack: _cancel),
        body: SafeArea(
            top: false,
            bottom: false,
            child: Form(
              key: _form,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: ListView(padding: const EdgeInsets.all(16), children: [
                const Text('Cuéntanos qué ocurrió',
                    style:
                        TextStyle(fontSize: 23, fontWeight: FontWeight.w800)),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                    value: _category,
                    isExpanded: true,
                    decoration: const InputDecoration(
                        labelText: 'Categoría', border: OutlineInputBorder()),
                    items: [
                      for (final category in SupportTicketCategory.all)
                        DropdownMenuItem(
                            value: category,
                            child: Text(SupportTicketCategory.labelEs(category),
                                overflow: TextOverflow.ellipsis))
                    ],
                    onChanged: _saving || sent
                        ? null
                        : (value) {
                            if (value != null) {
                              setState(() => _category = value);
                            }
                          }),
                const SizedBox(height: 16),
                TextFormField(
                    key: const ValueKey('support-subject'),
                    controller: _subject,
                    enabled: !_saving && !sent,
                    maxLength: 160,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.next,
                    validator: (value) => _required(value, 'El asunto'),
                    decoration: const InputDecoration(
                        labelText: 'Asunto',
                        hintText: 'Resume el problema',
                        border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextFormField(
                    key: const ValueKey('support-body'),
                    controller: _body,
                    enabled: !_saving && !sent,
                    minLines: 4,
                    maxLines: 8,
                    maxLength: 4000,
                    textCapitalization: TextCapitalization.sentences,
                    validator: (value) => _required(value, 'La descripción'),
                    decoration: const InputDecoration(
                        labelText: 'Describe el problema',
                        hintText: '¿Qué intentabas hacer y qué ocurrió?',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder())),
                const SizedBox(height: 4),
                if (linked) ...[
                  const SupportInfoNotice(
                      'Este reclamo quedará vinculado al pedido desde el que abriste soporte.'),
                  const SizedBox(height: 12),
                ] else
                  const Text(
                      'Si se relaciona con un pedido, indica su referencia en la descripción.'),
                const SizedBox(height: 16),
                const SupportInfoNotice(
                    'Puedes tener hasta 3 reclamos abiertos. Los casos en revisión también cuentan.'),
                const SizedBox(height: 12),
                if (_error != null) SupportInfoNotice(_error!, error: true),
              ]),
            )),
        bottomNavigationBar: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FilledButton(
                        onPressed: _saving || _limitReached ? null : _save,
                        style: FilledButton.styleFrom(
                            backgroundColor: supportMobileBlue,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(0, 48),
                            padding: const EdgeInsets.all(12)),
                        child: Text(_saving
                            ? 'Un momento…'
                            : sent
                                ? 'Abrir conversación'
                                : 'Enviar reclamo')),
                    TextButton(
                        onPressed: _saving ? null : _cancel,
                        child: Text(sent || _limitReached
                            ? 'Volver a reclamos'
                            : 'Cancelar')),
                  ]),
            )),
      ),
    );
  }
}
