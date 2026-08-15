import 'package:flutter/material.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

import 'carrier_decision.dart';
import 'pickup_location_mode.dart';
import 'importer_pickup_location_model.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_model.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'package:motolink_pro_app/features/orders/shared/order_pickup_flow_copy.dart';
import 'package:motolink_pro_app/features/orders/shared/b2b_order_panel_widgets.dart';

/// Muestra el punto de recolección confirmado (aliado / importador / admin).
class PickupLocationDisplaySection extends StatelessWidget {
  const PickupLocationDisplaySection({
    super.key,
    required this.request,
  });

  final TransactionRequestModel request;

  @override
  Widget build(BuildContext context) {
    if (!request.hasPickupConfirmed) {
      return B2bPanelSectionCard(
        tint: Colors.amber.shade50,
        icon: Icons.place_outlined,
        title: OrderPickupFlowCopy.recoleccionPendienteImportador,
      );
    }

    final maps = request.pickupMapsUrl?.trim();
    return B2bPanelSectionCard(
      icon: Icons.place_outlined,
      title: OrderPickupFlowCopy.recoleccionTitulo,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (request.pickupLocationMode != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                PickupLocationMode.labelEs(request.pickupLocationMode),
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          if ((request.pickupLabel ?? '').trim().isNotEmpty)
            Text(
              request.pickupLabel!.trim(),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          if (_pickupAddressLines(request) != null) ...[
            const SizedBox(height: 4),
            Text(
              _pickupAddressLines(request)!,
              style: TextStyle(fontSize: 12.5, height: 1.35, color: AppColors.textPrimary),
            ),
          ],
          if (maps != null && maps.isNotEmpty) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => _openMaps(context, maps),
              icon: const Icon(Icons.map_outlined, size: 18),
              label: const Text(OrderPickupFlowCopy.abrirMapas),
            ),
          ],
        ],
      ),
    );
  }

  String? _pickupAddressLines(TransactionRequestModel request) {
    final parts = <String>[];
    final e = request.pickupEstado?.trim();
    final c = request.pickupCiudad?.trim();
    final d = request.pickupDireccion?.trim();
    if (e != null && e.isNotEmpty) parts.add(e);
    if (c != null && c.isNotEmpty) parts.add(c);
    if (d != null && d.isNotEmpty) parts.add(d);
    if (parts.isEmpty) return null;
    return parts.join('\n');
  }

  Future<void> _openMaps(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el enlace de mapas.')),
      );
    }
  }
}

/// Importador: confirmar punto de recolección tras decisión del aliado.
class ImporterConfirmPickupSection extends StatefulWidget {
  const ImporterConfirmPickupSection({
    super.key,
    required this.lines,
    required this.onChanged,
  });

  final List<TransactionRequestModel> lines;
  final VoidCallback onChanged;

  @override
  State<ImporterConfirmPickupSection> createState() =>
      _ImporterConfirmPickupSectionState();
}

class _ImporterConfirmPickupSectionState extends State<ImporterConfirmPickupSection> {
  bool _busy = false;

  TransactionRequestModel get _primary => widget.lines.first;

  Future<void> _confirm() async {
    final r = _primary;
    if (!r.importadorPuedeConfirmarRecoleccion) return;

    List<ImporterPickupLocationModel> locations = const [];
    try {
      locations = await SupabaseService.listMyImporterPickupLocations();
      locations = locations.where((l) => l.isActive).toList();
    } catch (_) {}

    if (!mounted) return;

    final result = await showDialog<({String mode, String? locationId})>(
      context: context,
      builder: (ctx) => _ConfirmPickupDialog(
        request: r,
        locations: locations,
      ),
    );
    if (result == null) return;

    setState(() => _busy = true);
    try {
      for (final line in widget.lines) {
        await SupabaseService.importerConfirmPickupLocation(
          requestId: line.id,
          mode: result.mode,
          pickupLocationId: result.locationId,
        );
      }
      if (!mounted) return;
      widget.onChanged();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(OrderPickupFlowCopy.importadorRecoleccionExito),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _primary;
    if (r.status != 'pedido_listo') return const SizedBox.shrink();

    if (r.hasPickupConfirmed) {
      return PickupLocationDisplaySection(request: r);
    }

    if (r.carrierDecision == CarrierDecision.pending ||
        !r.importadorMuestraSeccionRecoleccion) {
      return const SizedBox.shrink();
    }

    return B2bPanelSectionCard(
      tint: Colors.blue.shade50,
      icon: Icons.place_outlined,
      title: OrderPickupFlowCopy.importadorRecoleccionTuTurnoTitulo,
      subtitle: OrderPickupFlowCopy.importadorRecoleccionCuerpo(r),
      child: FilledButton.icon(
        onPressed: _busy ? null : _confirm,
        icon: _busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.check_circle_outline),
        label: const Text(OrderPickupFlowCopy.importadorRecoleccionBoton),
      ),
    );
  }
}

class _ConfirmPickupDialog extends StatefulWidget {
  const _ConfirmPickupDialog({
    required this.request,
    required this.locations,
  });

  final TransactionRequestModel request;
  final List<ImporterPickupLocationModel> locations;

  @override
  State<_ConfirmPickupDialog> createState() => _ConfirmPickupDialogState();
}

class _ConfirmPickupDialogState extends State<_ConfirmPickupDialog> {
  late String _mode;
  String? _locationId;

  @override
  void initState() {
    super.initState();
    final r = widget.request;
    if (r.carrierDecision == CarrierDecision.selected) {
      _mode = PickupLocationMode.carrierBase;
    } else {
      _mode = PickupLocationMode.warehouse;
    }
    final defaultLoc = widget.locations.where((l) => l.isDefault).toList();
    if (defaultLoc.isNotEmpty) {
      _locationId = defaultLoc.first.id;
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    final canCarrierBase = r.carrierDecision == CarrierDecision.selected;

    return AlertDialog(
      title: const Text(OrderPickupFlowCopy.importadorRecoleccionDialogTitulo),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RadioListTile<String>(
              value: PickupLocationMode.warehouse,
              groupValue: _mode,
              onChanged: (v) => setState(() => _mode = v!),
              title: const Text('Mi almacén'),
              subtitle: const Text(OrderPickupFlowCopy.importadorAlmacenSubtitulo),
              contentPadding: EdgeInsets.zero,
            ),
            if (canCarrierBase)
              RadioListTile<String>(
                value: PickupLocationMode.carrierBase,
                groupValue: _mode,
                onChanged: (v) => setState(() => _mode = v!),
                title: const Text('Base del transportista'),
                subtitle: Text(
                  r.carrierDisplayCompanyName != null
                      ? '${OrderPickupFlowCopy.importadorBaseTransportistaSubtitulo}: ${r.carrierDisplayCompanyName}'
                      : OrderPickupFlowCopy.importadorBaseTransportistaSubtitulo,
                ),
                contentPadding: EdgeInsets.zero,
              ),
            if (widget.locations.isNotEmpty)
              RadioListTile<String>(
                value: PickupLocationMode.alternate,
                groupValue: _mode,
                onChanged: (v) => setState(() => _mode = v!),
                title: const Text('Ubicación alterna'),
                subtitle: const Text(OrderPickupFlowCopy.importadorUbicacionAlternaSubtitulo),
                contentPadding: EdgeInsets.zero,
              ),
            if (_mode == PickupLocationMode.alternate) ...[
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _locationId ?? widget.locations.first.id,
                decoration: const InputDecoration(
                  labelText: 'Seleccione la ubicación',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: widget.locations
                    .map(
                      (l) => DropdownMenuItem(
                        value: l.id,
                        child: Text(l.label),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _locationId = v),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            if (_mode == PickupLocationMode.alternate &&
                (_locationId == null || _locationId!.isEmpty)) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Seleccione una ubicación de la lista.'),
                ),
              );
              return;
            }
            Navigator.pop(
              context,
              (mode: _mode, locationId: _locationId),
            );
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
