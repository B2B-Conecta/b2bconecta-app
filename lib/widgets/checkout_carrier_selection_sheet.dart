import 'package:flutter/material.dart';

import '../models/importer_carrier_model.dart';
import '../models/profile_model.dart';
import '../services/cart_service.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../utils/carrier_eta_format.dart';
import 'importer_carrier_form.dart';

/// Destino de entrega para calcular ETA de transportistas.
class CheckoutDestinoInfo {
  const CheckoutDestinoInfo({
    required this.useProfile,
    this.texto,
    this.mapsUrl,
  });

  final bool useProfile;
  final String? texto;
  final String? mapsUrl;
}

/// Selección de transportista por importador durante el checkout.
class CheckoutCarrierSelectionSheet extends StatefulWidget {
  const CheckoutCarrierSelectionSheet({
    super.key,
    required this.profile,
    required this.destino,
    required this.importadorIds,
    required this.importadorNameFor,
  });

  final ProfileModel profile;
  final CheckoutDestinoInfo destino;
  final List<String> importadorIds;
  final String Function(String importadorId) importadorNameFor;

  @override
  State<CheckoutCarrierSelectionSheet> createState() =>
      _CheckoutCarrierSelectionSheetState();
}

class _CheckoutCarrierSelectionSheetState
    extends State<CheckoutCarrierSelectionSheet> {
  bool _loading = true;
  String? _error;
  final Map<String, List<ImporterCarrierModel>> _carriersByImportador = {};
  final Map<String, String?> _selectedCarrierId = {};
  final Map<String, String?> _selectedDriverId = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final destEstado =
          widget.destino.useProfile ? widget.profile.estado : null;
      final destCiudad =
          widget.destino.useProfile ? widget.profile.ciudad : null;
      final destLat =
          widget.destino.useProfile ? widget.profile.latitude : null;
      final destLng =
          widget.destino.useProfile ? widget.profile.longitude : null;

      for (final impId in widget.importadorIds) {
        final rows = await SupabaseService.listImporterCarriersForCheckout(
          importadorId: impId,
          destEstado: destEstado,
          destCiudad: destCiudad,
          destLatitude: destLat,
          destLongitude: destLng,
        );
        _carriersByImportador[impId] = rows;
        if (rows.length == 1) {
          _selectedCarrierId[impId] = rows.first.id;
        }
      }

      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  bool get _canConfirm {
    for (final impId in widget.importadorIds) {
      final carriers = _carriersByImportador[impId] ?? [];
      if (carriers.isEmpty) continue;
      final selected = _selectedCarrierId[impId];
      if (selected == null || selected.isEmpty) return false;
    }
    return true;
  }

  Map<String, Map<String, String?>> _buildSelectionPayload() {
    final out = <String, Map<String, String?>>{};
    for (final impId in widget.importadorIds) {
      final carriers = _carriersByImportador[impId] ?? [];
      if (carriers.isEmpty) continue;
      final carrierId = _selectedCarrierId[impId];
      if (carrierId == null || carrierId.isEmpty) continue;
      out[impId] = {
        'carrier_id': carrierId,
        'driver_id': _selectedDriverId[impId],
      };
    }
    return out;
  }

  void _confirm() {
    if (!_canConfirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Seleccione un transportista para cada importador.'),
        ),
      );
      return;
    }
    Navigator.of(context).pop(_buildSelectionPayload());
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
                  'Transporte y entrega',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          Text(
            'Elija la empresa de transporte de cada importador. '
            'Compare ETA, distancia y métodos de pago aceptados.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Text(_error!, style: TextStyle(color: Colors.red.shade700))
          else
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.55,
              ),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (final impId in widget.importadorIds) ...[
                      _ImporterCarrierPicker(
                        importadorName: widget.importadorNameFor(impId),
                        carriers: _carriersByImportador[impId] ?? [],
                        selectedCarrierId: _selectedCarrierId[impId],
                        selectedDriverId: _selectedDriverId[impId],
                        onCarrierChanged: (carrierId) {
                          setState(() {
                            _selectedCarrierId[impId] = carrierId;
                            _selectedDriverId[impId] = null;
                          });
                        },
                        onDriverChanged: (driverId) {
                          setState(() => _selectedDriverId[impId] = driverId);
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _loading || !_canConfirm ? null : _confirm,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.brand,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text(
              'Continuar con el pedido',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImporterCarrierPicker extends StatelessWidget {
  const _ImporterCarrierPicker({
    required this.importadorName,
    required this.carriers,
    required this.selectedCarrierId,
    required this.selectedDriverId,
    required this.onCarrierChanged,
    required this.onDriverChanged,
  });

  final String importadorName;
  final List<ImporterCarrierModel> carriers;
  final String? selectedCarrierId;
  final String? selectedDriverId;
  final ValueChanged<String?> onCarrierChanged;
  final ValueChanged<String?> onDriverChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              importadorName,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.brandBlue,
              ),
            ),
            const SizedBox(height: 8),
            if (carriers.isEmpty)
              Text(
                'Este importador no tiene transportistas configurados para su destino.',
                style: TextStyle(color: Colors.red.shade700, fontSize: 13),
              )
            else
              ...carriers.map((carrier) {
                final selected = carrier.id == selectedCarrierId;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () => onCarrierChanged(carrier.id),
                    borderRadius: BorderRadius.circular(10),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected
                              ? AppColors.brandOrange
                              : Colors.grey.shade300,
                          width: selected ? 1.5 : 1,
                        ),
                        color: selected
                            ? AppColors.brandBlueContainer.withOpacity(0.35)
                            : AppColors.fieldFill,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              carrier.companyName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (carrier.contactName?.isNotEmpty == true)
                              Text(
                                carrier.contactName!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                _ChipLabel(
                                  icon: Icons.schedule,
                                  text: CarrierEtaFormat.etaLabel(
                                    carrier.etaHours,
                                  ),
                                ),
                                _ChipLabel(
                                  icon: Icons.route_outlined,
                                  text: CarrierEtaFormat.distanceLabel(
                                    carrier.distanceKm,
                                  ),
                                ),
                                _ChipLabel(
                                  icon: Icons.payments_outlined,
                                  text: CarrierEtaFormat.feeLabel(
                                    carrier.feeUsd,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Pagos: ${carrier.pagoMetodosLabel}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            if (selected && carrier.drivers.isNotEmpty) ...[
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
                            if (selected) ...[
                              const SizedBox(height: 10),
                              CarrierPagoInstruccionesPanel(
                                metodos: carrier.acceptedPagoMetodos,
                                instrucciones: carrier.pagoMetodoInstrucciones,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _ChipLabel extends StatelessWidget {
  const _ChipLabel({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

/// Muestra el sheet de transportistas y devuelve la selección por importador.
Future<Map<String, Map<String, String?>>?> showCheckoutCarrierSelection({
  required BuildContext context,
  required ProfileModel profile,
  required bool destinoUsaPerfil,
  String? destinoTexto,
  String? destinoMapsUrl,
  required CartService cart,
}) async {
  final importadorIds = cart.linesGroupedByImportadorId.keys.toList();
  if (importadorIds.isEmpty) return {};

  var needsSelection = false;
  for (final impId in importadorIds) {
    final rows = await SupabaseService.listImporterCarriersForCheckout(
      importadorId: impId,
      destEstado: destinoUsaPerfil ? profile.estado : null,
      destCiudad: destinoUsaPerfil ? profile.ciudad : null,
      destLatitude: destinoUsaPerfil ? profile.latitude : null,
      destLongitude: destinoUsaPerfil ? profile.longitude : null,
    );
    if (rows.isNotEmpty) {
      needsSelection = true;
      break;
    }
  }
  if (!needsSelection) return {};

  if (!context.mounted) return null;

  return showModalBottomSheet<Map<String, Map<String, String?>>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => CheckoutCarrierSelectionSheet(
      profile: profile,
      destino: CheckoutDestinoInfo(
        useProfile: destinoUsaPerfil,
        texto: destinoTexto,
        mapsUrl: destinoMapsUrl,
      ),
      importadorIds: importadorIds,
      importadorNameFor: cart.importadorDisplayName,
    ),
  );
}
