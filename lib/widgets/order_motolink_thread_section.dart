import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/transaction_request_message_model.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_date_format.dart';
import 'main_shell_tab.dart';

/// Hilo de mensajes aliado ↔ MotoLink ↔ transportista (despacho) sobre un pedido.
class OrderMotolinkThreadSection extends StatefulWidget {
  const OrderMotolinkThreadSection({
    super.key,
    required this.transactionRequestId,
    required this.allowReplyAsAliado,
    required this.allowReplyAsAdmin,
    this.allowReplyAsTransportista = false,
    this.onThreadChanged,
    this.orderPrecioTotalUsd,
    this.creditPlanRescheduleLocked = false,
  });

  final String transactionRequestId;
  final bool allowReplyAsAliado;
  final bool allowReplyAsAdmin;

  /// Despacho asignado al pedido: puede leer y escribir en el mismo hilo que aliado y admin.
  final bool allowReplyAsTransportista;

  /// Nuevo mensaje (Realtime) u operaciones en el hilo: refresca la ficha del pedido (cuotas, cupo).
  final VoidCallback? onThreadChanged;

  /// Total del pedido para validar la suma de las cuotas (p. ej. [TransactionRequestModel.precioTotal]).
  final double? orderPrecioTotalUsd;

  /// Si [allowReplyAsAdmin] y el plan ya no puede redefinirse (p. ej. cuota 1 con comprobante).
  final bool creditPlanRescheduleLocked;

  @override
  State<OrderMotolinkThreadSection> createState() =>
      _OrderMotolinkThreadSectionState();
}

class _OrderMotolinkThreadSectionState extends State<OrderMotolinkThreadSection> {
  final _ctrl = TextEditingController();
  List<TransactionRequestMessageModel> _items = [];
  bool _loading = true;
  bool _sending = false;
  bool _savingPlan = false;
  String? _error;
  RealtimeChannel? _messagesChannel;

  @override
  void dispose() {
    SupabaseService.unsubscribeChannel(_messagesChannel);
    _ctrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    SupabaseService.markNotificationsReadForRelatedOrder(widget.transactionRequestId)
        .then((_) {
      // Evita setState del shell en el mismo frame que desmonta subárboles (p. ej. paso a tránsito).
      SchedulerBinding.instance.addPostFrameCallback((_) {
        MainShellTabController.requestNotificationsReload();
      });
    });
    _messagesChannel = SupabaseService.subscribeToTransactionRequestMessages(
      transactionRequestId: widget.transactionRequestId,
      onInsert: () {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _load();
            widget.onThreadChanged?.call();
          }
        });
      },
    );
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await SupabaseService.fetchTransactionRequestMessages(
        widget.transactionRequestId,
      );
      if (!mounted) return;
      setState(() {
        _items = list;
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

  List<double> _splitEqualCents(int n, double total) {
    if (n <= 0) return const [];
    final cents = (total * 100).round();
    final per = cents ~/ n;
    final rem = cents - per * n;
    return List<double>.generate(
      n,
      (i) => (per + (i < rem ? 1 : 0)) / 100.0,
    );
  }

  bool _montoCerca(double a, double b) => (a - b).abs() < 0.02;

  Future<void> _openPlanModal() async {
    if (_savingPlan) return;
    var orderTotal = widget.orderPrecioTotalUsd;
    orderTotal ??= await SupabaseService.fetchTransactionRequestPrecioTotal(
        widget.transactionRequestId,
      );
    if (orderTotal == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo leer el total del pedido.')),
      );
      return;
    }
    if (!mounted) return;
    final tPedido = orderTotal;

    int nCuotas = 1;
    final controllers = <TextEditingController>[];

    void setControllers() {
      for (final c in controllers) {
        c.dispose();
      }
      controllers.clear();
      for (final a in _splitEqualCents(nCuotas, tPedido)) {
        controllers.add(TextEditingController(text: a.toStringAsFixed(2)));
      }
    }

    setControllers();

    if (!mounted) return;
    final aceptar = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModal) {
            return AlertDialog(
              title: const Text('Ajustar plan de cuotas'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Vencimientos: cada 15 días a partir de hoy (zona Caracas). '
                      'Suma de cuotas debe ser ${tPedido.toStringAsFixed(2)} REF.',
                      style: const TextStyle(fontSize: 13, height: 1.3),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Total pedido: ${tPedido.toStringAsFixed(2)} REF',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: AppColors.brandBlue.withOpacity(0.95),
                      ),
                    ),
                    const SizedBox(height: 8),
                    RadioListTile<int>(
                      value: 1,
                      groupValue: nCuotas,
                      onChanged: (v) {
                        if (v == null) return;
                        nCuotas = v;
                        setControllers();
                        setModal(() {});
                      },
                      title: const Text('1 cuota (contado)'),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    RadioListTile<int>(
                      value: 2,
                      groupValue: nCuotas,
                      onChanged: (v) {
                        if (v == null) return;
                        nCuotas = v;
                        setControllers();
                        setModal(() {});
                      },
                      title: const Text('2 cuotas (cada 15 días)'),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    RadioListTile<int>(
                      value: 3,
                      groupValue: nCuotas,
                      onChanged: (v) {
                        if (v == null) return;
                        nCuotas = v;
                        setControllers();
                        setModal(() {});
                      },
                      title: const Text('3 cuotas (cada 15 días, máx. 45 días)'),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 8),
                    for (var i = 0; i < controllers.length; i++) ...[
                      TextField(
                        key: ObjectKey(controllers[i]),
                        controller: controllers[i],
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Cuota ${i + 1} (REF)',
                          isDense: true,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () {
                    var suma = 0.0;
                    for (final c in controllers) {
                      final t = c.text.trim().replaceAll(',', '.');
                      final x = double.tryParse(t);
                      if (x == null || x < 0) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                            content: Text('Revise que cada monto sea un número válido.'),
                          ),
                        );
                        return;
                      }
                      suma += x;
                    }
                    if (!_montoCerca(suma, tPedido)) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(
                          content: Text(
                            'La suma (${suma.toStringAsFixed(2)} REF) debe coincidir con el total (${tPedido.toStringAsFixed(2)} REF).',
                          ),
                        ),
                      );
                      return;
                    }
                    Navigator.of(ctx).pop(true);
                  },
                  child: const Text('Validar y confirmar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (aceptar != true) {
      for (final c in controllers) {
        c.dispose();
      }
      return;
    }
    final eq = _splitEqualCents(nCuotas, tPedido);
    final amounts = <double>[];
    var personalizado = false;
    for (var i = 0; i < nCuotas; i++) {
      final t = controllers[i].text.trim().replaceAll(',', '.');
      final x = double.tryParse(t);
      if (x == null) {
        for (final c in controllers) {
          c.dispose();
        }
        return;
      }
      amounts.add(x);
      if (i < eq.length && !_montoCerca(x, eq[i])) {
        personalizado = true;
      }
    }
    for (final c in controllers) {
      c.dispose();
    }

    if (!mounted) return;
    setState(() => _savingPlan = true);
    try {
      await SupabaseService.confirmOrderCreditPlan(
        transactionRequestId: widget.transactionRequestId,
        amountsUsd: amounts,
        montosPersonalizados: personalizado,
      );
      if (!mounted) return;
      await _load();
      widget.onThreadChanged?.call();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Plan de cuotas registrado. El aliado lo verá al instante.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final s = e.toString();
      var friendly = s;
      if (s.contains('CUPO_INSUFICIENTE') || s.contains('cupo disponible')) {
        friendly =
            'Cupo del aliado insuficiente. Revise límites, pedidos abiertos o cuotas ya aprobadas.';
      } else if (s.contains('MONTOS_NO_COINCIDEN')) {
        friendly = 'La suma de las cuotas no coincide con el total; verifique e intente de nuevo.';
      } else if (s.contains('PLAN_CUOTAS_BLOQUEADO')) {
        friendly =
            'El plan no puede cambiarse: la primera cuota ya tiene comprobante o registro de pago.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo registrar el plan: $friendly')),
      );
    } finally {
      if (mounted) setState(() => _savingPlan = false);
    }
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    try {
      if (widget.allowReplyAsAliado) {
        await SupabaseService.insertTransactionRequestMessageAsAliado(
          transactionRequestId: widget.transactionRequestId,
          body: text,
        );
      } else if (widget.allowReplyAsAdmin) {
        await SupabaseService.insertTransactionRequestMessageAsAdmin(
          transactionRequestId: widget.transactionRequestId,
          body: text,
        );
      } else if (widget.allowReplyAsTransportista) {
        await SupabaseService.insertTransactionRequestMessageAsTransportista(
          transactionRequestId: widget.transactionRequestId,
          body: text,
        );
      }
      _ctrl.clear();
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo enviar: $e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = SupabaseService.currentUserId;
    final canReply = widget.allowReplyAsAliado ||
        widget.allowReplyAsAdmin ||
        widget.allowReplyAsTransportista;
    final transportistaOnlyTitle = widget.allowReplyAsTransportista &&
        !widget.allowReplyAsAliado &&
        !widget.allowReplyAsAdmin;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                transportistaOnlyTitle
                    ? 'Mensajes del pedido'
                    : 'Consultas a MotoLink',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            if (widget.allowReplyAsAdmin) ...[
              IconButton(
                tooltip: widget.creditPlanRescheduleLocked
                    ? 'No se puede modificar: la primera cuota ya tiene comprobante o registro de pago.'
                    : 'Ajustar plan de cuotas',
                onPressed: _loading ||
                        _savingPlan ||
                        widget.creditPlanRescheduleLocked
                    ? null
                    : _openPlanModal,
                icon: const Icon(Icons.payments_outlined, size: 22),
                visualDensity: VisualDensity.compact,
              ),
            ],
            IconButton(
              tooltip: 'Actualizar',
              onPressed: _loading || _savingPlan ? null : _load,
              icon: const Icon(Icons.refresh, size: 20),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else if (_error != null)
          Text(_error!, style: TextStyle(fontSize: 12, color: Colors.red.shade800))
        else if (_items.isEmpty)
          Text(
            canReply
                ? 'Aún no hay mensajes. Escriba aquí si tiene dudas sobre este pedido.'
                : 'Sin mensajes en este pedido.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final m = _items[i];
              final mine = uid != null && m.authorId == uid;
              final label = mine
                  ? 'Tú'
                  : (m.isFromAdmin
                      ? 'MotoLink'
                      : (m.isFromTransportista
                          ? 'Transportista'
                          : 'Aliado'));
              final align =
                  mine ? CrossAxisAlignment.end : CrossAxisAlignment.start;
              final bg = m.isFromAdmin
                  ? AppColors.surfaceTinted.withOpacity(0.55)
                  : (m.isFromTransportista
                      ? Colors.teal.shade50
                      : (mine
                          ? AppColors.brandBlue.withOpacity(0.12)
                          : Colors.grey.shade200));

              return Column(
                crossAxisAlignment: align,
                children: [
                  Text(
                    '$label · ${formatEsShortDateTime(m.createdAt)}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                      child: Text(
                        m.body,
                        style: const TextStyle(fontSize: 13, height: 1.35),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        if (canReply) ...[
          const SizedBox(height: 10),
          TextField(
            controller: _ctrl,
            minLines: 1,
            maxLines: 4,
            textInputAction: TextInputAction.newline,
            decoration: InputDecoration(
              hintText: widget.allowReplyAsAdmin
                  ? 'Respuesta al aliado…'
                  : widget.allowReplyAsTransportista
                      ? 'Mensaje a MotoLink y aliado…'
                      : 'Escriba a MotoLink…',
              isDense: true,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: _sending ? null : _send,
              child: _sending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Enviar'),
            ),
          ),
        ],
      ],
    );
  }
}
