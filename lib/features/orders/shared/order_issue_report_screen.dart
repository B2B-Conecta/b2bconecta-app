import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/features/inventory/product_images.dart';
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
  });

  final List<TransactionRequestModel> lines;
  final bool viewOnly;

  @override
  State<OrderIssueReportScreen> createState() => _OrderIssueReportScreenState();
}

class _OrderIssueReportScreenState extends State<OrderIssueReportScreen> {
  final _noteCtrl = TextEditingController();
  final _selected = <String>{};
  final _qty = <String, int>{};
  final _evidence = <_DraftEvidence>[];
  bool _saving = false;
  bool _loadingSaved = false;
  bool _changed = false;
  String? _formError;
  List<_SavedReport> _saved = const [];

  bool get _hasVideo => _evidence.any((item) => item.isVideo);

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
    super.dispose();
  }

  Future<void> _loadSaved() async {
    final reported =
        widget.lines.where((line) => line.postventaDevolucionAt != null);
    if (reported.isEmpty) return;
    setState(() => _loadingSaved = true);
    final saved = <_SavedReport>[];
    for (final line in reported) {
      try {
        final caso = await OrdersService.fetchOrderPostventaCaso(
          transactionRequestId: line.id,
          kind: OrderPostventaKind.devolucion,
        );
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
      } catch (_) {}
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
      setState(() => _formError = 'Quite el video si va a enviar fotos.');
      return;
    }
    if (!video && _evidence.length >= OrderMessageLimits.maxImagesPerMessage) {
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
    final note = _noteCtrl.text.trim();
    final chosen =
        _eligible.where((line) => _selected.contains(line.id)).toList();
    if (chosen.isEmpty) {
      setState(() => _formError = 'Seleccione al menos un producto.');
      return;
    }
    if (note.length < 3) {
      setState(() => _formError = 'Escriba qué ocurrió antes de enviarlo.');
      return;
    }
    if (_evidence.isEmpty) {
      setState(() => _formError = 'Adjunte al menos una foto o un video.');
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

  String _friendly(Object error) {
    final raw = error.toString();
    if (raw.contains('plazo de 7 días') || raw.contains('7 days')) {
      return OrderReturnRules.closedHint;
    }
    final message = RegExp(r'message:\s*([^,\n]+)')
        .firstMatch(raw)
        ?.group(1)
        ?.trim();
    if (message != null && message.isNotEmpty) return message;
    return 'No se pudo enviar el reporte.';
  }

  @override
  Widget build(BuildContext context) {
    final eligible = _eligible;
    final showForm = !widget.viewOnly && eligible.isNotEmpty;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(showForm ? 'Reportar inconveniente' : 'Reporte del pedido'),
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
          enabled: !_saving,
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
        enabled: !_saving,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          labelText: 'Qué inconveniente tuvo',
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
      OrderMessageAttachButtons(
        enabled: !_saving,
        onPhotoCamera: () => _addEvidence(video: false, camera: true),
        onPhotoGallery: () => _addEvidence(video: false, camera: false),
        onVideoCamera: () => _addEvidence(video: true, camera: true),
        onVideoGallery: () => _addEvidence(video: true, camera: false),
      ),
      if (_evidence.isNotEmpty) _evidenceStrip(),
      if (selected.isNotEmpty) ...[
        const SizedBox(height: 8),
        _Preview(
          lines: selected,
          qtyFor: (id) => _qty[id] ?? 1,
          reason: _noteCtrl.text.trim(),
          preference: null,
          evidence: _evidence,
        ),
      ],
      const SizedBox(height: 12),
      FilledButton(
        onPressed: _saving ? null : _submit,
        child: _saving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
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
                            child: Icon(
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
                    onPressed: _saving
                        ? null
                        : () => setState(() => _evidence.removeAt(index)),
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

class _ProductRow extends StatelessWidget {
  const _ProductRow({
    required this.line,
    required this.eligible,
    required this.selected,
    required this.qty,
    required this.enabled,
    required this.onSelected,
    required this.onQty,
  });

  final TransactionRequestModel line;
  final bool eligible;
  final bool selected;
  final int qty;
  final bool enabled;
  final ValueChanged<bool> onSelected;
  final ValueChanged<int> onQty;

  @override
  Widget build(BuildContext context) {
    final name = (line.productName ?? '').trim();
    final sku = line.productSku?.trim();
    final reported = line.postventaDevolucionAt != null;
    return Material(
      color: AppColors.card,
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
                        if (reported)
                          Text(
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
                      onChanged: enabled
                          ? (value) => onSelected(value ?? false)
                          : null,
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
                      onPressed: !enabled || qty <= 1
                          ? null
                          : () => onQty(qty - 1),
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
    final pref = OrderReturnRules.preferenceLabel(preference);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
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
                              child: Icon(
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
    final line = report.line;
    final name = (line.productName ?? 'Producto').trim();
    final sku = line.productSku?.trim();
    final pref = OrderReturnRules.preferenceLabel(report.preference);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
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
                      report.qty == 1
                          ? '1 unidad'
                          : '${report.qty} unidades',
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
