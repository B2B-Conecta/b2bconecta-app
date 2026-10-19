import 'package:flutter/material.dart';

import 'importer_carrier_driver_model.dart';
import 'importer_carrier_model.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/layout/app_breakpoints.dart';
import 'importer_carrier_form.dart';
import 'importer_envio_politica_panel.dart';
import 'importer_pickup_locations_panel.dart';

/// Importador: gestión de empresas de transporte y conductores.
class ImporterCarriersScreen extends StatefulWidget {
  const ImporterCarriersScreen({super.key});

  @override
  State<ImporterCarriersScreen> createState() => _ImporterCarriersScreenState();
}

class _ImporterCarriersScreenState extends State<ImporterCarriersScreen> {
  List<ImporterCarrierModel> _carriers = [];
  bool _loading = true;
  String? _error;

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
      final rows = await SupabaseService.listMyImporterCarriers();
      if (!mounted) return;
      setState(() {
        _carriers = rows;
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

  Future<void> _openCarrierForm([ImporterCarrierModel? existing]) async {
    final saved = await showImporterCarrierForm(context, existing: existing);
    if (saved == true) await _load();
  }

  Future<void> _openDrivers(ImporterCarrierModel carrier) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => _CarrierDriversScreen(carrier: carrier),
      ),
    );
    await _load();
  }

  Future<void> _deactivateCarrier(ImporterCarrierModel carrier) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Desactivar transportista'),
        content: Text(
          '¿Desactivar «${carrier.companyName}»? Ya no aparecerá en checkout.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Desactivar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await SupabaseService.deleteImporterCarrier(carrier.id);
    await _load();
  }

  Future<void> _activateCarrier(ImporterCarrierModel carrier) async {
    try {
      await SupabaseService.updateImporterCarrier(
        carrierId: carrier.id,
        companyName: carrier.companyName,
        contactPhone: carrier.contactPhone,
        contactName: carrier.contactName,
        contactEmail: carrier.contactEmail,
        contactWhatsapp: carrier.contactWhatsapp,
        coverageEstados: carrier.coverageEstados,
        coverageCiudades: carrier.coverageCiudades,
        coverageNotes: carrier.coverageNotes,
        baseEstado: carrier.baseEstado,
        baseCiudad: carrier.baseCiudad,
        baseLatitude: carrier.baseLatitude,
        baseLongitude: carrier.baseLongitude,
        baseMapsUrl: carrier.baseMapsUrl,
        acceptedPagoMetodos: carrier.acceptedPagoMetodos,
        pagoMetodoInstrucciones: carrier.pagoMetodoInstrucciones,
        fletePagoModo: carrier.fletePagoModo,
        etaBaseHours: carrier.etaBaseHours,
        etaHoursPerKm: carrier.etaHoursPerKm,
        maxCoverageKm: carrier.maxCoverageKm,
        flatFeeUsd: carrier.flatFeeUsd,
        pricePerKmUsd: carrier.pricePerKmUsd,
        notes: carrier.notes,
        isActive: true,
        sortOrder: carrier.sortOrder,
      );
      await _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo activar el transportista.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= AppBreakpoints.formMaxWidth;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Transportistas',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCarrierForm(),
        backgroundColor: AppColors.brand,
        icon: const Icon(Icons.local_shipping_outlined),
        label: const Text('Nuevo transportista'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _carriers.isEmpty
                  ? ListView(
                      padding: EdgeInsets.fromLTRB(
                        isWide ? 24 : 16,
                        12,
                        isWide ? 24 : 16,
                        88,
                      ),
                      children: [
                        const ImporterEnvioPoliticaPanel(),
                        const SizedBox(height: 16),
                        const ImporterPickupLocationsPanel(),
                        const SizedBox(height: 20),
                        _EmptyCarriersState(onCreate: () => _openCarrierForm()),
                      ],
                    )
                  : Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: isWide ? 960 : double.infinity,
                        ),
                        child: ListView.separated(
                          padding: EdgeInsets.fromLTRB(
                            isWide ? 24 : 16,
                            12,
                            isWide ? 24 : 16,
                            88,
                          ),
                          itemCount: _carriers.length + 2,
                          separatorBuilder: (_, index) =>
                              SizedBox(height: index == 0 ? 16 : 12),
                          itemBuilder: (context, index) {
                            if (index == 0) {
                              return const ImporterEnvioPoliticaPanel();
                            }
                            if (index == 1) {
                              return const ImporterPickupLocationsPanel();
                            }
                            final c = _carriers[index - 2];
                            return _CarrierCard(
                              carrier: c,
                              onEdit: () => _openCarrierForm(c),
                              onDrivers: () => _openDrivers(c),
                              onDeactivate: c.isActive
                                  ? () => _deactivateCarrier(c)
                                  : null,
                              onActivate: c.isActive
                                  ? null
                                  : () => _activateCarrier(c),
                            );
                          },
                        ),
                      ),
                    ),
    );
  }
}

class _EmptyCarriersState extends StatelessWidget {
  const _EmptyCarriersState({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.local_shipping_outlined,
                size: 56,
                color: AppColors.brandBlue.withOpacity(0.55),
              ),
              const SizedBox(height: 16),
              const Text(
                'Sin transportistas registrados',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Registre empresas de transporte con cobertura, tarifas y métodos de pago. '
                'Las tiendas minoristas las verán al confirmar pedidos.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add),
                label: const Text('Agregar transportista'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _tarifaLabel(ImporterCarrierModel carrier) {
  final flat = carrier.flatFeeUsd;
  final perKm = carrier.pricePerKmUsd;
  if (flat != null && flat <= 0 && (perKm == null || perKm <= 0)) {
    return 'Envío gratis';
  }
  if (flat != null && flat > 0 && (perKm == null || perKm <= 0)) {
    return 'Tarifa fija ${flat.toStringAsFixed(2)} USD';
  }
  if (perKm != null && perKm > 0) {
    return 'Según distancia';
  }
  return 'Según tarifa de la agencia';
}

class _CarrierCard extends StatelessWidget {
  const _CarrierCard({
    required this.carrier,
    required this.onEdit,
    required this.onDrivers,
    this.onDeactivate,
    this.onActivate,
  });

  final ImporterCarrierModel carrier;
  final VoidCallback onEdit;
  final VoidCallback onDrivers;
  final VoidCallback? onDeactivate;
  final VoidCallback? onActivate;

  @override
  Widget build(BuildContext context) {
    final contactParts = <String>[
      if (carrier.contactName?.isNotEmpty == true) carrier.contactName!,
      carrier.contactPhone,
      if (carrier.baseCiudad?.isNotEmpty == true) carrier.baseCiudad!,
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: AppDecorations.cardShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.brandBlueContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.local_shipping_outlined,
                    color: AppColors.brandBlue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              carrier.companyName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          if (!carrier.isActive)
                            _StatusChip(
                              label: 'Inactivo',
                              color: AppColors.textSecondary,
                              background: Colors.grey.shade200,
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        contactParts.join(' · '),
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _InfoRow(
              icon: Icons.map_outlined,
              label: 'Cobertura',
              value: carrier.coverageLabel,
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.payments_outlined,
                    size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Métodos de pago',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      CarrierPagoMetodoChips(metodos: carrier.acceptedPagoMetodos),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _InfoRow(
              icon: Icons.attach_money,
              label: 'Tarifa',
              value: _tarifaLabel(carrier),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Editar'),
                ),
                OutlinedButton.icon(
                  onPressed: onDrivers,
                  icon: const Icon(Icons.person_outline, size: 18),
                  label: const Text('Conductores'),
                ),
                if (onDeactivate != null)
                  TextButton.icon(
                    onPressed: onDeactivate,
                    icon: Icon(Icons.delete_outline,
                        size: 18, color: Colors.red.shade700),
                    label: Text(
                      'Desactivar',
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                  ),
                if (onActivate != null)
                  FilledButton.icon(
                    onPressed: onActivate,
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Activar'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
              children: [
                TextSpan(
                  text: '$label: ',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.color,
    required this.background,
  });

  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

class _CarrierDriversScreen extends StatefulWidget {
  const _CarrierDriversScreen({required this.carrier});

  final ImporterCarrierModel carrier;

  @override
  State<_CarrierDriversScreen> createState() => _CarrierDriversScreenState();
}

class _CarrierDriversScreenState extends State<_CarrierDriversScreen> {
  List<ImporterCarrierDriverModel> _drivers = [];
  bool _loading = true;

  Future<void> _load() async {
    setState(() => _loading = true);
    final rows =
        await SupabaseService.listImporterCarrierDrivers(widget.carrier.id);
    if (!mounted) return;
    setState(() {
      _drivers = rows;
      _loading = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  List<ImporterCarrierDriverModel> get _orderedDrivers {
    final rows = [..._drivers];
    rows.sort((a, b) {
      if (a.isActive != b.isActive) return a.isActive ? -1 : 1;
      return a.driverName.toLowerCase().compareTo(b.driverName.toLowerCase());
    });
    return rows;
  }

  Future<void> _openDriverForm([ImporterCarrierDriverModel? existing]) async {
    final draft = await showDialog<_DriverDraft>(
      context: context,
      builder: (ctx) => _DriverEditorDialog(existing: existing),
    );
    if (draft == null) return;
    if (existing == null) {
      await SupabaseService.createImporterCarrierDriver(
        carrierId: widget.carrier.id,
        driverName: draft.name,
        contactPhone: draft.phone,
        licenseId: draft.license,
      );
    } else {
      await SupabaseService.updateImporterCarrierDriver(
        driverId: existing.id,
        driverName: draft.name,
        contactPhone: draft.phone,
        licenseId: draft.license,
        notes: existing.notes,
        isActive: existing.isActive,
        sortOrder: existing.sortOrder,
      );
    }
    await _load();
  }

  Future<void> _setActive(ImporterCarrierDriverModel driver, bool active) async {
    if (!active) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Desactivar conductor'),
          content: Text(
            '¿Desactivar a ${driver.driverName}? Deja de aparecer al coordinar el retiro.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Desactivar'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    await SupabaseService.updateImporterCarrierDriver(
      driverId: driver.id,
      driverName: driver.driverName,
      contactPhone: driver.contactPhone,
      licenseId: driver.licenseId,
      notes: driver.notes,
      isActive: active,
      sortOrder: driver.sortOrder,
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= AppBreakpoints.formMaxWidth;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Conductores · ${widget.carrier.companyName}'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openDriverForm(),
        backgroundColor: AppColors.brand,
        icon: const Icon(Icons.person_add_outlined),
        label: const Text('Agregar'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isWide ? 720 : double.infinity,
                ),
                child: _drivers.isEmpty
                    ? _DriversEmpty(onAdd: () => _openDriverForm())
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                        itemCount: _orderedDrivers.length + 1,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          if (index == 0) return const _DriversIntro();
                          final d = _orderedDrivers[index - 1];
                          return _DriverCard(
                            driver: d,
                            onEdit: () => _openDriverForm(d),
                            onToggle: () => _setActive(d, !d.isActive),
                          );
                        },
                      ),
              ),
            ),
    );
  }
}

class _DriversIntro extends StatelessWidget {
  const _DriversIntro();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        'Personas de este transportista. Sirven al coordinar quién retira o entrega.',
        style: TextStyle(
          fontSize: 13,
          height: 1.35,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _DriversEmpty extends StatelessWidget {
  const _DriversEmpty({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.badge_outlined,
            size: 52,
            color: AppColors.brandBlue.withOpacity(0.55),
          ),
          const SizedBox(height: 14),
          const Text(
            'Sin conductores',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Agregue quién retira o entrega con este transportista.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.person_add_outlined),
            label: const Text('Agregar conductor'),
          ),
        ],
      ),
    );
  }
}

class _DriverCard extends StatelessWidget {
  const _DriverCard({
    required this.driver,
    required this.onEdit,
    required this.onToggle,
  });

  final ImporterCarrierDriverModel driver;
  final VoidCallback onEdit;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final phone = driver.contactPhone?.trim() ?? '';
    final license = driver.licenseId?.trim() ?? '';
    final initial = driver.driverName.trim().isEmpty
        ? '?'
        : driver.driverName.trim()[0].toUpperCase();
    return Opacity(
      opacity: driver.isActive ? 1 : 0.72,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.brandBlueContainer,
                    child: Text(
                      initial,
                      style: const TextStyle(
                        color: AppColors.brandBlue,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      driver.driverName,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                  ),
                  _StatusChip(
                    label: driver.isActive ? 'Activo' : 'Inactivo',
                    color: driver.isActive
                        ? AppColors.successGreen
                        : AppColors.textSecondary,
                    background: driver.isActive
                        ? const Color(0xFFE8F5E9)
                        : const Color(0xFFECEFF1),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _DriverLine(
                icon: Icons.phone_outlined,
                text: phone.isEmpty ? 'Sin teléfono' : phone,
                muted: phone.isEmpty,
              ),
              const SizedBox(height: 4),
              _DriverLine(
                icon: Icons.badge_outlined,
                text: license.isEmpty ? 'Sin licencia o cédula' : license,
                muted: license.isEmpty,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Editar'),
                  ),
                  TextButton.icon(
                    onPressed: onToggle,
                    icon: Icon(
                      driver.isActive
                          ? Icons.person_off_outlined
                          : Icons.person_outline,
                      size: 18,
                    ),
                    label: Text(driver.isActive ? 'Desactivar' : 'Activar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DriverLine extends StatelessWidget {
  const _DriverLine({
    required this.icon,
    required this.text,
    required this.muted,
  });

  final IconData icon;
  final String text;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: muted ? AppColors.textSecondary : AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

class _DriverDraft {
  const _DriverDraft({
    required this.name,
    required this.phone,
    required this.license,
  });

  final String name;
  final String phone;
  final String license;
}

class _DriverEditorDialog extends StatefulWidget {
  const _DriverEditorDialog({this.existing});

  final ImporterCarrierDriverModel? existing;

  @override
  State<_DriverEditorDialog> createState() => _DriverEditorDialogState();
}

class _DriverEditorDialogState extends State<_DriverEditorDialog> {
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _license;
  String? _nameError;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.driverName ?? '');
    _phone = TextEditingController(text: e?.contactPhone ?? '');
    _license = TextEditingController(text: e?.licenseId ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _license.dispose();
    super.dispose();
  }

  InputDecoration _field({
    required String label,
    String? hint,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: AppColors.textSecondary),
      filled: true,
      fillColor: AppColors.fieldFill,
      errorText: label.startsWith('Nombre') ? _nameError : null,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppColors.borderSubtle),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.brand, width: 1.5),
      ),
    );
  }

  void _save() {
    final name = _name.text.trim();
    if (name.length < 2) {
      setState(() => _nameError = 'Indique el nombre');
      return;
    }
    Navigator.pop(
      context,
      _DriverDraft(
        name: name,
        phone: _phone.text.trim(),
        license: _license.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                editing ? 'Editar conductor' : 'Nuevo conductor',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                'Nombre y un teléfono bastan para guardarlo.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                autofocus: true,
                decoration: _field(
                  label: 'Nombre *',
                  icon: Icons.person_outline,
                ),
                onChanged: (_) {
                  if (_nameError != null) setState(() => _nameError = null);
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: _field(
                  label: 'Teléfono',
                  hint: 'Opcional',
                  icon: Icons.phone_outlined,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _license,
                textCapitalization: TextCapitalization.characters,
                decoration: _field(
                  label: 'Licencia o cédula',
                  hint: 'Opcional',
                  icon: Icons.badge_outlined,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _save,
                    child: const Text('Guardar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
