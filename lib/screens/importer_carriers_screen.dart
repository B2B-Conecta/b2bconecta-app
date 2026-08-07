import 'package:flutter/material.dart';

import '../models/importer_carrier_driver_model.dart';
import '../models/importer_carrier_model.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_breakpoints.dart';
import '../widgets/importer_carrier_form.dart';
import '../widgets/importer_pickup_locations_panel.dart';

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
                          itemCount: _carriers.length + 1,
                          separatorBuilder: (_, index) =>
                              SizedBox(height: index == 0 ? 16 : 12),
                          itemBuilder: (context, index) {
                            if (index == 0) {
                              return const ImporterPickupLocationsPanel();
                            }
                            final c = _carriers[index - 1];
                            return _CarrierCard(
                              carrier: c,
                              onEdit: () => _openCarrierForm(c),
                              onDrivers: () => _openDrivers(c),
                              onDeactivate: c.isActive
                                  ? () => _deactivateCarrier(c)
                                  : null,
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
                'Los aliados las verán al confirmar pedidos.',
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

class _CarrierCard extends StatelessWidget {
  const _CarrierCard({
    required this.carrier,
    required this.onEdit,
    required this.onDrivers,
    this.onDeactivate,
  });

  final ImporterCarrierModel carrier;
  final VoidCallback onEdit;
  final VoidCallback onDrivers;
  final VoidCallback? onDeactivate;

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
            if (carrier.flatFeeUsd != null || carrier.pricePerKmUsd != null) ...[
              const SizedBox(height: 8),
              _InfoRow(
                icon: Icons.attach_money,
                label: 'Tarifa',
                value: [
                  if (carrier.flatFeeUsd != null)
                    'Fija USD ${carrier.flatFeeUsd}',
                  if (carrier.pricePerKmUsd != null)
                    'USD/km ${carrier.pricePerKmUsd}',
                ].join(' · '),
              ),
            ],
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

  Future<void> _addDriver() async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final licenseCtrl = TextEditingController();
    final isWide = MediaQuery.sizeOf(context).width >= 600;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nuevo conductor'),
        content: SizedBox(
          width: isWide ? 420 : null,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre *',
                  filled: true,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: phoneCtrl,
                decoration: const InputDecoration(
                  labelText: 'Teléfono',
                  filled: true,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: licenseCtrl,
                decoration: const InputDecoration(
                  labelText: 'Licencia / cédula',
                  filled: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (ok != true || nameCtrl.text.trim().isEmpty) return;
    await SupabaseService.createImporterCarrierDriver(
      carrierId: widget.carrier.id,
      driverName: nameCtrl.text.trim(),
      contactPhone: phoneCtrl.text.trim(),
      licenseId: licenseCtrl.text.trim(),
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
        onPressed: _addDriver,
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
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'Agregue conductores de confianza para este transportista.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                        itemCount: _drivers.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final d = _drivers[index];
                          return DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppColors.brandBlueContainer,
                                child: Text(
                                  d.driverName.isNotEmpty
                                      ? d.driverName[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    color: AppColors.brandBlue,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              title: Text(
                                d.driverName,
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                              subtitle: Text(
                                [
                                  if (d.contactPhone?.isNotEmpty == true)
                                    d.contactPhone!,
                                  if (d.licenseId?.isNotEmpty == true)
                                    'Lic. ${d.licenseId}',
                                ].join(' · '),
                              ),
                              trailing: d.isActive
                                  ? IconButton(
                                      tooltip: 'Desactivar',
                                      icon: const Icon(Icons.delete_outline),
                                      onPressed: () async {
                                        await SupabaseService
                                            .deleteImporterCarrierDriver(d.id);
                                        await _load();
                                      },
                                    )
                                  : const _StatusChip(
                                      label: 'Inactivo',
                                      color: Colors.grey,
                                      background: Color(0xFFECEFF1),
                                    ),
                            ),
                          );
                        },
                      ),
              ),
            ),
    );
  }
}
