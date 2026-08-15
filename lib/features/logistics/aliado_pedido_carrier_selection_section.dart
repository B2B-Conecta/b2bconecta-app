import 'package:flutter/material.dart';

import 'importer_carrier_model.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_model.dart';
import 'carrier_decision.dart';
import 'carrier_flete_pago_modo.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_status.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'carrier_eta_format.dart';
import 'package:motolink_pro_app/features/orders/shared/order_pickup_flow_copy.dart';
import 'package:motolink_pro_app/features/orders/shared/b2b_orders_panel_layout.dart';
import 'package:motolink_pro_app/features/orders/shared/b2b_order_panel_widgets.dart';
import 'importer_carrier_form.dart';

/// Aliado: elegir transportista cuando el pedido está listo para despacho.
class AliadoPedidoCarrierSelectionSection extends StatefulWidget {
  const AliadoPedidoCarrierSelectionSection({
    super.key,
    required this.request,
    required this.onChanged,
  });

  final TransactionRequestModel request;
  final VoidCallback onChanged;

  @override
  State<AliadoPedidoCarrierSelectionSection> createState() =>
      _AliadoPedidoCarrierSelectionSectionState();
}

class _AliadoPedidoCarrierSelectionSectionState
    extends State<AliadoPedidoCarrierSelectionSection> {
  bool _loading = true;
  bool _hasCarriers = false;
  List<ImporterCarrierModel> _carriers = [];
  String? _error;
  bool _selecting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant AliadoPedidoCarrierSelectionSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.request.id != widget.request.id ||
        oldWidget.request.status != widget.request.status ||
        oldWidget.request.carrierDecision != widget.request.carrierDecision ||
        oldWidget.request.importerCarrierId != widget.request.importerCarrierId) {
      _load();
    }
  }

  Future<void> _load() async {
    final r = widget.request;
    final shouldQuery = r.status == TransactionRequestStatus.pedidoListo &&
        (r.carrierDecision == CarrierDecision.pending ||
            r.carrierDecision == CarrierDecision.notApplicable);

    if (!shouldQuery) {
      setState(() {
        _loading = false;
        _hasCarriers = false;
        _carriers = [];
      });
      return;
    }

    final wasNotApplicable =
        r.carrierDecision == CarrierDecision.notApplicable;

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await SupabaseService.listImporterCarriersForPedido(
        widget.request.id,
      );
      if (!mounted) return;
      setState(() {
        _carriers = rows;
        _hasCarriers = rows.isNotEmpty;
        _loading = false;
      });
      if (wasNotApplicable && rows.isNotEmpty) {
        widget.onChanged();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
        _hasCarriers = false;
      });
    }
  }

  Future<void> _openPicker() async {
    if (_carriers.isEmpty) return;
    final picked = await showModalBottomSheet<_CarrierPickResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _CarrierPickerSheet(
        carriers: _carriers,
        selectedCarrierId: widget.request.importerCarrierId,
        selectedDriverId: widget.request.importerCarrierDriverId,
      ),
    );
    if (picked == null) return;

    setState(() => _selecting = true);
    try {
      await SupabaseService.aliadoSelectCarrierForPedido(
        requestId: widget.request.id,
        carrierId: picked.carrierId,
        driverId: picked.driverId,
        fletePagoModo: picked.fletePagoModo,
      );
      if (!mounted) return;
      widget.onChanged();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transportista elegido. El importador verá su selección.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    } finally {
      if (mounted) setState(() => _selecting = false);
    }
  }

  Future<void> _skipCarrier() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(OrderPickupFlowCopy.aliadoSkipDialogTitulo),
        content: const Text(OrderPickupFlowCopy.aliadoSkipDialogCuerpo),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _selecting = true);
    try {
      await SupabaseService.aliadoSkipCarrierForPedido(
        requestId: widget.request.id,
      );
      if (!mounted) return;
      widget.onChanged();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(OrderPickupFlowCopy.aliadoSkipExito),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    } finally {
      if (mounted) setState(() => _selecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    if (r.status != TransactionRequestStatus.pedidoListo) {
      return const SizedBox.shrink();
    }

    if (r.carrierDecision == CarrierDecision.skipped) {
      return B2bPanelSectionCard(
        tint: Colors.blueGrey.shade50,
        icon: Icons.storefront_outlined,
        title: OrderPickupFlowCopy.aliadoEntregaPropiaTitulo,
        subtitle: OrderPickupFlowCopy.aliadoEntregaPropiaCuerpo,
      );
    }

    if (r.carrierDecision == CarrierDecision.selected &&
        r.hasImporterCarrierSelected) {
      return _buildSelectedCarrierCard(r, allowChange: false);
    }

    final awaitingCarrierChoice = r.status == TransactionRequestStatus.pedidoListo &&
        (r.carrierDecision == CarrierDecision.pending ||
            r.carrierDecision == CarrierDecision.notApplicable);

    if (!awaitingCarrierChoice) {
      return const SizedBox.shrink();
    }
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (!_hasCarriers) {
      if (r.carrierDecision == CarrierDecision.notApplicable) {
        return const SizedBox.shrink();
      }
      return _buildEmptyCarriersCard();
    }

    final selected = r.hasImporterCarrierSelected;

    return _buildSelectedCarrierCard(r, allowChange: true, selected: selected);
  }

  Widget _buildEmptyCarriersCard() {
    return B2bPanelSectionCard(
      tint: Colors.amber.shade50,
      icon: Icons.local_shipping_outlined,
      title: OrderPickupFlowCopy.aliadoSinTransportistasElegiblesTitulo,
      subtitle: OrderPickupFlowCopy.aliadoSinTransportistasElegiblesCuerpo,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) ...[
            Text(_error!, style: TextStyle(color: Colors.red.shade700, fontSize: 12)),
            const SizedBox(height: 8),
          ],
          OutlinedButton.icon(
            onPressed: _selecting ? null : _skipCarrier,
            style: OutlinedButton.styleFrom(
              minimumSize: b2bActionButtonMinSize(context),
            ),
            icon: const Icon(Icons.storefront_outlined),
            label: const Text(OrderPickupFlowCopy.aliadoSkipBoton),
          ),
        ],
      ),
    );
  }

  Widget _buildCarrierChoiceActions({required bool selected}) {
    final density = B2bOrderCardDensityScope.of(context);
    final outlinedStyle = OutlinedButton.styleFrom(
      minimumSize: density.actionButtonMinSize,
      padding: density.buttonPadding,
      textStyle: TextStyle(fontSize: density.buttonTextSize),
      visualDensity: density.buttonVisualDensity,
    );
    final filledStyle = FilledButton.styleFrom(
      backgroundColor: AppColors.brandBlue,
      minimumSize: density.actionButtonMinSize,
      padding: density.buttonPadding,
      textStyle: TextStyle(fontSize: density.buttonTextSize),
      visualDensity: density.buttonVisualDensity,
    );

    return B2bActionButtonRow(
      secondary: OutlinedButton.icon(
        onPressed: _selecting ? null : _skipCarrier,
        style: outlinedStyle,
        icon: const Icon(Icons.storefront_outlined),
        label: const Text(OrderPickupFlowCopy.aliadoSkipBoton),
      ),
      primary: FilledButton.icon(
        onPressed: _selecting ? null : _openPicker,
        style: filledStyle,
        icon: _selecting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(selected ? Icons.swap_horiz : Icons.local_shipping_outlined),
        label: Text(
          selected
              ? OrderPickupFlowCopy.aliadoCambiarTransportista
              : OrderPickupFlowCopy.aliadoElegirTransportista,
        ),
      ),
    );
  }

  Widget _buildSelectedCarrierCard(
    TransactionRequestModel r, {
    required bool allowChange,
    bool selected = true,
  }) {
    return B2bPanelSectionCard(
      tint: Colors.teal.shade50,
      icon: Icons.local_shipping_outlined,
      title: selected
          ? OrderPickupFlowCopy.aliadoTransporteElegidoTitulo
          : OrderPickupFlowCopy.aliadoTransporteTitulo,
      subtitle: selected
          ? OrderPickupFlowCopy.aliadoTransporteElegidoCuerpo(
              r.carrierDisplayCompanyName,
            )
          : OrderPickupFlowCopy.aliadoTransporteIntro,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) ...[
            Text(_error!, style: TextStyle(color: Colors.red.shade700, fontSize: 12)),
            const SizedBox(height: 8),
          ],
          if (selected) ...[
            Text(
              r.carrierCompanyName ?? 'Transportista',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            if (r.carrierFletePagoModoSnapshot != null) ...[
              const SizedBox(height: 4),
              Text(
                CarrierFletePagoModo.labelEs(r.carrierFletePagoModoSnapshot),
                style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
              ),
            ],
            if (r.carrierFeeUsdSnapshot != null) ...[
              const SizedBox(height: 4),
              Text(
                'Flete estimado: ${CarrierEtaFormat.feeLabel(r.carrierFeeUsdSnapshot)}',
                style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
              ),
            ],
            const SizedBox(height: 6),
            Text(
              OrderPickupFlowCopy.aliadoTransportePendienteFactura,
              style: TextStyle(
                fontSize: 12,
                height: 1.35,
                color: Colors.teal.shade900.withOpacity(0.85),
              ),
            ),
          ],
          if (allowChange) ...[
            if (selected) const SizedBox(height: 10),
            if (!selected)
              _buildCarrierChoiceActions(selected: selected)
            else
              FilledButton.icon(
                onPressed: _selecting ? null : _openPicker,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.brandBlue,
                ),
                icon: _selecting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.swap_horiz),
                label: const Text(OrderPickupFlowCopy.aliadoCambiarTransportista),
              ),
          ],
        ],
      ),
    );
  }
}

class _CarrierPickResult {
  const _CarrierPickResult({
    required this.carrierId,
    this.driverId,
    required this.fletePagoModo,
  });
  final String carrierId;
  final String? driverId;
  final String fletePagoModo;
}

class _CarrierPickerSheet extends StatefulWidget {
  const _CarrierPickerSheet({
    required this.carriers,
    this.selectedCarrierId,
    this.selectedDriverId,
  });

  final List<ImporterCarrierModel> carriers;
  final String? selectedCarrierId;
  final String? selectedDriverId;

  @override
  State<_CarrierPickerSheet> createState() => _CarrierPickerSheetState();
}

class _CarrierPickerSheetState extends State<_CarrierPickerSheet> {
  String? _carrierId;
  String? _driverId;
  late String _fletePagoModo;

  ImporterCarrierModel? get _selectedCarrier {
    if (_carrierId == null) return null;
    for (final c in widget.carriers) {
      if (c.id == _carrierId) return c;
    }
    return null;
  }

  void _syncFleteModoFromCarrier() {
    final carrier = _selectedCarrier;
    if (carrier == null) return;
    _fletePagoModo = carrier.fletePagoModo;
  }

  @override
  void initState() {
    super.initState();
    _carrierId = widget.selectedCarrierId;
    _driverId = widget.selectedDriverId;
    _fletePagoModo = CarrierFletePagoModo.incluidoFactura;
    if (_carrierId != null) _syncFleteModoFromCarrier();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Transportistas del importador',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  for (final carrier in widget.carriers) ...[
                    _CarrierOptionCard(
                      carrier: carrier,
                      selected: carrier.id == _carrierId,
                      selectedDriverId: carrier.id == _carrierId ? _driverId : null,
                      onTap: () => setState(() {
                        _carrierId = carrier.id;
                        _driverId = null;
                        _syncFleteModoFromCarrier();
                      }),
                      onDriverChanged: (driverId) =>
                          setState(() => _driverId = driverId),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
          ),
          if (_carrierId != null) ...[
            const SizedBox(height: 12),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                OrderPickupFlowCopy.aliadoFleteFacturaTitulo,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              OrderPickupFlowCopy.aliadoFleteFacturaIntro,
              style: TextStyle(fontSize: 12.5, height: 1.35),
            ),
            const SizedBox(height: 8),
            RadioListTile<String>(
              value: CarrierFletePagoModo.incluidoFactura,
              groupValue: _fletePagoModo,
              onChanged: (v) => setState(() => _fletePagoModo = v!),
              contentPadding: EdgeInsets.zero,
              title: const Text(OrderPickupFlowCopy.aliadoFleteIncluidoTitulo),
              subtitle: const Text(OrderPickupFlowCopy.aliadoFleteIncluidoCuerpo),
            ),
            RadioListTile<String>(
              value: CarrierFletePagoModo.pagoSeparado,
              groupValue: _fletePagoModo,
              onChanged: (v) => setState(() => _fletePagoModo = v!),
              contentPadding: EdgeInsets.zero,
              title: const Text(OrderPickupFlowCopy.aliadoFleteSeparadoTitulo),
              subtitle: const Text(OrderPickupFlowCopy.aliadoFleteSeparadoCuerpo),
            ),
          ],
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _carrierId == null
                ? null
                : () => Navigator.pop(
                      context,
                      _CarrierPickResult(
                        carrierId: _carrierId!,
                        driverId: _driverId,
                        fletePagoModo: _fletePagoModo,
                      ),
                    ),
            style: FilledButton.styleFrom(backgroundColor: AppColors.brand),
            child: const Text('Usar este transportista'),
          ),
        ],
      ),
    );
  }
}

class _CarrierOptionCard extends StatelessWidget {
  const _CarrierOptionCard({
    required this.carrier,
    required this.selected,
    required this.selectedDriverId,
    required this.onTap,
    required this.onDriverChanged,
  });

  final ImporterCarrierModel carrier;
  final bool selected;
  final String? selectedDriverId;
  final VoidCallback onTap;
  final ValueChanged<String?> onDriverChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.brand : AppColors.borderSubtle,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                carrier.companyName,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              if (!carrier.coversDestination) ...[
                const SizedBox(height: 4),
                Text(
                  'Cobertura no confirmada para su dirección',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.amber.shade900,
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                CarrierFletePagoModo.shortLabelEs(carrier.fletePagoModo),
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  _miniChip(
                    Icons.schedule,
                    CarrierEtaFormat.etaLabel(carrier.etaHours),
                  ),
                  _miniChip(
                    Icons.route_outlined,
                    CarrierEtaFormat.distanceLabel(carrier.distanceKm),
                  ),
                  _miniChip(
                    Icons.payments_outlined,
                    CarrierEtaFormat.feeLabel(carrier.feeUsd),
                  ),
                ],
              ),
              if (selected) ...[
                const SizedBox(height: 8),
                CarrierPagoInstruccionesPanel(
                  metodos: carrier.acceptedPagoMetodos,
                  instrucciones: carrier.pagoMetodoInstrucciones,
                ),
                if (carrier.drivers.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String?>(
                    value: selectedDriverId,
                    decoration: const InputDecoration(
                      labelText: 'Conductor (opcional)',
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Sin preferencia'),
                      ),
                      ...carrier.drivers.map(
                        (d) => DropdownMenuItem<String?>(
                          value: d.id,
                          child: Text(d.driverName),
                        ),
                      ),
                    ],
                    onChanged: onDriverChanged,
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 11.5)),
      ],
    );
  }
}
