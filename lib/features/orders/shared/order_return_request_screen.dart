import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/utils/app_date_format.dart';
import 'package:motolink_pro_app/core/utils/ves_amount_format.dart';
import 'order_message_attachment.dart';
import 'order_message_media.dart';
import 'order_message_pick.dart';
import 'order_motolink_thread_section.dart';
import 'order_return_rules.dart';
import 'orders_service.dart';
import 'transaction_request_model.dart';

abstract final class OrderPostventaKind {
  static const devolucion = 'devolucion';
  static const queja = 'queja';
  static const cambio = 'cambio';
  static const credito = 'credito';
  static const rechazo = 'rechazo';

  static String actionLabel(String kind) =>
      kind == queja ? 'Presentar una queja' : 'Solicitar devolución';

  static String viewLabel(String kind) =>
      kind == queja ? 'Ver queja' : 'Ver devolución';

  static String registeredTitle(String kind) =>
      kind == queja ? 'Queja registrada' : 'Solicitud enviada';
}

class _LocalEvidence {
  const _LocalEvidence({required this.attachment, required this.bytes});

  final OrderMessageAttachment attachment;
  final Uint8List bytes;
}

/// Registra una devolución o una queja y la deja anotada en el pedido.
class OrderReturnRequestScreen extends StatefulWidget {
  const OrderReturnRequestScreen({
    super.key,
    required this.request,
    required this.kind,
    required this.alreadyRegistered,
    required this.allowReplyAsAliado,
    required this.allowReplyAsImportador,
    this.mergedThreadRequestIds,
  });

  final TransactionRequestModel request;
  final String kind;
  final bool alreadyRegistered;
  final bool allowReplyAsAliado;
  final bool allowReplyAsImportador;
  final List<String>? mergedThreadRequestIds;

  @override
  State<OrderReturnRequestScreen> createState() =>
      _OrderReturnRequestScreenState();
}

class _OrderReturnRequestScreenState extends State<OrderReturnRequestScreen> {
  final _noteCtrl = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  bool _resolving = false;
  bool _registered = false;
  bool _changed = false;
  String? _savedBody;
  DateTime? _savedAt;
  String? _productName;
  int _affectedQty = 1;
  int? _savedQty;
  String? _resolution;
  String? _requestedResolution;
  String? _preference;
  String? _status;
  String? _rejectionNote;
  String? _casoId;
  String? _replacementStatus;
  double? _creditAmount;
  String? _formError;
  final List<_LocalEvidence> _evidence = [];
  List<OrderMessageAttachment> _savedEvidence = const [];

  bool get _isDevolucion => widget.kind == OrderPostventaKind.devolucion;

  bool get _canRegister => _isDevolucion
      ? widget.allowReplyAsAliado
      : widget.allowReplyAsAliado || widget.allowReplyAsImportador;

  bool get _canResolve =>
      _isDevolucion &&
      widget.allowReplyAsImportador &&
      _registered &&
      _resolution == null &&
      _status != 'rechazada';

  bool get _windowOpen => OrderReturnRules.isAvailable(
        status: widget.request.status,
        updatedAt: widget.request.updatedAt,
        deliveredAt: widget.request.atEntregado,
      );

  int get _lineQty =>
      widget.request.cantidad < 1 ? 1 : widget.request.cantidad;

  bool get _hasVideo => _evidence.any((item) => item.attachment.isVideo);

  @override
  void initState() {
    super.initState();
    _registered = widget.alreadyRegistered;
    _affectedQty = OrderReturnRules.clampAffectedQty(1, _lineQty);
    _load();
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final row = await OrdersService.fetchOrderPostventaCaso(
        transactionRequestId: widget.request.id,
        kind: widget.kind,
      );
      if (!mounted) return;
      String? replacement;
      final casoId = row?['id']?.toString();
      if (casoId != null && casoId.isNotEmpty) {
        try {
          final shipment = await OrdersService.fetchReplacementOrder(casoId);
          replacement = shipment?['status']?.toString();
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (row != null) {
          _registered = true;
          _casoId = casoId;
          _savedBody = row['body']?.toString();
          _savedAt = DateTime.tryParse(row['created_at']?.toString() ?? '')
              ?.toLocal();
          final name = row['product_name']?.toString().trim();
          if (name != null && name.isNotEmpty) _productName = name;
          final qty = int.tryParse(row['affected_qty']?.toString() ?? '');
          if (qty != null && qty > 0) _savedQty = qty;
          final resolution = row['resolution']?.toString().trim();
          if (resolution != null && resolution.isNotEmpty) {
            _resolution = resolution;
          }
          final requested = row['requested_resolution']?.toString().trim();
          if (requested != null && requested.isNotEmpty) {
            _requestedResolution = requested;
          }
          final status = row['status']?.toString().trim();
          if (status != null && status.isNotEmpty) _status = status;
          if (_status == 'rechazada') _resolution = OrderPostventaKind.rechazo;
          _rejectionNote = row['rejection_note']?.toString();
          final credit = row['credit_amount'];
          if (credit != null) {
            _creditAmount = double.tryParse(credit.toString());
          }
          _savedEvidence = parseOrderMessageAttachments(row['evidence']);
          _replacementStatus = replacement;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _addEvidence({
    required bool video,
    required bool camera,
  }) async {
    if (_saving) return;
    if (video && _evidence.isNotEmpty) {
      setState(() {
        _formError = _hasVideo
            ? 'Solo puede adjuntar un video.'
            : 'Quite las fotos si va a enviar un video.';
      });
      return;
    }
    if (!video && _hasVideo) {
      setState(() {
        _formError = 'Quite el video si va a enviar fotos.';
      });
      return;
    }
    if (!video &&
        _evidence.length >= OrderMessageLimits.maxImagesPerMessage) {
      setState(() => _formError = 'Puede adjuntar hasta 3 fotos.');
      return;
    }
    PreparedOrderAttachment? prepared;
    try {
      prepared = video
          ? await prepareOrderChatVideo(fromCamera: camera)
          : await prepareOrderChatImage(fromCamera: camera);
    } on OrderMessageLimitException catch (e) {
      if (!mounted) return;
      setState(() => _formError = e.message);
      return;
    } catch (_) {
      if (!mounted) return;
      setState(() => _formError = 'No se pudo obtener el archivo.');
      return;
    }
    if (prepared == null || !mounted) return;
    setState(() => _saving = true);
    try {
      final attachment = await OrdersService.uploadOrderReturnEvidence(
        transactionRequestId: widget.request.id,
        bytes: prepared.bytes,
        fileName: prepared.fileName,
        mime: prepared.mime,
        kind: prepared.kind,
      );
      if (!mounted) return;
      setState(() {
        _evidence.add(
          _LocalEvidence(attachment: attachment, bytes: prepared!.bytes),
        );
        _formError = null;
        _saving = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _formError = _friendlyError(e);
      });
    }
  }

  Future<void> _removeEvidence(int index) async {
    final item = _evidence[index];
    setState(() => _evidence.removeAt(index));
    try {
      await OrdersService.removeOrderReturnEvidence(item.attachment.path);
    } catch (_) {}
  }

  Future<void> _register() async {
    final note = _noteCtrl.text.trim();
    if (note.length < 3) {
      setState(() => _formError = 'Escriba qué ocurrió antes de enviarlo.');
      return;
    }
    if (_isDevolucion && _preference == null) {
      setState(() {
        _formError = 'Elija si prefiere crédito a favor o un cambio.';
      });
      return;
    }
    if (_isDevolucion && _evidence.isEmpty) {
      setState(() => _formError = 'Adjunte al menos una foto o un video.');
      return;
    }
    final qty = OrderReturnRules.clampAffectedQty(_affectedQty, _lineQty);
    setState(() {
      _saving = true;
      _formError = null;
    });
    try {
      final at = await OrdersService.registerOrderPostventaCaso(
        transactionRequestId: widget.request.id,
        kind: widget.kind,
        body: note,
        affectedQty: qty,
        requestedResolution: _isDevolucion ? _preference : null,
        evidence: _evidence.map((item) => item.attachment).toList(),
      );
      if (!mounted) return;
      setState(() {
        _registered = true;
        _changed = true;
        _savedBody = note;
        _savedAt = at;
        _savedQty = qty;
        _requestedResolution = _preference;
        _status = 'abierta';
        _savedEvidence = _evidence.map((item) => item.attachment).toList();
        _saving = false;
      });
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isDevolucion
                ? 'Solicitud enviada. El proveedor la verá en este pedido.'
                : 'Queja registrada. La otra parte la verá aquí y en el chat.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _formError = _friendlyError(e);
      });
    }
  }

  Future<void> _resolve(String resolution) async {
    String? note;
    if (resolution == OrderPostventaKind.rechazo) {
      note = await _askRejectionNote();
      if (note == null || !mounted) return;
    } else {
      final accepted = await _confirmResolution(resolution);
      if (accepted != true || !mounted) return;
    }
    setState(() {
      _resolving = true;
      _formError = null;
    });
    try {
      final result = await OrdersService.resolveOrderPostventaCaso(
        transactionRequestId: widget.request.id,
        resolution: resolution,
        note: note,
      );
      if (!mounted) return;
      setState(() {
        _resolution = result.resolution;
        _creditAmount = result.creditAmount;
        _status = resolution == OrderPostventaKind.rechazo
            ? 'rechazada'
            : resolution == OrderPostventaKind.credito
                ? 'aprobada_credito'
                : 'aprobada_cambio';
        _rejectionNote = note;
        if (resolution == OrderPostventaKind.cambio) {
          _replacementStatus = 'pendiente_retiro';
        }
        _changed = true;
        _resolving = false;
      });
      if (_casoId != null) await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_resolvedSnack(resolution, result.creditAmount))),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _resolving = false;
        _formError = _friendlyError(e);
      });
    }
  }

  Future<bool?> _confirmResolution(String resolution) {
    final credit = _previewCredit;
    final product = _displayProduct();
    final qty = _savedQty ?? _affectedQty;
    final isCredit = resolution == OrderPostventaKind.credito;
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isCredit ? 'Aprobar con crédito' : 'Aprobar el cambio'),
        content: Text(
          isCredit
              ? 'La tienda tendrá ${formatRefAmount(credit)} REF de saldo '
                  'para el próximo pedido con usted. Cubre ${_unitsLabel(qty)} '
                  'de $product.'
              : 'Se reserva ${_unitsLabel(qty)} de $product para enviarlo '
                  'sin costo. El pedido original sigue entregado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(isCredit ? 'Aprobar crédito' : 'Aprobar cambio'),
          ),
        ],
      ),
    );
  }

  Future<String?> _askRejectionNote() async {
    final ctrl = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('No aceptar la devolución'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          minLines: 3,
          maxLines: 5,
          decoration: const InputDecoration(
            labelText: 'Por qué no la acepta',
            hintText: 'La tienda verá esta nota.',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(ctrl.text.trim()),
            child: const Text('Enviar respuesta'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (note == null) return null;
    if (note.length < 3) {
      setState(() {
        _formError = 'Escriba por qué no acepta la devolución.';
      });
      return null;
    }
    return note;
  }

  Future<void> _advanceReplacement(String status) async {
    final casoId = _casoId;
    if (casoId == null || _resolving) return;
    setState(() {
      _resolving = true;
      _formError = null;
    });
    try {
      final next = await OrdersService.advanceReplacementOrder(
        casoId: casoId,
        status: status,
      );
      if (!mounted) return;
      setState(() {
        _replacementStatus = next;
        _changed = true;
        _resolving = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _resolving = false;
        _formError = _friendlyError(e);
      });
    }
  }

  String _resolvedSnack(String resolution, double? credit) {
    if (resolution == OrderPostventaKind.rechazo) {
      return 'La tienda ya puede ver por qué no se aceptó.';
    }
    if (resolution == OrderPostventaKind.credito) {
      return 'Saldo de ${formatRefAmount(credit ?? _previewCredit)} REF listo para el próximo pedido.';
    }
    return 'Cambio reservado. Queda pendiente de retiro.';
  }

  String _friendlyError(Object error) {
    final raw = error.toString();
    if (raw.contains('plazo de 7 días')) return OrderReturnRules.closedHint;
    if (raw.contains('ya quedó registrado')) {
      return 'Eso ya quedó registrado en este pedido.';
    }
    if (raw.contains('ya tiene una respuesta')) {
      return 'Esta devolución ya tiene una respuesta.';
    }
    if (raw.contains('no puede superar')) {
      return 'La cantidad no puede superar las unidades de este producto.';
    }
    if (raw.contains('Solo la tienda')) {
      return 'Solo la tienda puede solicitar la devolución.';
    }
    if (raw.contains('foto o un video') || raw.contains('evidencia')) {
      return 'Adjunte hasta 3 fotos o 1 video.';
    }
    if (raw.contains('crédito a favor o cambio') || raw.contains('Elija crédito')) {
      return 'Elija si prefiere crédito a favor o un cambio.';
    }
    if (raw.contains('no tiene un monto')) {
      return 'Este producto no tiene un monto para dejar como crédito.';
    }
    if (raw.contains('stock libre') || raw.contains('Stock insuficiente')) {
      return 'No hay stock libre para reservar el cambio.';
    }
    if (raw.contains('por qué no acepta')) {
      return 'Escriba por qué no acepta la devolución.';
    }
    if (error is OrderMessageLimitException) return error.message;
    return 'No se pudo completar. Revise su conexión e intente de nuevo.';
  }

  String _displayProduct() {
    final saved = _productName?.trim();
    if (saved != null && saved.isNotEmpty) return saved;
    final live = widget.request.productName?.trim();
    if (live != null && live.isNotEmpty) return live;
    return 'Producto del pedido';
  }

  String _unitsLabel(int qty) => qty == 1 ? '1 unidad' : '$qty unidades';

  double get _previewCredit => OrderReturnRules.creditAmount(
        unitPrice: widget.request.precioUnitarioAliado,
        lineTotal: widget.request.precioTotal,
        lineQty: _lineQty,
        affectedQty: _savedQty ?? _affectedQty,
      );

  void _close() => Navigator.of(context).pop(_changed);

  @override
  Widget build(BuildContext context) {
    final until = OrderReturnRules.availableUntil(
      deliveredAt: widget.request.atEntregado,
      updatedAt: widget.request.updatedAt,
    );
    final untilLabel =
        until == null ? null : formatEsShortDateTime(until.toLocal());
    final title = _registered
        ? OrderPostventaKind.viewLabel(widget.kind)
        : OrderPostventaKind.actionLabel(widget.kind);
    final sku = widget.request.productSku?.trim();
    final showStepper =
        !_registered && _canRegister && _windowOpen && _lineQty > 1;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _close();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(title),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _close,
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  Text(
                    _displayProduct(),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (sku != null && sku.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      'SKU $sku',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    _registered
                        ? 'Quedó en este pedido. El estado sigue siendo entregado.'
                        : _windowOpen
                            ? 'Puede enviarlo hasta ${untilLabel ?? 'dentro de 7 días'}.'
                            : OrderReturnRules.closedHint,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_registered) ...[
                    _SavedNote(
                      product: _displayProduct(),
                      qtyLabel: _unitsLabel(_savedQty ?? _lineQty),
                      body: _savedBody,
                      at: _savedAt,
                      preference: _requestedResolution,
                    ),
                    if (_savedEvidence.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      OrderMessageMediaStrip(attachments: _savedEvidence),
                    ],
                    if (_resolution != null || _status == 'rechazada') ...[
                      const SizedBox(height: 8),
                      _ResolutionNote(
                        resolution: _resolution ?? OrderPostventaKind.rechazo,
                        creditAmount: _creditAmount ?? _previewCredit,
                        product: _displayProduct(),
                        qtyLabel: _unitsLabel(_savedQty ?? _lineQty),
                        rejectionNote: _rejectionNote,
                        replacementStatus: _replacementStatus,
                      ),
                    ],
                    if (_replacementStatus != null &&
                        widget.allowReplyAsImportador &&
                        _replacementStatus != 'entregado') ...[
                      const SizedBox(height: 8),
                      _advanceButton(),
                    ],
                    if (_canResolve) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Su respuesta',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _requestedResolution == null
                            ? 'Apruebe un crédito, apruebe el cambio o explíquele a la tienda por qué no lo acepta.'
                            : 'La tienda prefiere ${OrderReturnRules.preferenceLabel(_requestedResolution).toLowerCase()}. Puede aceptar esa vía u otra.',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.35,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _decisionButton(
                        resolution: OrderPostventaKind.credito,
                        icon: Icons.account_balance_wallet_outlined,
                        label:
                            'Aprobar crédito · ${formatRefAmount(_previewCredit)} REF',
                      ),
                      const SizedBox(height: 8),
                      _decisionButton(
                        resolution: OrderPostventaKind.cambio,
                        icon: Icons.swap_horiz,
                        label: 'Aprobar cambio de producto',
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _resolving
                            ? null
                            : () => _resolve(OrderPostventaKind.rechazo),
                        icon: const Icon(Icons.close, size: 18),
                        label: const Text('No aceptar'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textPrimary,
                          side: BorderSide(color: AppColors.borderSubtle),
                          minimumSize: const Size.fromHeight(44),
                        ),
                      ),
                    ],
                  ] else if (_canRegister && _windowOpen) ...[
                    Text(
                      'Unidades en el pedido: $_lineQty',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (showStepper)
                      _QtyStepper(
                        value: _affectedQty,
                        max: _lineQty,
                        enabled: !_saving,
                        onChanged: (value) =>
                            setState(() => _affectedQty = value),
                      )
                    else
                      Text(
                        'Se registrará ${_unitsLabel(_lineQty)}.',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _noteCtrl,
                      enabled: !_saving,
                      minLines: 3,
                      maxLines: 5,
                      decoration: InputDecoration(
                        labelText: _isDevolucion
                            ? 'Qué inconveniente tuvo'
                            : 'Qué ocurrió',
                        hintText: 'Escríbalo con claridad.',
                        filled: true,
                        fillColor: AppColors.fieldFill,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    if (_isDevolucion) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Cómo prefiere resolverlo',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'El proveedor puede aceptar esta opción u otra.',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.35,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _PreferenceCard(
                        selected: _preference == OrderPostventaKind.credito,
                        icon: Icons.account_balance_wallet_outlined,
                        title: 'Crédito a favor',
                        body:
                            'Saldo para el próximo pedido con este proveedor. '
                            'Hoy serían ${formatRefAmount(_previewCredit)} REF.',
                        onTap: _saving
                            ? null
                            : () => setState(
                                  () => _preference = OrderPostventaKind.credito,
                                ),
                      ),
                      const SizedBox(height: 8),
                      _PreferenceCard(
                        selected: _preference == OrderPostventaKind.cambio,
                        icon: Icons.swap_horiz,
                        title: 'Cambio de producto',
                        body:
                            'Que le envíen ${_unitsLabel(_affectedQty)} de reemplazo, sin costo.',
                        onTap: _saving
                            ? null
                            : () => setState(
                                  () => _preference = OrderPostventaKind.cambio,
                                ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Evidencia',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Hasta 3 fotos o 1 video. Es obligatoria.',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.35,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      OrderMessageAttachButtons(
                        enabled: !_saving,
                        onPhotoCamera: () =>
                            _addEvidence(video: false, camera: true),
                        onPhotoGallery: () =>
                            _addEvidence(video: false, camera: false),
                        onVideoCamera: () =>
                            _addEvidence(video: true, camera: true),
                        onVideoGallery: () =>
                            _addEvidence(video: true, camera: false),
                      ),
                      if (_evidence.isNotEmpty) _evidenceStrip(),
                    ],
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: _saving ? null : _register,
                      child: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(OrderPostventaKind.actionLabel(widget.kind)),
                    ),
                  ],
                  if (_formError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _formError!,
                      style: TextStyle(
                        color: Colors.red.shade800,
                        fontSize: 13,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Text(
                    'Mensajes de este pedido',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 320,
                    child: OrderMotolinkThreadSection(
                      transactionRequestId: widget.request.id,
                      allowReplyAsAliado:
                          widget.allowReplyAsAliado && _windowOpen,
                      allowReplyAsImportador:
                          widget.allowReplyAsImportador && _windowOpen,
                      allowReplyAsAdmin: false,
                      deliveryGrace: _windowOpen,
                      suppressBuiltinTitle: true,
                      suppressInlineHelp: true,
                      expandMessages: true,
                      emptyHint: 'Aquí puede seguir la conversación del pedido.',
                      mergedThreadRequestIds: widget.mergedThreadRequestIds,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _decisionButton({
    required String resolution,
    required IconData icon,
    required String label,
  }) {
    final preferred = _requestedResolution == resolution;
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 8),
        Text(label, textAlign: TextAlign.center),
      ],
    );
    final onPressed = _resolving ? null : () => _resolve(resolution);
    if (preferred) {
      return FilledButton(onPressed: onPressed, child: child);
    }
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.brand,
        side: const BorderSide(color: AppColors.brand),
        minimumSize: const Size.fromHeight(44),
      ),
      child: child,
    );
  }

  Widget _advanceButton() {
    final next = _replacementStatus == 'pendiente_retiro'
        ? 'en_transito'
        : 'entregado';
    final label = next == 'en_transito'
        ? 'Marcar en tránsito'
        : 'Marcar como entregado';
    return FilledButton.icon(
      onPressed: _resolving ? null : () => _advanceReplacement(next),
      icon: Icon(
        next == 'en_transito' ? Icons.local_shipping_outlined : Icons.done_all,
        size: 18,
      ),
      label: Text(label),
    );
  }

  Widget _evidenceStrip() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SizedBox(
        height: 72,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _evidence.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final item = _evidence[index];
            return Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 72,
                    height: 72,
                    child: item.attachment.isVideo
                        ? ColoredBox(
                            color: AppColors.brandBlueContainer,
                            child: const Icon(
                              Icons.videocam_outlined,
                              color: AppColors.brand,
                            ),
                          )
                        : Image.memory(item.bytes, fit: BoxFit.cover),
                  ),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: _saving ? null : () => _removeEvidence(index),
                    icon: const Icon(Icons.close, size: 16),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.card,
                      foregroundColor: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PreferenceCard extends StatelessWidget {
  const _PreferenceCard({
    required this.selected,
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final String body;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.brandBlueContainer : AppColors.card,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.brand : AppColors.borderSubtle,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: AppColors.brand),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      body,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.35,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                color: selected ? AppColors.brand : AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QtyStepper extends StatelessWidget {
  const _QtyStepper({
    required this.value,
    required this.max,
    required this.enabled,
    required this.onChanged,
  });

  final int value;
  final int max;
  final bool enabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            value == 1
                ? '1 unidad con inconveniente'
                : '$value unidades con inconveniente',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        IconButton(
          onPressed: !enabled || value <= 1 ? null : () => onChanged(value - 1),
          icon: const Icon(Icons.remove_circle_outline),
          tooltip: 'Menos unidades',
        ),
        IconButton(
          onPressed: !enabled || value >= max ? null : () => onChanged(value + 1),
          icon: const Icon(Icons.add_circle_outline),
          tooltip: 'Más unidades',
        ),
      ],
    );
  }
}

class _SavedNote extends StatelessWidget {
  const _SavedNote({
    required this.product,
    required this.qtyLabel,
    required this.body,
    required this.at,
    this.preference,
  });

  final String product;
  final String qtyLabel;
  final String? body;
  final DateTime? at;
  final String? preference;

  @override
  Widget build(BuildContext context) {
    final when = at == null ? null : formatEsShortDateTime(at!.toLocal());
    final pref = OrderReturnRules.preferenceLabel(preference);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.brandBlueContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              when == null
                  ? 'Solicitud en este pedido.'
                  : 'Enviada el $when.',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            ),
            const SizedBox(height: 6),
            Text(
              '$product · $qtyLabel',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            if (pref.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Preferencia: $pref',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ],
            if (body != null && body!.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                body!.trim(),
                style: const TextStyle(fontSize: 13, height: 1.35),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ResolutionNote extends StatelessWidget {
  const _ResolutionNote({
    required this.resolution,
    required this.creditAmount,
    required this.product,
    required this.qtyLabel,
    this.rejectionNote,
    this.replacementStatus,
  });

  final String resolution;
  final double creditAmount;
  final String product;
  final String qtyLabel;
  final String? rejectionNote;
  final String? replacementStatus;

  @override
  Widget build(BuildContext context) {
    final String text;
    if (resolution == OrderPostventaKind.credito) {
      text =
          'Crédito de ${formatRefAmount(creditAmount)} REF a favor de la tienda para el próximo pedido con este proveedor. $product · $qtyLabel.';
    } else if (resolution == OrderPostventaKind.cambio) {
      final step = OrderReturnRules.replacementStatusLabel(replacementStatus);
      text = step.isEmpty
          ? 'Cambio de producto sin costo. $product · $qtyLabel.'
          : 'Cambio de producto sin costo. $step. $product · $qtyLabel.';
    } else {
      final note = rejectionNote?.trim();
      text = (note == null || note.isEmpty)
          ? 'El proveedor no aceptó la devolución.'
          : 'El proveedor no aceptó la devolución. $note';
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          text,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            height: 1.35,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
