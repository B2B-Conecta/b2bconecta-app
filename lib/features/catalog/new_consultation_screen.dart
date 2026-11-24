import 'package:flutter/material.dart';
import '../../app/theme/app_theme.dart';
import '../../core/widgets/lucide_icon.dart';
import '../orders/shared/order_message_pick.dart';
import 'catalog_filters.dart';
import 'consultation_media.dart';
import 'importer_catalog_logo.dart';
import 'store_supplier_chat.dart';

/// Compose first; selecting a supplier does not create or send anything.
class NewConsultationScreen extends StatefulWidget {
  const NewConsultationScreen(
      {super.key, required this.suppliers, this.sendOverride, this.pickPhoto});
  final List<ImporterOption> suppliers;
  final Future<String> Function(
      ImporterOption supplier,
      String text,
      String model,
      PreparedOrderAttachment? photo,
      String messageId)? sendOverride;
  final Future<PreparedOrderAttachment?> Function(bool camera)? pickPhoto;
  @override
  State<NewConsultationScreen> createState() => _NewConsultationScreenState();
}

class _NewConsultationScreenState extends State<NewConsultationScreen> {
  final _text = TextEditingController(),
      _model = TextEditingController(),
      _search = TextEditingController();
  final _form = GlobalKey<FormState>();
  PreparedOrderAttachment? _photo;
  ImporterOption? _supplier;
  bool _choosing = false, _sending = false, _picking = false;
  String? _error;
  bool _allowPop = false;
  bool _leaving = false;
  String _messageId = newConsultationMessageId();
  @override
  void initState() {
    super.initState();
    _text.addListener(_edited);
    _model.addListener(_edited);
  }

  void _edited() {
    _messageId = newConsultationMessageId();
  }

  @override
  void dispose() {
    _text.dispose();
    _model.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _pick(bool camera) async {
    if (_picking || _sending) return;
    setState(() => _picking = true);
    try {
      final photo = await (widget.pickPhoto?.call(camera) ??
          prepareOrderChatImage(fromCamera: camera));
      if (mounted && photo != null) {
        setState(() {
          _photo = photo;
          _messageId = newConsultationMessageId();
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'No se pudo adjuntar la foto. Usa JPG, PNG o WEBP de hasta 8 MB.');
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _send() async {
    final supplier = _supplier;
    if (supplier == null || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final String thread;
      if (widget.sendOverride != null) {
        thread = await widget.sendOverride!(supplier, _text.text.trim(),
            _model.text.trim(), _photo, _messageId);
      } else {
        thread = await StoreSupplierChatService.openOrCreate(
            importadorId: supplier.id);
        await StoreSupplierChatService.sendConsultation(
            threadId: thread,
            messageId: _messageId,
            body: _text.text,
            model: _model.text,
            photo: _photo);
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
          builder: (_) => StoreSupplierChatScreen(threadId: thread)));
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'No se pudo enviar la consulta. Conservamos el texto y la foto para que puedas reintentar.');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<bool> _leave() async {
    if (_choosing) {
      setState(() => _choosing = false);
      return false;
    }
    if (_text.text.trim().isEmpty &&
        _model.text.trim().isEmpty &&
        _photo == null) return true;
    return await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
                    title: const Text('¿Descartar la consulta?'),
                    content: const Text(
                        'El texto y la foto todavía no se han enviado.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Seguir editando')),
                      TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Descartar'))
                    ])) ??
        false;
  }

  Future<void> _back() async {
    if (_sending || _leaving) return;
    _leaving = true;
    try {
      if (await _leave() && mounted) {
        setState(() => _allowPop = true);
        await WidgetsBinding.instance.endOfFrame;
        if (mounted) Navigator.pop(context);
      }
    } finally {
      _leaving = false;
    }
  }

  Widget _summary() => Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: AppColors.surfaceTinted,
          borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        if (_photo != null) ...[
          ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.memory(_photo!.bytes,
                  width: 64, height: 64, fit: BoxFit.cover)),
          const SizedBox(width: 12)
        ],
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_text.text.trim(),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          if (_model.text.trim().isNotEmpty)
            Text(_model.text.trim(),
                maxLines: 2, overflow: TextOverflow.ellipsis)
        ])),
        TextButton(
            onPressed:
                _sending ? null : () => setState(() => _choosing = false),
            child: const Text('Editar'))
      ]));
  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final suppliers = widget.suppliers
        .where((s) => '${s.businessName} ${s.ubicacionLine}'
            .toLowerCase()
            .contains(query))
        .toList();
    return PopScope<Object?>(
        canPop: _allowPop && !_sending,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) _back();
        },
        child: Scaffold(
            backgroundColor: AppColors.background,
            appBar: consultationAppBar(
                title: _choosing ? 'Elegir proveedor' : 'Nueva consulta',
                onBack: _back),
            body: SafeArea(
                top: false,
                child: Center(
                    child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 720),
                        child: Form(
                            key: _form,
                            child: Column(children: [
                              Expanded(
                                  child: ListView(
                                      padding: const EdgeInsets.all(16),
                                      children: [
                                    if (!_choosing) ...[
                                      Text('¿Qué repuesto buscas?',
                                          style: Theme.of(context)
                                              .textTheme
                                              .headlineSmall
                                              ?.copyWith(
                                                  fontWeight: FontWeight.w700)),
                                      const SizedBox(height: 8),
                                      const Text(
                                          'Escribe el nombre, código o adjunta una foto de referencia.'),
                                      const SizedBox(height: 20),
                                      TextFormField(
                                          controller: _text,
                                          enabled: !_sending,
                                          maxLength: 4000,
                                          minLines: 5,
                                          maxLines: 8,
                                          decoration: const InputDecoration(
                                              labelText: 'Tu consulta',
                                              hintText:
                                                  'Hola, ¿tienen pastillas de freno para una moto 150 cc?',
                                              alignLabelWithHint: true),
                                          validator: (value) => value
                                                      ?.trim()
                                                      .isEmpty !=
                                                  false
                                              ? 'Escribe qué repuesto necesitas.'
                                              : null),
                                      Wrap(spacing: 8, children: [
                                        OutlinedButton.icon(
                                            onPressed: _picking
                                                ? null
                                                : () => _pick(false),
                                            icon: const Icon(Icons.attach_file),
                                            label: const Text('Agregar foto')),
                                        IconButton(
                                            tooltip: 'Tomar foto',
                                            onPressed: _picking
                                                ? null
                                                : () => _pick(true),
                                            icon: const Icon(
                                                Icons.photo_camera_outlined))
                                      ]),
                                      if (_picking)
                                        const LinearProgressIndicator(),
                                      if (_photo != null)
                                        Padding(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 12),
                                            child: Row(children: [
                                              ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  child: Image.memory(
                                                      _photo!.bytes,
                                                      width: 96,
                                                      height: 96,
                                                      fit: BoxFit.cover)),
                                              IconButton(
                                                  tooltip: 'Quitar foto',
                                                  onPressed: () => setState(() {
                                                        _photo = null;
                                                        _messageId =
                                                            newConsultationMessageId();
                                                      }),
                                                  icon:
                                                      const Icon(Icons.cancel))
                                            ])),
                                      const SizedBox(height: 16),
                                      TextFormField(
                                          controller: _model,
                                          maxLength: 160,
                                          decoration: const InputDecoration(
                                              labelText:
                                                  'Código o modelo (opcional)',
                                              hintText:
                                                  'Marca, modelo, cilindrada o año')),
                                    ] else ...[
                                      _summary(),
                                      const SizedBox(height: 16),
                                      TextField(
                                          controller: _search,
                                          enabled: !_sending,
                                          onChanged: (_) => setState(() {}),
                                          decoration: const InputDecoration(
                                              prefixIcon: Icon(Icons.search),
                                              hintText: 'Buscar proveedor…')),
                                      const SizedBox(height: 16),
                                      const Text(
                                          'Selecciona a quién consultar.'),
                                      const SizedBox(height: 8),
                                      if (suppliers.isEmpty)
                                        Padding(
                                            padding: const EdgeInsets.all(20),
                                            child: Text(widget.suppliers.isEmpty
                                                ? 'No hay proveedores disponibles para consultar.'
                                                : 'No encontramos proveedores con esa búsqueda.')),
                                      for (final supplier in suppliers)
                                        Padding(
                                            padding: const EdgeInsets.only(
                                                bottom: 8),
                                            child: Material(
                                                color: _supplier?.id ==
                                                        supplier.id
                                                    ? AppColors
                                                        .brandBlueContainer
                                                    : AppColors.card,
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                                child: RadioListTile<String>(
                                                    value: supplier.id,
                                                    groupValue: _supplier?.id,
                                                    controlAffinity:
                                                        ListTileControlAffinity
                                                            .trailing,
                                                    secondary:
                                                        ImporterCatalogLogo(
                                                            storagePath: supplier
                                                                .logoStoragePath,
                                                            size: 44),
                                                    title: Text(
                                                        supplier.businessName,
                                                        style: const TextStyle(
                                                            fontWeight:
                                                                FontWeight
                                                                    .w700)),
                                                    subtitle: Text(
                                                        supplier.ubicacionLine),
                                                    onChanged: _sending
                                                        ? null
                                                        : (_) => setState(() {
                                                              if (_supplier
                                                                      ?.id !=
                                                                  supplier.id) {
                                                                _messageId =
                                                                    newConsultationMessageId();
                                                              }
                                                              _supplier =
                                                                  supplier;
                                                              _error = null;
                                                            })))),
                                    ],
                                  ])),
                              Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(16, 8, 16, 16),
                                  child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        if (_error != null)
                                          Padding(
                                              padding: const EdgeInsets.only(
                                                  bottom: 12),
                                              child: Text(_error!,
                                                  style: TextStyle(
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .error))),
                                        Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                                color: AppColors
                                                    .brandBlueContainer,
                                                borderRadius:
                                                    BorderRadius.circular(12)),
                                            child: Row(children: [
                                              const LucideIcon(
                                                  LucideGlyph.circleAlert,
                                                  size: 20),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                  child: Text(!_choosing
                                                      ? 'La consulta no genera un pedido.'
                                                      : _supplier == null
                                                          ? 'Elige un proveedor para enviar la consulta.'
                                                          : 'Se enviará solo a ${_supplier!.businessName}.'))
                                            ])),
                                        const SizedBox(height: 16),
                                        FilledButton.icon(
                                            onPressed: _sending || _picking
                                                ? null
                                                : _choosing
                                                    ? (_supplier == null
                                                        ? null
                                                        : _send)
                                                    : () {
                                                        if (!_form.currentState!
                                                            .validate()) return;
                                                        if (_text.text
                                                            .trim()
                                                            .isEmpty) {
                                                          setState(() => _error =
                                                              'Escribe qué repuesto necesitas.');
                                                          return;
                                                        }
                                                        FocusScope.of(context)
                                                            .unfocus();
                                                        setState(() {
                                                          _error = null;
                                                          _choosing = true;
                                                        });
                                                      },
                                            icon: _sending
                                                ? const SizedBox(
                                                    width: 18,
                                                    height: 18,
                                                    child:
                                                        CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                            color:
                                                                Colors.white))
                                                : Icon(_choosing
                                                    ? Icons.send_rounded
                                                    : Icons.arrow_forward),
                                            label: Text(_sending
                                                ? 'Enviando…'
                                                : _choosing
                                                    ? 'Enviar consulta'
                                                    : 'Elegir proveedor'),
                                            style: FilledButton.styleFrom(
                                                minimumSize:
                                                    const Size(0, 52))),
                                      ])),
                            ])))))));
  }
}
