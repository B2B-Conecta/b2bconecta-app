import 'package:flutter/material.dart';

import '../models/importer_carrier_model.dart';
import '../models/transaction_request_model.dart';
import '../models/carrier_flete_pago_modo.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../utils/carrier_eta_format.dart';
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
        oldWidget.request.importerCarrierId != widget.request.importerCarrierId) {
      _load();
    }
  }

  Future<void> _load() async {
    if (!widget.request.aliadoPuedeElegirTransportista) {
      setState(() {
        _loading = false;
        _hasCarriers = false;
        _carriers = [];
      });
      return;
    }

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
      );
      if (!mounted) return;
      widget.onChanged();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transportista seleccionado.'),
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
    if (!widget.request.aliadoPuedeElegirTransportista) {
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
    if (!_hasCarriers) return const SizedBox.shrink();

    final r = widget.request;
    final selected = r.hasImporterCarrierSelected;

    return Material(
      color: Colors.teal.shade50,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.local_shipping_outlined, color: Colors.teal.shade800),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selected
                            ? 'Transportista seleccionado'
                            : 'Elija un transportista',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Colors.teal.shade900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        selected
                            ? 'El importador podrá despachar cuando adjunte la(s) factura(s) requerida(s).'
                            : 'El importador marcó el pedido listo. Seleccione quién entregará la mercancía.',
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.35,
                          color: Colors.teal.shade900.withOpacity(0.85),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: Colors.red.shade700, fontSize: 12)),
            ],
            if (selected) ...[
              const SizedBox(height: 10),
              Text(
                r.carrierCompanyName ?? 'Transportista',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              if (r.carrierFletePagoModoSnapshot != null) ...[
                const SizedBox(height: 4),
                Text(
                  CarrierFletePagoModo.labelEs(r.carrierFletePagoModoSnapshot),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
                ),
              ],
              if (r.carrierFeeUsdSnapshot != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Flete estimado: ${CarrierEtaFormat.feeLabel(r.carrierFeeUsdSnapshot)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
                ),
              ],
            ],
            const SizedBox(height: 10),
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
                  : Icon(selected ? Icons.swap_horiz : Icons.local_shipping_outlined),
              label: Text(selected ? 'Cambiar transportista' : 'Ver opciones'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CarrierPickResult {
  const _CarrierPickResult({required this.carrierId, this.driverId});
  final String carrierId;
  final String? driverId;
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

  @override
  void initState() {
    super.initState();
    _carrierId = widget.selectedCarrierId;
    _driverId = widget.selectedDriverId;
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
                  'Transportistas disponibles',
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
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _carrierId == null
                ? null
                : () => Navigator.pop(
                      context,
                      _CarrierPickResult(
                        carrierId: _carrierId!,
                        driverId: _driverId,
                      ),
                    ),
            style: FilledButton.styleFrom(backgroundColor: AppColors.brand),
            child: const Text('Confirmar transportista'),
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
            color: selected ? AppColors.brandOrange : Colors.grey.shade300,
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
              const SizedBox(height: 4),
              Text(
                CarrierFletePagoModo.shortLabelEs(carrier.fletePagoModo),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
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
