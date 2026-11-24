import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../app/theme/b2b_theme_extension.dart';
import '../../../core/layout/app_breakpoints.dart';
import '../../../core/utils/app_date_format.dart';
import 'mobile_order_action_widgets.dart';

import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/features/inventory/product_images.dart';
import 'order_list_colors.dart';
import 'order_message_attachment.dart';
import 'order_message_media.dart';
import 'order_message_pick.dart';
import 'order_product_thumb.dart';
import 'order_return_request_screen.dart';
import 'order_return_rules.dart';
import 'orders_service.dart';
import 'transaction_request_model.dart';

class _DraftEvidence {
  const _DraftEvidence({
    required this.bytes,
    required this.fileName,
    required this.mime,
    required this.kind,
  });

  final Uint8List bytes;
  final String fileName;
  final String mime;
  final String kind;

  bool get isVideo => kind == 'video';
}

class _SavedReport {
  const _SavedReport({
    required this.line,
    required this.body,
    required this.qty,
    required this.preference,
    required this.evidence,
  });

  final TransactionRequestModel line;
  final String body;
  final int qty;
  final String preference;
  final List<OrderMessageAttachment> evidence;
}

/// Reporte único del pedido: productos, cantidad, motivo, evidencia y preferencia.
class OrderIssueReportScreen extends StatefulWidget {
  const OrderIssueReportScreen({
    super.key,
    required this.lines,
    this.viewOnly = false,
    this.onSubmitted,
    this.loadReport,
    this.uploadEvidence,
    this.registerReport,
    this.pickEvidence,
  });

  final List<TransactionRequestModel> lines;
  final bool viewOnly;
  final Future<void> Function(BuildContext context, List<String> reportedIds)?
      onSubmitted;
  final Future<Map<String, dynamic>?> Function(String id)? loadReport;
  final Future<OrderMessageAttachment> Function(
      String id, PreparedOrderAttachment item)? uploadEvidence;
  final Future<void> Function(String id, String note, int qty,
      List<OrderMessageAttachment> evidence)? registerReport;
  final Future<PreparedOrderAttachment?> Function(bool video, bool camera)?
      pickEvidence;

  @override
  State<OrderIssueReportScreen> createState() => _OrderIssueReportScreenState();
}

class _OrderIssueReportScreenState extends State<OrderIssueReportScreen> {
  final _noteCtrl = TextEditingController();
  final _scroll = ScrollController();
  final _selected = <String>{};
  final _qty = <String, int>{};
  final _evidence = <_DraftEvidence>[];
  bool _saving = false;
  bool _pickingEvidence = false;
  bool _loadingSaved = false;
  bool _changed = false;
  bool _attempted = false, _submitted = false, _openingChat = false;
  final _sentIds = <String>{};
  final _uploadedById = <String, List<OrderMessageAttachment>>{};
  List<TransactionRequestModel>? _attemptLines;
  String? _formError;
  List<_SavedReport> _saved = const [];

  bool get _hasVideo => _evidence.any((item) => item.isVideo);
  bool get _mobile =>
      MediaQuery.sizeOf(context).width < AppBreakpoints.mobileMenu;
  bool get _editable =>
      !_saving && !_pickingEvidence && (!_mobile || !_attempted);

  void _revealNotice() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scroll.hasClients) {
        _scroll.animateTo(0,
            duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  void _showError(String message) {
    setState(() => _formError = message);
    if (_mobile) _revealNotice();
  }

  Future<Map<String, dynamic>?> _fetchReport(String id) =>
      widget.loadReport?.call(id) ??
      OrdersService.fetchOrderPostventaCaso(
          transactionRequestId: id, kind: OrderPostventaKind.devolucion);

  List<TransactionRequestModel> get _eligible => widget.lines.where((line) {
        if (line.postventaDevolucionAt != null) return false;
        return OrderReturnRules.isAvailable(
          status: line.status,
          updatedAt: line.updatedAt,
          deliveredAt: line.atEntregado,
        );
      }).toList();

  @override
  void initState() {
    super.initState();
    final eligible = _eligible;
    if (eligible.length == 1) {
      _selected.add(eligible.first.id);
      _qty[eligible.first.id] = 1;
    }
    _loadSaved();
    _noteCtrl.addListener(_onNote);
  }

  void _onNote() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _noteCtrl.removeListener(_onNote);
    _noteCtrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadSaved() async {
    final reported =
        widget.lines.where((line) => line.postventaDevolucionAt != null);
    if (reported.isEmpty) return;
    setState(() {
      _loadingSaved = true;
      _formError = null;
    });
    final saved = <_SavedReport>[];
    for (final line in reported) {
      try {
        final caso = await _fetchReport(line.id);
        if (caso == null) continue;
        saved.add(
          _SavedReport(
            line: line,
            body: caso['body']?.toString() ?? '',
            qty: int.tryParse(caso['affected_qty']?.toString() ?? '') ?? 1,
            preference: caso['requested_resolution']?.toString() ?? '',
            evidence: parseOrderMessageAttachments(caso['evidence']),
          ),
        );
      } catch (_) {
        if (mounted) {
          setState(() => _formError =
              'No se pudo cargar el reporte. Vuelve a intentarlo.');
        }
      }
    }
    if (!mounted) return;
    setState(() {
      _saved = saved;
      _loadingSaved = false;
    });
  }

  Future<void> _addEvidence({
    required bool video,
    required bool camera,
  }) async {
    if (_saving || _pickingEvidence || (_mobile && _attempted)) return;
    if (video && _evidence.isNotEmpty) {
      _showError(_hasVideo
          ? 'Solo puede adjuntar un video.'
          : 'Quite las fotos si va a enviar un video.');
      return;
    }
    if (!video && _hasVideo) {
      _showError('Quite el video si va a enviar fotos.');
      return;
    }
    if (!video && _evidence.length >= OrderMessageLimits.maxImagesPerMessage) {
      _showError('Puede adjuntar hasta 3 fotos.');
      return;
    }
    PreparedOrderAttachment? prepared;
    setState(() => _pickingEvidence = true);
    try {
      prepared = widget.pickEvidence != null
          ? await widget.pickEvidence!(video, camera)
          : video
              ? await prepareOrderChatVideo(fromCamera: camera)
              : await prepareOrderChatImage(fromCamera: camera);
    } on OrderMessageLimitException catch (e) {
      if (!mounted) return;
      _showError(e.message);
      return;
    } catch (_) {
      if (!mounted) return;
      _showError('No se pudo obtener el archivo.');
      return;
    } finally {
      if (mounted) setState(() => _pickingEvidence = false);
    }
    if (prepared == null || !mounted) return;
    setState(() {
      _evidence.add(
        _DraftEvidence(
          bytes: prepared!.bytes,
          fileName: prepared.fileName,
          mime: prepared.mime,
          kind: prepared.kind,
        ),
      );
      _formError = null;
    });
  }

  Future<void> _submit() async {
    if (_saving || _pickingEvidence || _submitted) return;
    final note = _noteCtrl.text.trim();
    final chosen = _mobile && _attemptLines != null
        ? _attemptLines!
        : _eligible.where((line) => _selected.contains(line.id)).toList();
    if (chosen.isEmpty) {
      _showError('Seleccione al menos un producto.');
      return;
    }
    if (note.length < 3) {
      _showError('Escriba qué ocurrió antes de enviarlo.');
      return;
    }
    if (_evidence.isEmpty) {
      _showError('Adjunte al menos una foto o un video.');
      return;
    }
    if (_mobile) {
      await _submitMobile(chosen, note);
      return;
    }
    setState(() {
      _saving = true;
      _formError = null;
    });
    try {
      for (final line in chosen) {
        final uploaded = <OrderMessageAttachment>[];
        try {
          for (final item in _evidence) {
            uploaded.add(
              await OrdersService.uploadOrderReturnEvidence(
                transactionRequestId: line.id,
                bytes: item.bytes,
                fileName: item.fileName,
                mime: item.mime,
                kind: item.kind,
              ),
            );
          }
          await OrdersService.registerOrderPostventaCaso(
            transactionRequestId: line.id,
            kind: OrderPostventaKind.devolucion,
            body: note,
            affectedQty: OrderReturnRules.clampAffectedQty(
              _qty[line.id] ?? 1,
              line.cantidad,
            ),
            evidence: uploaded,
          );
        } catch (e) {
          for (final item in uploaded) {
            try {
              await OrdersService.removeOrderReturnEvidence(item.path);
            } catch (_) {}
          }
          rethrow;
        }
      }
      if (!mounted) return;
      setState(() => _changed = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Observación enviada. El proveedor la ve en el chat y acuerda la solución.',
          ),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _formError = _friendly(e);
      });
    }
  }

  Future<void> _submitMobile(
      List<TransactionRequestModel> chosen, String note) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _attempted = true;
      _attemptLines = chosen;
      _formError = null;
    });
    try {
      for (final line in chosen) {
        if (_sentIds.contains(line.id)) continue;
        final qty = OrderReturnRules.clampAffectedQty(
            _qty[line.id] ?? 1, line.cantidad);
        // A lost response can already have created the report. Reconcile before
        // retrying and retain its evidence instead of deleting a committed file.
        final existing = await _fetchReport(line.id);
        if (existing != null) {
          final existingEvidence =
              parseOrderMessageAttachments(existing['evidence']);
          final uploaded = _uploadedById[line.id];
          final sameEvidence = uploaded != null &&
              uploaded.isNotEmpty &&
              existingEvidence.length == uploaded.length &&
              existingEvidence.every(
                  (item) => uploaded.any((saved) => saved.path == item.path));
          if (existing['body']?.toString().trim() != note ||
              int.tryParse(existing['affected_qty']?.toString() ?? '') != qty ||
              !sameEvidence) {
            throw StateError(
                'Este producto ya tiene otro reporte. Vuelve al pedido para consultarlo.');
          }
          _sentIds.add(line.id);
          _changed = true;
          continue;
        }
        final uploaded = _uploadedById.putIfAbsent(line.id, () => []);
        for (var i = uploaded.length; i < _evidence.length; i++) {
          final item = _evidence[i];
          final prepared = PreparedOrderAttachment(
              bytes: item.bytes,
              fileName: item.fileName,
              mime: item.mime,
              kind: item.kind);
          uploaded.add(widget.uploadEvidence != null
              ? await widget.uploadEvidence!(line.id, prepared)
              : await OrdersService.uploadOrderReturnEvidence(
                  transactionRequestId: line.id,
                  bytes: item.bytes,
                  fileName: item.fileName,
                  mime: item.mime,
                  kind: item.kind));
        }
        if (widget.registerReport != null) {
          await widget.registerReport!(line.id, note, qty, uploaded);
        } else {
          await OrdersService.registerOrderPostventaCaso(
              transactionRequestId: line.id,
              kind: OrderPostventaKind.devolucion,
              body: note,
              affectedQty: qty,
              evidence: uploaded);
        }
        _sentIds.add(line.id);
        _changed = true;
      }
      if (!mounted) return;
      setState(() {
        _saving = false;
        _submitted = true;
      });
      if (widget.onSubmitted != null) await _continueInChat();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _formError =
            '${_sentIds.isEmpty ? '' : '${_sentIds.length} de ${chosen.length} productos ya fueron reportados. '}'
            '${error is StateError ? error.message : _friendly(error)} Los datos se conservan para reintentar sin repetir los envíos completados.';
      });
      _revealNotice();
    }
  }

  Future<void> _continueInChat() async {
    if (_openingChat) return;
    if (widget.onSubmitted == null) {
      Navigator.pop(context, _changed);
      return;
    }
    setState(() {
      _openingChat = true;
      _formError = null;
    });
    try {
      await widget.onSubmitted!(
          context,
          _sentIds.isEmpty
              ? widget.lines
                  .where((line) => line.postventaDevolucionAt != null)
                  .map((line) => line.id)
                  .toList()
              : _sentIds.toList());
      if (mounted) Navigator.pop(context, _changed);
    } catch (_) {
      if (mounted) {
        setState(() {
          _openingChat = false;
          _formError =
              'El reporte está registrado, pero no se pudo abrir el chat. Reintenta para continuar.';
        });
        _revealNotice();
      }
    }
  }

  String _friendly(Object error) {
    final raw = error.toString();
    if (raw.contains('plazo de 7 días') || raw.contains('7 days')) {
      return OrderReturnRules.closedHint;
    }
    final message =
        RegExp(r'message:\s*([^,\n]+)').firstMatch(raw)?.group(1)?.trim();
    if (message != null && message.isNotEmpty) return message;
    return 'No se pudo enviar el reporte.';
  }

  @override
  Widget build(BuildContext context) {
    final eligible = _eligible;
    final showForm = !widget.viewOnly &&
        (eligible.isNotEmpty || (_mobile && _attempted && !_submitted));
    if (_mobile) return _buildMobile(showForm, eligible);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title:
              Text(showForm ? 'Reportar inconveniente' : 'Reporte del pedido'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(_changed),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            Text(
              showForm
                  ? 'Seleccione los productos y describa el inconveniente. El proveedor acuerda con usted la solución en el chat.'
                  : 'Así quedó la observación enviada a su proveedor.',
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            if (showForm) ..._form(eligible),
            if (_loadingSaved)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
            for (final report in _saved) ...[
              _SavedCard(report: report),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMobile(bool showForm, List<TransactionRequestModel> eligible) {
    final theme = B2BThemeExtension.of(context);
    final deadlines = eligible
        .map((line) => OrderReturnRules.availableUntil(
            deliveredAt: line.atEntregado, updatedAt: line.updatedAt))
        .whereType<DateTime>()
        .toList()
      ..sort();
    void back() {
      if (!_saving && !_openingChat) Navigator.pop(context, _changed);
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) back();
      },
      child: Scaffold(
        backgroundColor: theme.background,
        appBar: mobileOrderActionBar(
            context,
            _submitted
                ? 'Reporte enviado'
                : showForm
                    ? 'Reportar inconveniente'
                    : 'Reporte del pedido',
            onBack: back),
        body: SafeArea(
            top: false,
            child: Column(children: [
              Expanded(
                  child: ListView(
                      controller: _scroll,
                      padding: const EdgeInsets.all(16),
                      children: [
                    MobileOrderActionPanel(
                        child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Icon(Icons.storefront_outlined, color: theme.brand),
                          const SizedBox(width: 10),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(mobileOrderReference(widget.lines),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w800)),
                                const SizedBox(height: 3),
                                Text(widget.lines.first.ownerBusinessName ??
                                    'Proveedor'),
                              ])),
                        ])),
                    if (_formError != null) ...[
                      MobileOrderActionNotice(_formError!, error: true),
                      if (_formError!.contains('cargar el reporte'))
                        TextButton.icon(
                            onPressed: _loadingSaved ? null : _loadSaved,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Reintentar carga')),
                    ],
                    if (_submitted) ...[
                      Icon(Icons.check_circle_outline,
                          color: theme.successFg, size: 64),
                      const SizedBox(height: 12),
                      const Text('Reporte registrado',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 23, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      const Text(
                          'Continúa en el chat para acordar la solución con el proveedor.',
                          textAlign: TextAlign.center),
                    ] else if (showForm) ...[
                      MobileOrderActionNotice(
                          'Puedes reportar dentro de los 7 días posteriores a la entrega.'
                          '${deadlines.isEmpty ? '' : ' Disponible hasta el ${formatEsShortDateTime(deadlines.first)}.'}'),
                      const Text('Productos afectados',
                          style: TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 10),
                      ..._form(eligible),
                      const SizedBox(height: 12),
                      const MobileOrderActionNotice(
                          'La solución se acuerda con el proveedor. Puede ser un cambio de producto o crédito a favor.'),
                    ] else if (!widget.viewOnly &&
                        _saved.isEmpty &&
                        !_loadingSaved)
                      const MobileOrderActionNotice(
                          OrderReturnRules.closedHint),
                    if (!_submitted) ...[
                      if (_loadingSaved)
                        const Center(child: CircularProgressIndicator()),
                      for (final report in _saved) ...[
                        _SavedCard(report: report),
                        const SizedBox(height: 10)
                      ],
                    ],
                  ])),
              Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                        style: FilledButton.styleFrom(
                            backgroundColor: mobileOrderActionBlue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            minimumSize: const Size(44, 48)),
                        onPressed: _saving || _openingChat || _pickingEvidence
                            ? null
                            : showForm && !_submitted
                                ? _submit
                                : _continueInChat,
                        child: Text(
                            _saving
                                ? 'Enviando reporte…'
                                : _openingChat
                                    ? 'Abriendo chat…'
                                    : showForm && !_submitted
                                        ? _attempted
                                            ? 'Reintentar envío'
                                            : 'Enviar reporte'
                                        : widget.onSubmitted != null
                                            ? 'Continuar en el chat'
                                            : 'Volver al pedido',
                            textAlign: TextAlign.center)),
                  )),
            ])),
      ),
    );
  }

  Future<void> _showEvidenceOptions() async {
    final choice = await showModalBottomSheet<int>(
        context: context,
        showDragHandle: true,
        builder: (sheet) => SafeArea(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              for (final option in [
                (Icons.photo_camera_outlined, 'Tomar foto'),
                (Icons.photo_library_outlined, 'Elegir foto'),
                (Icons.videocam_outlined, 'Grabar video'),
                (Icons.video_library_outlined, 'Elegir video')
              ].asMap().entries)
                ListTile(
                    leading: Icon(option.value.$1),
                    title: Text(option.value.$2),
                    onTap: () => Navigator.pop(sheet, option.key)),
            ])));
    if (choice != null && mounted) {
      await _addEvidence(video: choice >= 2, camera: choice.isEven);
    }
  }

  List<Widget> _form(List<TransactionRequestModel> eligible) {
    final selected =
        eligible.where((line) => _selected.contains(line.id)).toList();
    return [
      for (final line in widget.lines) ...[
        _ProductRow(
          line: line,
          eligible: eligible.any((item) => item.id == line.id),
          selected: _selected.contains(line.id),
          qty: _qty[line.id] ?? 1,
          compact: _mobile,
          enabled: _editable,
          onSelected: (value) {
            setState(() {
              if (value) {
                _selected.add(line.id);
                _qty.putIfAbsent(line.id, () => 1);
              } else {
                _selected.remove(line.id);
              }
            });
          },
          onQty: (value) => setState(() => _qty[line.id] = value),
        ),
        const SizedBox(height: 8),
      ],
      const SizedBox(height: 8),
      TextField(
        controller: _noteCtrl,
        minLines: 3,
        maxLines: 5,
        maxLength: _mobile ? 4000 : null,
        enabled: _editable,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          labelText: _mobile ? '¿Qué ocurrió?' : 'Qué inconveniente tuvo',
          hintText: 'Escríbalo con claridad.',
          filled: true,
          fillColor: AppColors.fieldFill,
          border: const OutlineInputBorder(),
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
      if (_mobile)
        _mobileEvidence()
      else
        OrderMessageAttachButtons(
          enabled: !_saving,
          onPhotoCamera: () => _addEvidence(video: false, camera: true),
          onPhotoGallery: () => _addEvidence(video: false, camera: false),
          onVideoCamera: () => _addEvidence(video: true, camera: true),
          onVideoGallery: () => _addEvidence(video: true, camera: false),
        ),
      if (!_mobile && _evidence.isNotEmpty) _evidenceStrip(),
      if (!_mobile && selected.isNotEmpty) ...[
        const SizedBox(height: 8),
        _Preview(
          lines: selected,
          qtyFor: (id) => _qty[id] ?? 1,
          reason: _noteCtrl.text.trim(),
          preference: null,
          evidence: _evidence,
        ),
      ],
      if (!_mobile) ...[
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: OrderListColors.of(context).onAccent,
                  ),
                )
              : const Text('Enviar reporte'),
        ),
        if (_formError != null) ...[
          const SizedBox(height: 8),
          Text(
            _formError!,
            style: TextStyle(color: Colors.red.shade800, fontSize: 13),
          ),
        ],
      ],
    ];
  }

  Widget _evidenceStrip() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
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
                    child: item.isVideo
                        ? ColoredBox(
                            color: AppColors.brandBlueContainer,
                            child: const Icon(
                              Icons.videocam_outlined,
                              color: AppColors.brand,
                            ),
                          )
                        : Image.memory(item.bytes,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Center(
                                child: Icon(Icons.broken_image_outlined))),
                  ),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: !_editable
                        ? null
                        : () => setState(() => _evidence.removeAt(index)),
                    icon: const Icon(Icons.close, size: 16),
                    style: IconButton.styleFrom(
                      backgroundColor: OrderListColors.of(context).surface,
                      foregroundColor: OrderListColors.of(context).ink,
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

  Widget _mobileEvidence() {
    final theme = B2BThemeExtension.of(context);
    final canAdd =
        !_hasVideo && _evidence.length < OrderMessageLimits.maxImagesPerMessage;
    return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: LayoutBuilder(builder: (context, constraints) {
          final size = ((constraints.maxWidth - 10) / 2).clamp(96.0, 128.0);
          final addWidth =
              (constraints.maxWidth - size - 10).clamp(size, 180.0);
          return Wrap(spacing: 10, runSpacing: 10, children: [
            for (var index = 0; index < _evidence.length; index++)
              SizedBox(
                  width: size,
                  height: size,
                  child: Stack(fit: StackFit.expand, children: [
                    ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: ColoredBox(
                            color: theme.surfaceCard,
                            child: _evidence[index].isVideo
                                ? Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                        Icon(Icons.play_circle_outline,
                                            size: 36, color: theme.brand),
                                        const SizedBox(height: 6),
                                        const Text('Video adjunto',
                                            textAlign: TextAlign.center),
                                      ])
                                : Image.memory(_evidence[index].bytes,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Center(
                                        child: Icon(
                                            Icons.broken_image_outlined))))),
                    Positioned(
                        top: 0,
                        right: 0,
                        child: IconButton(
                            tooltip: 'Quitar evidencia ${index + 1}',
                            onPressed: _editable
                                ? () =>
                                    setState(() => _evidence.removeAt(index))
                                : null,
                            icon: const Icon(Icons.close, size: 18),
                            style: IconButton.styleFrom(
                                backgroundColor: theme.surfaceCard,
                                foregroundColor: theme.textPrimary))),
                  ])),
            if (canAdd)
              SizedBox(
                  width: _evidence.isEmpty ? double.infinity : addWidth,
                  height: size,
                  child: OutlinedButton(
                      onPressed: _editable ? _showEvidenceOptions : null,
                      style: OutlinedButton.styleFrom(
                          foregroundColor: theme.textPrimary,
                          backgroundColor: theme.brandContainer,
                          side: BorderSide(color: theme.borderStrong),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))),
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_a_photo_outlined,
                                color: theme.brand, size: 28),
                            const SizedBox(height: 8),
                            const Text('Agregar foto o video',
                                textAlign: TextAlign.center),
                          ]))),
          ]);
        }));
  }
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({
    required this.line,
    required this.eligible,
    required this.selected,
    required this.qty,
    required this.enabled,
    required this.onSelected,
    required this.onQty,
    this.compact = false,
  });

  final TransactionRequestModel line;
  final bool eligible;
  final bool selected;
  final int qty;
  final bool enabled;
  final ValueChanged<bool> onSelected;
  final ValueChanged<int> onQty;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = OrderListColors.of(context);
    final name = (line.productName ?? '').trim();
    final sku = line.productSku?.trim();
    final reported = line.postventaDevolucionAt != null;
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.brand : AppColors.borderSubtle,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                OrderProductThumb(
                  size: 52,
                  url: productCoverImageUrl(line.productImageUrls),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name.isEmpty ? 'Producto' : name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (sku != null && sku.isNotEmpty)
                        Text(
                          'SKU $sku',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      Text(
                        line.cantidad == 1
                            ? '1 unidad en el pedido'
                            : '${line.cantidad} unidades en el pedido',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (compact && line.atEntregado != null)
                        Text(
                            'Entregado el ${formatEsShortDate(line.atEntregado!)}',
                            style: TextStyle(
                                fontSize: 12, color: AppColors.textSecondary)),
                      if (reported)
                        const Text(
                          'Ya reportado',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.brand,
                          ),
                        )
                      else if (!eligible)
                        Text(
                          'Fuera del plazo',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                if (eligible)
                  Checkbox(
                    value: selected,
                    onChanged:
                        enabled ? (value) => onSelected(value ?? false) : null,
                    activeColor: AppColors.brand,
                  ),
              ],
            ),
            if (selected && line.cantidad > 1)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      qty == 1
                          ? '1 unidad con inconveniente'
                          : '$qty unidades con inconveniente',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed:
                        !enabled || qty <= 1 ? null : () => onQty(qty - 1),
                    icon: const Icon(Icons.remove_circle_outline),
                    tooltip: 'Menos unidades',
                  ),
                  IconButton(
                    onPressed: !enabled || qty >= line.cantidad
                        ? null
                        : () => onQty(qty + 1),
                    icon: const Icon(Icons.add_circle_outline),
                    tooltip: 'Más unidades',
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({
    required this.lines,
    required this.qtyFor,
    required this.reason,
    required this.preference,
    required this.evidence,
  });

  final List<TransactionRequestModel> lines;
  final int Function(String id) qtyFor;
  final String reason;
  final String? preference;
  final List<_DraftEvidence> evidence;

  @override
  Widget build(BuildContext context) {
    final colors = OrderListColors.of(context);
    final pref = OrderReturnRules.preferenceLabel(preference);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Vista previa',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          for (final line in lines) ...[
            Row(
              children: [
                OrderProductThumb(
                  size: 44,
                  url: productCoverImageUrl(line.productImageUrls),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${(line.productName ?? 'Producto').trim()} · ${qtyFor(line.id) == 1 ? '1 unidad' : '${qtyFor(line.id)} unidades'}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          if (pref.isNotEmpty)
            Text(
              'Preferencia: $pref',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          if (reason.isNotEmpty)
            Text(
              reason,
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                color: AppColors.textPrimary,
              ),
            ),
          if (evidence.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 56,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: evidence.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, index) {
                  final item = evidence[index];
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 56,
                      height: 56,
                      child: item.isVideo
                          ? ColoredBox(
                              color: AppColors.brandBlueContainer,
                              child: const Icon(
                                Icons.videocam_outlined,
                                color: AppColors.brand,
                              ),
                            )
                          : Image.memory(item.bytes, fit: BoxFit.cover),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SavedCard extends StatelessWidget {
  const _SavedCard({required this.report});

  final _SavedReport report;

  @override
  Widget build(BuildContext context) {
    final colors = OrderListColors.of(context);
    final line = report.line;
    final name = (line.productName ?? 'Producto').trim();
    final sku = line.productSku?.trim();
    final pref = OrderReturnRules.preferenceLabel(report.preference);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              OrderProductThumb(
                size: 52,
                url: productCoverImageUrl(line.productImageUrls),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (sku != null && sku.isNotEmpty)
                      Text(
                        'SKU $sku',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    Text(
                      report.qty == 1 ? '1 unidad' : '${report.qty} unidades',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (pref.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Preferencia: $pref',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
            ),
          ],
          if (report.body.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              report.body.trim(),
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                color: AppColors.textPrimary,
              ),
            ),
          ],
          OrderMessageMediaStrip(attachments: report.evidence),
        ],
      ),
    );
  }
}
