import 'dart:async';
import 'package:flutter/material.dart';
import '../../../app/theme/b2b_theme_extension.dart';
import 'orders_service.dart';
import 'transaction_request_model.dart';

/// Case status comes from stored resolutions, never from a simulated review step.
String mobilePostventaStatus(List<Map<String, dynamic>> cases) {
  if (cases.isEmpty) return 'Reporte registrado';
  String resolution(Map<String, dynamic> row) => row['status'] == 'rechazada'
      ? 'rechazo'
      : row['resolution']?.toString() ?? '';
  final pending = cases.where((row) => resolution(row).isEmpty).length;
  if (pending == cases.length) return 'Pendiente de acuerdo';
  if (pending > 0) {
    final resolved = cases.length - pending;
    return '$pending ${pending == 1 ? 'pendiente' : 'pendientes'} · $resolved ${resolved == 1 ? 'resuelto' : 'resueltos'}';
  }
  final resolutions = cases.map(resolution).toSet();
  if (resolutions.length > 1) return 'Acuerdos registrados';
  return switch (resolutions.single) {
    'cambio' => 'Cambio aprobado',
    'credito' => 'Crédito aprobado',
    'rechazo' => 'Reporte no aceptado',
    _ => 'Acuerdo registrado',
  };
}

class MobilePostventaContext extends StatefulWidget {
  const MobilePostventaContext(
      {super.key,
      required this.lines,
      this.revision = 0,
      this.loadCases,
      this.refreshInterval = const Duration(seconds: 30)});
  final List<TransactionRequestModel> lines;
  final int revision;
  final Future<List<Map<String, dynamic>>> Function()? loadCases;
  final Duration? refreshInterval;
  @override
  State<MobilePostventaContext> createState() => _MobilePostventaContextState();
}

class _MobilePostventaContextState extends State<MobilePostventaContext>
    with WidgetsBindingObserver {
  List<Map<String, dynamic>> _cases = [];
  bool _loading = true, _failed = false;
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    if (widget.refreshInterval != null) {
      _timer = Timer.periodic(widget.refreshInterval!, (_) {
        if (ModalRoute.of(context)?.isCurrent != false) _load();
      });
    }
  }

  @override
  void didUpdateWidget(covariant MobilePostventaContext oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.revision != widget.revision) _load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  bool _busy = false;
  Future<void> _load() async {
    if (_busy) return;
    _busy = true;
    try {
      final cases = widget.loadCases != null
          ? await widget.loadCases!()
          : (await Future.wait(widget.lines.map((line) =>
                  OrdersService.fetchOrderPostventaCaso(
                      transactionRequestId: line.id, kind: 'devolucion'))))
              .whereType<Map<String, dynamic>>()
              .toList();
      if (mounted) {
        setState(() {
          _cases = cases;
          _loading = false;
          _failed = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final status = _loading
        ? 'Consultando estado…'
        : _failed
            ? 'Estado sin actualizar'
            : mobilePostventaStatus(_cases);
    final approved = !_failed &&
        _cases.isNotEmpty &&
        _cases.every((row) =>
            row['status'] != 'rechazada' &&
            (row['resolution'] == 'cambio' || row['resolution'] == 'credito'));
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      color: theme.background,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('Reporte del pedido',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                      color: approved ? theme.successBg : theme.warningBg,
                      borderRadius: BorderRadius.circular(16)),
                  child: Text(status,
                      style:
                          TextStyle(fontSize: 12, color: theme.textPrimary))),
              if (_failed)
                TextButton(onPressed: _load, child: const Text('Actualizar')),
            ]),
        const SizedBox(height: 7),
        Text(
            'La solución se acuerda con el proveedor: cambio de producto o crédito a favor.',
            style: TextStyle(
                fontSize: 12, height: 1.3, color: theme.textSecondary)),
      ]),
    );
  }
}
