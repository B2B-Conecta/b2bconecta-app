import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:motolink_pro_app/core/layout/app_breakpoints.dart';
import 'package:motolink_pro_app/core/widgets/desktop_workflow.dart';
import 'package:motolink_pro_app/core/widgets/b2b_header_title.dart';
import 'package:flutter/services.dart';
import 'package:file_saver/file_saver.dart';
import '../../app/theme/b2b_theme_extension.dart';
import '../../core/data/supabase_service.dart';
import '../../core/utils/app_date_format.dart';
import '../../core/utils/document_pick_utils.dart';
import '../../core/utils/stored_file_page.dart';
import '../../core/utils/stored_file_frame.dart';
import '../../core/utils/stored_file_actions.dart';
import '../../core/utils/upload_file_guard.dart';
import '../../core/utils/ves_amount_format.dart';
import '../orders/shared/transaction_request_model.dart';
import '../orders/shared/order_payment_pricing.dart';
import 'mobile_supplier_payment_model.dart';
import 'pago_metodo.dart';
import 'pago_revision_estado.dart';
import 'payments_service.dart';

typedef SupplierPaymentSubmit = Future<void> Function(
    List<TransactionRequestModel>,
    SupplierPaymentDeclaration,
    PickedDocumentBytes?);

/// Guided payment. The supplied lines always belong to one supplier.
class MobileSupplierPaymentScreen extends StatefulWidget {
  const MobileSupplierPaymentScreen(
      {super.key,
      required this.lines,
      required this.onChanged,
      this.onMessage,
      this.loadLines,
      this.pickProof,
      this.submit,
      this.refreshInterval = const Duration(seconds: 30),
      this.now});
  final List<TransactionRequestModel> lines;
  final VoidCallback onChanged;
  final VoidCallback? onMessage;
  final Future<List<TransactionRequestModel>> Function()? loadLines;
  final Future<PickedDocumentBytes?> Function(DocumentPickChannel)? pickProof;
  final SupplierPaymentSubmit? submit;
  final DateTime Function()? now;
  final Duration? refreshInterval;
  @override
  State<MobileSupplierPaymentScreen> createState() =>
      _MobileSupplierPaymentScreenState();
}

class _MobileSupplierPaymentScreenState
    extends State<MobileSupplierPaymentScreen> with WidgetsBindingObserver {
  static const _blue = Color(0xFF0047E1);
  final _scroll = ScrollController(), _form = GlobalKey<FormState>();
  final _reference = TextEditingController(),
      _amount = TextEditingController(),
      _note = TextEditingController();
  late List<TransactionRequestModel> _lines;
  late DateTime _paidOn;
  String? _method, _error, _submissionId;
  PickedDocumentBytes? _proof;
  String? _pdfUrl;
  int _step = 0;
  bool _sending = false,
      _refreshing = false,
      _picking = false,
      _submitted = false,
      _uncertain = false;
  bool _loadFailed = false;
  Timer? _statusTimer;
  DateTime get _now => (widget.now ?? DateTime.now)();
  TransactionRequestModel get _ref => _lines.first;
  MobileSupplierPaymentQuote get _quote =>
      MobileSupplierPaymentQuote(_lines, _method);
  String get _status => supplierPaymentStatus(_lines);
  bool get _canEdit => supplierPaymentEditable(_lines);
  bool get _reviewing => _lines.any(
      (l) => l.pagoEstadoRevisionEfectivo == PagoRevisionEstado.enRevision);
  bool get _hasSubmission => _lines
      .any((l) => l.comprobantePagoSubmittedAt != null || l.hasComprobantePago);
  B2BThemeExtension get _theme => B2BThemeExtension.of(context);
  Color get _accent => Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF85B0FF)
      : _blue;
  Color get _success => Theme.of(context).brightness == Brightness.dark
      ? _theme.successFg
      : const Color(0xFF15803D);

  @override
  void initState() {
    super.initState();
    _lines = List.of(widget.lines);
    _paidOn = DateUtils.dateOnly(_now);
    _reference.text = _ref.pagoDeclaracion['reference'] as String? ?? '';
    _note.text = _ref.pagoDeclaracion['note'] as String? ?? '';
    final savedDate =
        DateTime.tryParse(_ref.pagoDeclaracion['paid_on'] as String? ?? '');
    if (savedDate != null && !savedDate.isAfter(_paidOn)) _paidOn = savedDate;
    final savedAmount = _ref.pagoDeclaracion['amount'];
    if (savedAmount is num) _amount.text = savedAmount.toStringAsFixed(2);
    _syncMethod();
    if (_hasSubmission || _status == 'Pago confirmado') _step = 3;
    WidgetsBinding.instance.addObserver(this);
    if (widget.loadLines != null && widget.refreshInterval != null) {
      _statusTimer = Timer.periodic(widget.refreshInterval!, (_) {
        if (mounted &&
            _step == 3 &&
            ModalRoute.of(context)?.isCurrent == true) {
          _refresh();
        }
      });
    }
    if (widget.loadLines != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
    }
  }

  void _syncMethod() {
    final methods = _quote.methods;
    if (_hasSubmission && _reviewing && _ref.pagoMetodo != null) {
      _method = _ref.pagoMetodo;
      return;
    }
    if (_status == 'Pago confirmado' && _ref.pagoMetodo != null) {
      _method = _ref.pagoMetodo;
      return;
    }
    if (!methods.contains(_method)) {
      _method = methods.contains(_ref.pagoMetodo)
          ? _ref.pagoMetodo
          : (methods.isEmpty ? null : methods.first);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _step == 3 && !_sending) {
      _refresh();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _statusTimer?.cancel();
    _scroll.dispose();
    _reference.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  void _go(int step) {
    FocusScope.of(context).unfocus();
    setState(() {
      _step = step;
      _error = null;
    });
    _showStepFromTop();
  }

  void _showStepFromTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scroll.hasClients) _scroll.jumpTo(0);
    });
  }

  Future<void> _refresh() async {
    if (_refreshing || _sending || widget.loadLines == null) return;
    setState(() => _refreshing = true);
    try {
      final refreshed = await widget.loadLines!();
      if (!mounted) return;
      final ids = _lines.map((l) => l.id).toSet();
      final supplier = refreshed
          .where((l) =>
              l.ownerId == _ref.ownerId &&
              l.aliadoId == _ref.aliadoId &&
              l.checkoutGroupId == _ref.checkoutGroupId)
          .toList();
      if (supplier.isEmpty ||
          !ids.every((id) => supplier.any((l) => l.id == id))) {
        throw StateError(
            'El pedido cambió. Vuelve al detalle para actualizarlo.');
      }
      final pricesChanged = _lines.length != supplier.length ||
          _lines.any((old) => supplier.any((l) =>
              l.id == old.id &&
              (l.precioTotal != old.precioTotal ||
                  l.totalBs != old.totalBs ||
                  l.metodoPagoMoneda != old.metodoPagoMoneda)));
      setState(() {
        _loadFailed = false;
        _error = null;
        _lines = supplier;
        _syncMethod();
        if (supplier.any((l) =>
            l.pagoDeclaracion['submission_id'] == _submissionId &&
            _submissionId != null)) _submitted = false;
        if (pricesChanged && _step == 2 && !_uncertain) {
          _step = 0;
          _submissionId = null;
          _error = 'El importe cambió. Revisa el resumen antes de continuar.';
        }
        if (_status == 'Pago confirmado') {
          _step = 3;
          _uncertain = false;
          _submitted = false;
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadFailed = true;
          _error =
              'No pudimos actualizar el pedido. Reintenta antes de enviar un pago.';
        });
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  void _draftChanged() {
    if (!_uncertain) _submissionId = null;
  }

  Future<void> _pick(DocumentPickChannel channel) async {
    if (_picking || _sending || _uncertain) return;
    setState(() {
      _picking = true;
      _error = null;
    });
    try {
      final picked = await (widget.pickProof?.call(channel) ??
          pickKycDocument(channel: channel));
      if (picked == null || !mounted) return;
      final checked = UploadFileGuard.check(picked.bytes, picked.fileName,
          kind: UploadKind.imageOrPdf);
      setState(() {
        _proof = PickedDocumentBytes(
            bytes: checked.bytes, fileName: checked.fileName);
        _pdfUrl = checked.mime == 'application/pdf'
            ? Uri.dataFromBytes(checked.bytes, mimeType: checked.mime)
                .toString()
            : null;
        _submissionId = null;
      });
    } on UploadRejectedException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'No pudimos abrir el archivo. Intenta con otra imagen o PDF.');
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _send() async {
    if (_sending || _refreshing || _loadFailed) return;
    if (!_form.currentState!.validate()) return;
    if (!_canEdit) {
      _go(3);
      return;
    }
    if (_method != PagoMetodo.efectivo && _proof == null) {
      setState(() => _error = 'Adjunta un comprobante antes de enviarlo.');
      return;
    }
    _submissionId ??= _newId();
    final declaration = SupplierPaymentDeclaration(
        submissionId: _submissionId!,
        method: _method!,
        reference: _reference.text,
        paidOn: _paidOn,
        amount: parseDeclaredPaymentAmount(_amount.text)!,
        currency: _quote.currency,
        previousSubmissionId:
            _ref.pagoDeclaracion['submission_id'] as String? ?? '',
        note: _note.text);
    setState(() {
      _sending = true;
      _error = null;
    });
    var sent = false;
    try {
      if (widget.submit != null) {
        await widget.submit!(_lines, declaration, _proof);
      } else {
        await PaymentsService.submitMobileSupplierPayment(
            lines: _lines, declaration: declaration, proof: _proof);
      }
      if (!mounted) return;
      setState(() {
        _submitted = true;
        _uncertain = false;
        _step = 3;
      });
      FocusScope.of(context).unfocus();
      _showStepFromTop();
      widget.onChanged();
      sent = true;
    } catch (e) {
      if (!mounted) return;
      // Transport failures may have committed; retry exactly the same declaration.
      final known = e.toString().contains('PostgrestException') ||
          e is ArgumentError ||
          e is UploadRejectedException ||
          e is StateError;
      setState(() {
        _uncertain = !known;
        _error = known
            ? 'No se pudo registrar el pago. ${_friendlyError(e)}'
            : 'No recibimos confirmación. Conservamos estos datos: pulsa «Verificar envío» para consultar o reintentar el mismo envío.';
      });
    } finally {
      if (mounted) setState(() => _sending = false);
    }
    if (sent && mounted) await _refresh();
  }

  String _friendlyError(Object e) {
    final text = e.toString();
    if (text.contains('PGRST202') || text.contains('pago_declaracion')) {
      return 'La función de pagos aún no está habilitada en este entorno.';
    }
    if (e is ArgumentError || e is UploadRejectedException) return text;
    if (text.contains('message:')) {
      return text.split('message:').last.split(', code:').first.trim();
    }
    return 'Actualiza el pedido y revisa los datos antes de reintentar.';
  }

  static String _newId() {
    final random = Random.secure();
    final bytes = List.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final h = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }

  Future<void> _file(TransactionRequestModel line,
      {bool download = false, bool proof = false}) async {
    try {
      final path = proof
          ? line.comprobantePagoStoragePath
          : line.proveedorFacturaStoragePath;
      if (path == null) return;
      final name = (proof
              ? line.comprobantePagoFileName
              : line.proveedorFacturaFileName) ??
          (proof ? 'Comprobante' : 'Factura');
      if (download) {
        final url = await SupabaseService.createSignedUrlForOrderInvoice(path);
        await downloadStoredFile(url, name);
      } else {
        if (!mounted) return;
        await openStoredFile(context,
            signedUrl: () => proof
                ? SupabaseService.createSignedUrlForComprobantePago(path)
                : SupabaseService.createSignedUrlForOrderInvoice(path),
            fileName: name);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No pudimos abrir el archivo. Reintenta.');
      }
    }
  }

  Future<void> _showProof() async {
    final proof = _proof;
    if (proof == null) return;
    await Navigator.of(context).push<void>(MaterialPageRoute(
        builder: (context) => Scaffold(
              appBar: AppBar(title: Text(proof.fileName)),
              body: _pdfUrl == null
                  ? Center(
                      child:
                          InteractiveViewer(child: Image.memory(proof.bytes)))
                  : Column(children: [
                      Expanded(
                          child: buildStoredFileFrame(_pdfUrl!) ??
                              Center(
                                  child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                    const Icon(Icons.picture_as_pdf_outlined,
                                        size: 64),
                                    Text(proof.fileName),
                                  ]))),
                      SafeArea(
                          child: TextButton(
                              onPressed: () async {
                                try {
                                  await FileSaver.instance.saveFile(
                                      name: 'comprobante',
                                      bytes: proof.bytes,
                                      ext: 'pdf',
                                      mimeType: MimeType.pdf);
                                } catch (_) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                            content: Text(
                                                'No pudimos guardar el PDF. Reintenta.')));
                                  }
                                }
                              },
                              child: const Text('Guardar PDF para revisarlo'))),
                    ]),
            )));
  }

  Widget _panel(Widget child) => Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: _theme.surfaceCard, borderRadius: BorderRadius.circular(16)),
      child: child);
  Widget _heading(String text) => Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 12),
      child: Text(text,
          style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              color: _theme.textPrimary)));
  Widget _row(String label, String value, {bool strong = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
            child: Text(label,
                style: TextStyle(color: _theme.textSecondary, fontSize: 13))),
        const SizedBox(width: 10),
        Flexible(
            fit: FlexFit.tight,
            child: Text(value,
                textAlign: TextAlign.right,
                style: TextStyle(
                    color: _theme.textPrimary,
                    fontSize: strong ? 19 : 14,
                    fontWeight: strong ? FontWeight.w800 : FontWeight.w600))),
      ]));
  Widget _notice(String text, {bool warning = false}) => Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: warning ? _theme.warningBg : _theme.brandContainer,
          borderRadius: BorderRadius.circular(12)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.info_outline,
            size: 20, color: warning ? _theme.warningFg : _theme.textPrimary),
        const SizedBox(width: 9),
        Expanded(
            child: Text(text,
                style: TextStyle(
                    fontSize: 13, height: 1.35, color: _theme.textPrimary)))
      ]));
  String _money(double? value, {String? currency}) => value == null
      ? 'Importe por confirmar'
      : (currency ?? _quote.currency) == 'BS'
          ? formatBsLabel(value)
          : '${formatRefAmount(value)} USD';
  Widget _supplier() =>
      _panel(Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.storefront_outlined, color: _accent, size: 25),
        const SizedBox(width: 10),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_ref.ownerBusinessName ?? 'Proveedor',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          Text(
              'Pedido #${(_ref.checkoutGroupId ?? _ref.id).replaceAll('-', '').substring(0, min(8, (_ref.checkoutGroupId ?? _ref.id).replaceAll('-', '').length)).toUpperCase()}',
              style: TextStyle(fontSize: 12, color: _theme.textSecondary)),
          if (_step > 0)
            Padding(
                padding: const EdgeInsets.only(top: 7),
                child: Text(_money(_quote.payable),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800))),
        ])),
      ]));

  Widget _paymentBadge() => Align(
      alignment: Alignment.centerLeft,
      child: Container(
          key: const ValueKey('invoice-payment-status'),
          margin: const EdgeInsets.only(top: 7),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
              color: _status == 'Pago confirmado'
                  ? _theme.successBg
                  : _theme.warningBg,
              borderRadius: BorderRadius.circular(20)),
          child: Text(_status,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _status == 'Pago confirmado'
                      ? _success
                      : _theme.textPrimary))));

  Widget _productPaymentRow(TransactionRequestModel line) {
    final total = OrderPaymentPricing.previewForRequest(
            request: line, pagoMetodo: _method)
        .total;
    final currency = _quote.bolivares ? 'REF' : 'USD';
    final unit = line.cantidad > 0 ? total / line.cantidad : total;
    final amount = Text('${formatRefAmount(total)} $currency',
        textAlign: TextAlign.right,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14));
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
              width: 52,
              height: 52,
              child: line.productImageUrls.isEmpty
                  ? const Icon(Icons.inventory_2_outlined)
                  : Image.network(line.productImageUrls.first,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.inventory_2_outlined))),
          const SizedBox(width: 10),
          Expanded(child: LayoutBuilder(builder: (context, constraints) {
            final narrow = constraints.maxWidth < 235 ||
                MediaQuery.textScalerOf(context).scale(14) > 18;
            final details =
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(line.productName ?? 'Producto',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(
                  '${line.cantidad} ${line.cantidad == 1 ? 'ud' : 'uds'} × ${formatRefAmount(unit, fractionDigits: (unit * 100 - (unit * 100).round()).abs() > .0001 ? 4 : 2)} $currency',
                  style: TextStyle(
                      fontSize: 12, height: 1.35, color: _theme.textSecondary)),
            ]);
            if (narrow) {
              return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [details, const SizedBox(height: 6), amount]);
            }
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: details),
              const SizedBox(width: 10),
              Flexible(fit: FlexFit.tight, child: amount)
            ]);
          })),
        ]));
  }

  List<Widget> _invoice() {
    final invoices = <String, TransactionRequestModel>{
      for (final l in _lines)
        if (l.hasProveedorFactura) l.proveedorFacturaStoragePath!: l
    };
    return [
      if (invoices.isEmpty)
        _notice(
            'El proveedor aún no adjunta su factura. Podrás registrar el pago cuando esté disponible.'),
      for (final line in invoices.values)
        _panel(
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.description_outlined, color: _accent, size: 30),
            const SizedBox(width: 10),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(line.proveedorFacturaFileName ?? 'Factura del proveedor',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 16)),
                  _paymentBadge(),
                  if (line.proveedorFacturaSubmittedAt != null)
                    Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Text(
                            'Recibida: ${formatEsShortDate(line.proveedorFacturaSubmittedAt!)}',
                            style: TextStyle(
                                fontSize: 12, color: _theme.textSecondary))),
                ]))
          ]),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 4, children: [
            OutlinedButton.icon(
                onPressed: () => _file(line),
                icon: const Icon(Icons.visibility_outlined, size: 18),
                label: const Text('Ver factura')),
            OutlinedButton.icon(
                onPressed: () => _file(line, download: true),
                icon: const Icon(Icons.download_outlined, size: 18),
                label: const Text('Descargar')),
          ]),
        ])),
      _heading('Resumen del pedido'),
      _panel(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (var i = 0; i < _lines.length; i++) ...[
          if (i > 0) const Divider(height: 12),
          _productPaymentRow(_lines[i]),
        ],
        const Divider(height: 18),
        _row('Productos',
            '${formatRefAmount(_quote.productTotal)} ${_quote.bolivares ? 'REF' : 'USD'}'),
        _row('Importe al proveedor', _money(_quote.payable), strong: true),
        if (_quote.bolivares && _quote.rate != null)
          Text(
              'Tasa aplicada: Bs ${formatTasaBcvDisplay(_quote.rate!, fractionDigits: 4)} por REF',
              style: TextStyle(fontSize: 12, color: _theme.textSecondary)),
      ])),
      if (_lines.any((l) => l.aliadoMuestraSeccionFleteSeparado))
        _notice(
            'El flete se paga por separado al transportista. No está incluido en este comprobante.')
      else if (_lines.any((l) => l.hasExtraShippingCost))
        _notice(
            'Hay un cargo de envío informado en el pedido. Comprueba en la factura cómo debes pagarlo; no se suma automáticamente al importe de productos.')
      else if (_ref.customerPickup)
        _notice('Retiro en tienda sin costo de transporte.'),
      _notice(
          'Este pago corresponde únicamente a ${_ref.ownerBusinessName ?? 'este proveedor'}. Revisa que el importe coincida con su factura.'),
      if (_quote.methods.isEmpty)
        _notice(
            'El proveedor no tiene métodos compatibles con la moneda del pedido. Consúltalo antes de pagar.',
            warning: true),
    ];
  }

  static IconData _methodIcon(String method) => switch (method) {
        PagoMetodo.pagoMovil => Icons.phone_android_outlined,
        PagoMetodo.transferencia => Icons.account_balance_outlined,
        PagoMetodo.efectivo => Icons.payments_outlined,
        PagoMetodo.usdt => Icons.currency_exchange_outlined,
        _ => Icons.account_balance_wallet_outlined
      };
  static String _methodDescription(String method) => switch (method) {
        PagoMetodo.pagoMovil => 'Pago desde tu banco en bolívares.',
        PagoMetodo.transferencia =>
          'Transferencia desde tu cuenta en bolívares.',
        PagoMetodo.zelleDivisas => 'Pago en USD a la cuenta indicada.',
        PagoMetodo.usdt => 'Confirma la red y la dirección antes de enviar.',
        PagoMetodo.efectivo => 'Entrega según lo acordado con el proveedor.',
        _ => 'Sigue las instrucciones del proveedor.',
      };
  List<Widget> _methods() {
    final methods = _quote.methods;
    final locked = _reviewing && _hasSubmission;
    final details = _ref.pagoInstruccionesImportadorFor(_method)?.trim();
    return [
      _heading(_quote.bolivares
          ? '¿Cómo pagarás en bolívares?'
          : '¿Cómo pagarás en USD?'),
      for (final method in methods)
        Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
                color: _method == method
                    ? _theme.brandContainer
                    : _theme.surfaceCard,
                borderRadius: BorderRadius.circular(14),
                child: RadioListTile<String>(
                  value: method,
                  groupValue: _method,
                  activeColor: _accent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                          color: _method == method ? _blue : _theme.border)),
                  title: Row(children: [
                    Icon(_methodIcon(method),
                        color: _theme.textPrimary, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(PagoMetodo.labelEs(method),
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)))
                  ]),
                  subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(_methodDescription(method),
                          style: TextStyle(
                              fontSize: 12,
                              height: 1.35,
                              color: _theme.textSecondary))),
                  onChanged: locked
                      ? null
                      : (value) => setState(() {
                            _method = value;
                            _draftChanged();
                            _amount.clear();
                          }),
                ))),
      if (locked)
        _notice(
            'El comprobante está pendiente de revisión. Puedes corregirlo conservando el mismo método de pago.'),
      if (_method != null)
        _panel(
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Datos para ${PagoMetodo.labelEs(_method!)}',
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          if (details == null || details.isEmpty)
            const Text(
                'El proveedor aún no registró los datos de este método. Confírmalos por chat antes de pagar.')
          else ...[
            for (final item
                in details.split('\n').where((s) => s.trim().isNotEmpty))
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                    child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(item,
                            style:
                                const TextStyle(fontSize: 14, height: 1.4)))),
                IconButton(
                    tooltip: 'Copiar $item',
                    onPressed: () => _copy(item),
                    icon: const Icon(Icons.copy_outlined, size: 19)),
              ]),
            TextButton.icon(
                onPressed: () => _copy(details),
                icon: const Icon(Icons.copy_all_outlined, size: 18),
                label: const Text('Copiar todos los datos')),
          ],
        ])),
      _notice(_method == PagoMetodo.efectivo
          ? 'Entrega el efectivo según lo acordado con el proveedor. Luego registra el pago; la foto es opcional.'
          : 'Realiza el pago desde tu banco o aplicación y luego adjunta el comprobante. B2B Conecta no realiza la transferencia.'),
      if (_quote.payable == null)
        _notice(
            'Este pedido no tiene una tasa BCV aplicada. Consulta al proveedor antes de transferir.',
            warning: true),
    ];
  }

  void _copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Datos copiados.')));
  }

  List<Widget> _receipt() => [
        _heading(_method == PagoMetodo.efectivo
            ? 'Registra tu pago en efectivo'
            : 'Revisa tu comprobante'),
        if (_proof != null)
          _panel(Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
                width: 80,
                height: 110,
                child: _pdfUrl == null
                    ? SizedBox(
                        height: 110,
                        child: Image.memory(_proof!.bytes,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) =>
                                const Icon(Icons.image_outlined, size: 50)))
                    : Padding(
                        padding: const EdgeInsets.all(16),
                        child: Icon(Icons.picture_as_pdf_outlined,
                            size: 42, color: _accent))),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(_proof!.fileName,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(
                      _pdfUrl == null
                          ? 'Imagen adjunta · aún no enviada'
                          : 'PDF adjunto · aún no enviado',
                      style:
                          TextStyle(fontSize: 12, color: _theme.textSecondary)),
                  TextButton.icon(
                      onPressed: _showProof,
                      icon: const Icon(Icons.visibility_outlined, size: 18),
                      label: const Text('Revisar archivo')),
                ])),
          ])),
        if (!_uncertain)
          Wrap(spacing: 8, runSpacing: 6, children: [
            OutlinedButton.icon(
                onPressed:
                    _picking ? null : () => _pick(DocumentPickChannel.file),
                icon: const Icon(Icons.attach_file, size: 18),
                label: Text(_proof == null ? 'Adjuntar archivo' : 'Cambiar')),
            OutlinedButton.icon(
                onPressed:
                    _picking ? null : () => _pick(DocumentPickChannel.camera),
                icon: const Icon(Icons.photo_camera_outlined, size: 18),
                label: const Text('Cámara')),
            OutlinedButton.icon(
                onPressed:
                    _picking ? null : () => _pick(DocumentPickChannel.gallery),
                icon: const Icon(Icons.photo_library_outlined, size: 18),
                label: const Text('Galería')),
          ]),
        const SizedBox(height: 16),
        TextFormField(
            key: const ValueKey('payment-reference'),
            controller: _reference,
            readOnly: _uncertain,
            maxLength: 100,
            decoration: InputDecoration(
                labelText: _method == PagoMetodo.efectivo
                    ? 'Referencia (opcional)'
                    : 'Referencia de pago'),
            onChanged: (_) => _draftChanged(),
            validator: (value) =>
                _method != PagoMetodo.efectivo && (value ?? '').trim().isEmpty
                    ? 'Indica la referencia del pago.'
                    : null),
        const SizedBox(height: 10),
        OutlinedButton.icon(
            onPressed: _uncertain
                ? null
                : () async {
                    final date = await showDatePicker(
                        context: context,
                        initialDate: _paidOn,
                        firstDate: DateTime(2000),
                        lastDate: DateUtils.dateOnly(_now));
                    if (date != null && mounted) {
                      setState(() {
                        _paidOn = date;
                        _draftChanged();
                      });
                    }
                  },
            icon: const Icon(Icons.calendar_today_outlined, size: 18),
            label: Text('Fecha del pago: ${formatEsShortDate(_paidOn)}')),
        const SizedBox(height: 12),
        TextFormField(
            key: const ValueKey('payment-amount'),
            controller: _amount,
            readOnly: _uncertain,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
                labelText: 'Monto pagado (${_quote.bolivares ? 'Bs' : 'USD'})',
                helperMaxLines: 3,
                helperText:
                    'Indica lo que pagaste. Este dato no cambia el importe del pedido.'),
            onChanged: (_) {
              _draftChanged();
              setState(() {});
            },
            validator: (value) => parseDeclaredPaymentAmount(value ?? '') ==
                    null
                ? 'Ingresa un monto mayor que cero, con hasta dos decimales.'
                : null),
        const SizedBox(height: 12),
        _row('Método de pago', PagoMetodo.labelEs(_method!)),
        if (parseDeclaredPaymentAmount(_amount.text) != null &&
            _quote.payable != null &&
            (parseDeclaredPaymentAmount(_amount.text)! - _quote.payable!)
                    .abs() >
                .009)
          _notice(
              'El monto declarado difiere del importe del pedido. El proveedor deberá revisar la diferencia.',
              warning: true),
        ExpansionTile(
            title: const Text('Agregar una nota'),
            tilePadding: EdgeInsets.zero,
            children: [
              TextFormField(
                  key: const ValueKey('payment-note'),
                  controller: _note,
                  readOnly: _uncertain,
                  maxLines: 3,
                  maxLength: 1000,
                  decoration: const InputDecoration(
                      labelText: 'Nota para el proveedor'),
                  onChanged: (_) => _draftChanged())
            ]),
        _notice(_method == PagoMetodo.efectivo
            ? 'La foto es opcional. El proveedor confirmará cuando reciba el efectivo.'
            : 'Revisa el archivo, la referencia y el monto antes de enviarlos. Adjuntar un archivo no confirma el pago.'),
      ];
  List<Widget> _state() {
    final confirmed = _status == 'Pago confirmado';
    final rejected = _status == 'Comprobante rechazado' && !_submitted;
    final submitted = _submitted || _hasSubmission;
    final declaration = _submitted
        ? {
            'reference': _reference.text,
            'paid_on': formatEsShortDate(_paidOn),
            'amount': parseDeclaredPaymentAmount(_amount.text),
            'currency': _quote.currency,
            'note': _note.text
          }
        : _ref.pagoDeclaracion;
    final status = confirmed
        ? 'Pago confirmado'
        : rejected
            ? 'Comprobante rechazado'
            : submitted
                ? 'Pendiente de revisión'
                : _status;
    return [
      Center(
          child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Icon(
                  confirmed
                      ? Icons.check_circle_outline
                      : rejected
                          ? Icons.error_outline
                          : Icons.upload_file_outlined,
                  size: 68,
                  color: confirmed
                      ? _success
                      : rejected
                          ? _theme.warningFg
                          : _accent))),
      Center(
          child: Text(
              confirmed
                  ? 'Tu pago fue confirmado'
                  : rejected
                      ? 'Revisa tu comprobante'
                      : submitted
                          ? (_method == PagoMetodo.efectivo
                              ? 'Pago en efectivo registrado'
                              : 'Comprobante enviado')
                          : 'Estado del pago',
              style: TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                  color: confirmed ? _success : _theme.textPrimary),
              textAlign: TextAlign.center)),
      const SizedBox(height: 8),
      Center(
          child: Text(
              confirmed
                  ? 'El proveedor confirmó la recepción.'
                  : rejected
                      ? 'Consulta el motivo y corrige los datos.'
                      : 'El proveedor debe verificar que recibió tu pago.',
              textAlign: TextAlign.center)),
      const SizedBox(height: 14),
      Center(
          child: Chip(
              label: Text(status),
              labelStyle: confirmed
                  ? TextStyle(color: _success, fontWeight: FontWeight.w600)
                  : null,
              side: confirmed
                  ? BorderSide(color: _success.withOpacity(.24))
                  : null,
              backgroundColor:
                  confirmed ? _theme.successBg : _theme.warningBg)),
      const SizedBox(height: 12),
      _panel(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(_ref.proveedorFacturaFileName ?? 'Pago al proveedor',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        _row('Importe del pedido', _money(_quote.payable)),
        if (declaration['amount'] is num)
          _row(
              'Monto declarado',
              _money((declaration['amount'] as num).toDouble(),
                  currency: declaration['currency'] as String?)),
        if ((declaration['reference'] as String? ?? '').isNotEmpty)
          _row('Referencia', declaration['reference'].toString()),
        if (declaration['paid_on'] != null)
          _row('Fecha del pago', declaration['paid_on'].toString()),
        if (_method != null) _row('Método', PagoMetodo.labelEs(_method!)),
        if ((declaration['note'] as String? ?? '').isNotEmpty)
          _row('Nota', declaration['note'].toString()),
        if (_ref.hasComprobantePago)
          OutlinedButton.icon(
              onPressed: () => _file(_ref, proof: true),
              icon: const Icon(Icons.receipt_long_outlined, size: 18),
              label: const Text('Ver comprobante')),
      ])),
      _panel(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _timeline(
            _method == PagoMetodo.efectivo
                ? 'Pago declarado'
                : 'Comprobante registrado',
            submitted,
            _ref.comprobantePagoSubmittedAt == null
                ? null
                : formatEsShortDateTime(_ref.comprobantePagoSubmittedAt),
            connected: true,
            completedConnection: confirmed || rejected),
        _timeline(
            rejected ? 'Revisión rechazada' : 'Revisión del proveedor',
            confirmed || rejected,
            confirmed
                ? 'El proveedor completó la revisión.'
                : rejected
                    ? 'Necesita una corrección.'
                    : 'Pendiente de que el proveedor confirme.',
            connected: true,
            completedConnection: confirmed,
            attention: rejected),
        _timeline(
            'Pago confirmado',
            confirmed,
            _ref.pagoAprobadoAt == null
                ? 'Aparecerá cuando el proveedor lo confirme.'
                : formatEsShortDateTime(_ref.pagoAprobadoAt)),
      ])),
      if (rejected)
        _notice(
            _ref.pagoComprobanteRechazoNota?.trim().isNotEmpty == true
                ? _ref.pagoComprobanteRechazoNota!
                : 'El proveedor rechazó el comprobante. Corrígelo o consulta por chat.',
            warning: true),
      if (widget.loadLines != null)
        OutlinedButton.icon(
            onPressed: _refreshing ? null : _refresh,
            icon: const Icon(Icons.refresh),
            label: Text(_refreshing ? 'Actualizando…' : 'Actualizar estado')),
      if (_canEdit)
        TextButton(
            onPressed: _loadFailed || _refreshing
                ? null
                : () {
                    setState(() {
                      _submitted = false;
                      _submissionId = null;
                    });
                    _go(1);
                  },
            child: Text(rejected
                ? 'Corregir comprobante'
                : 'Corregir datos o comprobante')),
      _notice(
          'Enviar el comprobante no confirma el pago. El estado cambia cuando el proveedor lo aprueba o rechaza.'),
    ];
  }

  Widget _timeline(String title, bool done, String? subtitle,
          {bool connected = false,
          bool completedConnection = false,
          bool attention = false}) =>
      IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
            width: 22,
            child: Column(children: [
              Icon(
                  attention
                      ? Icons.error_outline
                      : done
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                  color: attention
                      ? _theme.warningFg
                      : done
                          ? _accent
                          : _theme.textSecondary,
                  size: 22),
              if (connected)
                Expanded(
                    child: Center(
                        child: Container(
                            width: 2,
                            margin: const EdgeInsets.symmetric(vertical: 3),
                            color: completedConnection
                                ? _accent
                                : _theme.border))),
            ])),
        const SizedBox(width: 10),
        Expanded(
            child: Padding(
                padding: EdgeInsets.only(bottom: connected ? 22 : 0),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      if (subtitle != null)
                        Text(subtitle,
                            style: TextStyle(
                                fontSize: 12,
                                height: 1.35,
                                color: _theme.textSecondary))
                    ])))
      ]));
  Future<void> _back() async {
    if (_sending) return;
    if (_step == 1) {
      _go(0);
      return;
    }
    if (_step == 2 && !_uncertain) {
      _go(1);
      return;
    }
    if ((_proof != null || _uncertain) && !_submitted && _step != 3) {
      final leave = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
                  title: const Text('¿Salir sin enviar?'),
                  content: Text(_uncertain
                      ? 'La confirmación del envío no llegó. Al volver al pedido podrás consultar si quedó registrado.'
                      : 'El archivo y los datos que preparaste aún no se han enviado.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Seguir revisando')),
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Salir'))
                  ]));
      if (leave != true || !mounted) return;
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final desktop =
        MediaQuery.sizeOf(context).width >= AppBreakpoints.mobileMenu;
    final title = [
      'Pago y factura',
      'Método de pago',
      'Comprobante de pago',
      'Estado del pago'
    ][_step];
    final body = switch (_step) {
      0 => _invoice(),
      1 => _methods(),
      2 => _receipt(),
      _ => _state()
    };
    final busy = _sending || _refreshing || _picking || (_loadFailed && _step < 3);
    final VoidCallback? primaryAction = busy
        ? null
        : switch (_step) {
            0 when _canEdit && _quote.methods.isNotEmpty => () => _go(1),
            0 when _hasSubmission => () => _go(3),
            1 when _method != null && _quote.payable != null => () {
                if (_amount.text.isEmpty) {
                  _amount.text = _quote.payable!.toStringAsFixed(2);
                }
                _go(2);
              },
            2 => _send,
            3 => () => Navigator.pop(context),
            _ => null,
          };
    return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _back();
        },
        child: Scaffold(
          backgroundColor: _theme.background,
          appBar: desktop
              ? desktopWorkflowAppBar(context, title, onBack: _back)
              : AppBar(
                  backgroundColor: _blue,
                  foregroundColor: Colors.white,
                  surfaceTintColor: Colors.transparent,
                  toolbarHeight:
                      MediaQuery.textScalerOf(context).scale(18) > 23 ? 96 : 72,
                  shape: const RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.vertical(bottom: Radius.circular(24))),
                  leading: BackButton(onPressed: _sending ? null : _back),
                  title: B2bHeaderTitle(
                    title: Text(title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700)),
                  )),
          body: SafeArea(
              top: false,
              child: DesktopWorkflow(
                body: RefreshIndicator(
                    onRefresh: _refresh,
                    child: SingleChildScrollView(
                        controller: _scroll,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                        child: AbsorbPointer(
                            absorbing: _sending || _refreshing,
                            child: Form(
                                key: _form,
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      if (_error != null)
                                        _notice(_error!, warning: true),
                                      if (_loadFailed)
                                        TextButton.icon(
                                            onPressed:
                                                _refreshing ? null : _refresh,
                                            icon: const Icon(Icons.refresh),
                                            label: const Text(
                                                'Reintentar actualización')),
                                      _supplier(),
                                      ...body,
                                      if (widget.onMessage != null)
                                        TextButton.icon(
                                            onPressed: widget.onMessage,
                                            icon: const Icon(
                                                Icons.chat_bubble_outline,
                                                size: 20),
                                            label: const Text(
                                                'Consultar al proveedor')),
                                    ]))))),
                actions: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                    child: SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                              backgroundColor: _blue,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(44, 48),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 13)),
                          onPressed: primaryAction,
                          child: Text(
                              _sending
                                  ? 'Enviando…'
                                  : _step == 0
                                      ? 'Ver métodos de pago'
                                      : _step == 1
                                          ? 'Ya pagué · Revisar comprobante'
                                          : _step == 2
                                              ? (_uncertain
                                                  ? 'Verificar envío'
                                                  : _method ==
                                                          PagoMetodo.efectivo
                                                      ? 'Registrar pago en efectivo'
                                                      : 'Enviar comprobante')
                                              : 'Volver al pedido',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: primaryAction == null
                                      ? _theme.textMuted
                                      : Colors.white,
                                  fontWeight: FontWeight.w700, fontSize: 15)),
                        ))),
              )),
        ));
  }
}
