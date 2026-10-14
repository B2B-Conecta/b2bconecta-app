import 'package:flutter/material.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

import 'carrier_decision.dart';
import 'pickup_location_mode.dart';
import 'importer_pickup_location_model.dart';
import 'importer_pickup_locations_panel.dart';
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
  late List<ImporterPickupLocationModel> _locations;
  String? _locationId;
  bool _adding = false;

  @override
  void initState() {
    super.initState();
    final r = widget.request;
    if (r.carrierDecision == CarrierDecision.selected) {
      _mode = PickupLocationMode.carrierBase;
    } else {
      _mode = PickupLocationMode.warehouse;
    }
    _locations = List.of(widget.locations);
    final defaultLoc = _locations.where((l) => l.isDefault).toList();
    if (defaultLoc.isNotEmpty) {
      _locationId = defaultLoc.first.id;
    } else if (_locations.isNotEmpty) {
      _locationId = _locations.first.id;
    }
  }

  Future<void> _addLocation() async {
    setState(() => _adding = true);
    try {
      final saved = await showImporterPickupLocationForm(context);
      if (saved != true || !mounted) return;
      final rows = await SupabaseService.listMyImporterPickupLocations();
      final active = rows.where((l) => l.isActive).toList();
      if (!mounted) return;
      final known = _locations.map((l) => l.id).toSet();
      String? created;
      for (final item in active) {
        if (!known.contains(item.id)) created = item.id;
      }
      setState(() {
        _locations = active;
        _mode = PickupLocationMode.alternate;
        _locationId = created ??
            (active.isEmpty ? null : active.last.id);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar la ubicación: $e')),
      );
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    final canCarrierBase = r.carrierDecision == CarrierDecision.selected;

    final selectedId = _locationId ??
        (_locations.isEmpty ? null : _locations.first.id);
    ImporterPickupLocationModel? selectedLocation;
    for (final item in _locations) {
      if (item.id == selectedId) selectedLocation = item;
    }
    return AlertDialog(
      title: const Text(OrderPickupFlowCopy.importadorRecoleccionDialogTitulo),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'La tienda y el transporte usan este punto para retirar la mercancía.',
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            _PickupChoice(
              selected: _mode == PickupLocationMode.warehouse,
              icon: Icons.warehouse_outlined,
              title: 'Mi almacén',
              body: OrderPickupFlowCopy.importadorAlmacenSubtitulo,
              onTap: () => setState(() => _mode = PickupLocationMode.warehouse),
            ),
            if (canCarrierBase) ...[
              const SizedBox(height: 8),
              _PickupChoice(
                selected: _mode == PickupLocationMode.carrierBase,
                icon: Icons.local_shipping_outlined,
                title: 'Base del transportista',
                body: r.carrierDisplayCompanyName != null
                    ? '${OrderPickupFlowCopy.importadorBaseTransportistaSubtitulo}: ${r.carrierDisplayCompanyName}'
                    : OrderPickupFlowCopy.importadorBaseTransportistaSubtitulo,
                onTap: () =>
                    setState(() => _mode = PickupLocationMode.carrierBase),
              ),
            ],
            const SizedBox(height: 8),
            _PickupChoice(
              selected: _mode == PickupLocationMode.alternate,
              icon: Icons.edit_location_alt_outlined,
              title: 'Otra ubicación',
              body: _mode == PickupLocationMode.alternate &&
                      selectedLocation != null
                  ? selectedLocation.ubicacionMultilinea
                  : 'Un punto distinto al almacén de su perfil.',
              onTap: () => setState(() => _mode = PickupLocationMode.alternate),
            ),
            if (_mode == PickupLocationMode.alternate) ...[
              const SizedBox(height: 8),
              if (_locations.isNotEmpty)
                DropdownButtonFormField<String>(
                  value: selectedId,
                  decoration: const InputDecoration(
                    labelText: 'Seleccione la ubicación',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: _locations
                      .map(
                        (l) => DropdownMenuItem(
                          value: l.id,
                          child: Text(l.label),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _locationId = v),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _adding ? null : _addLocation,
                  icon: _adding
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_location_alt_outlined, size: 18),
                  label: Text(
                    _locations.isEmpty
                        ? 'Agregar ubicación'
                        : 'Agregar otra ubicación',
                  ),
                ),
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
                (selectedId == null || selectedId.isEmpty)) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Agregue o seleccione una ubicación distinta al almacén.',
                  ),
                ),
              );
              return;
            }
            Navigator.pop(
              context,
              (
                mode: _mode,
                locationId: _mode == PickupLocationMode.alternate
                    ? selectedId
                    : null,
              ),
            );
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

class _PickupChoice extends StatelessWidget {
  const _PickupChoice({
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
  final VoidCallback onTap;

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
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      body,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? AppColors.brand : AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
