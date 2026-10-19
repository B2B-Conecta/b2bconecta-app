import 'package:flutter/material.dart';

import 'importer_pickup_location_model.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/features/orders/shared/order_pickup_flow_copy.dart';

Future<bool?> showImporterPickupLocationForm(
  BuildContext context, {
  ImporterPickupLocationModel? existing,
}) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => _ImporterPickupLocationDialog(existing: existing),
  );
}

class ImporterPickupLocationsPanel extends StatefulWidget {
  const ImporterPickupLocationsPanel({super.key});

  @override
  State<ImporterPickupLocationsPanel> createState() =>
      _ImporterPickupLocationsPanelState();
}

class _ImporterPickupLocationsPanelState
    extends State<ImporterPickupLocationsPanel> {
  List<ImporterPickupLocationModel> _locations = [];
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
      final rows = await SupabaseService.listMyImporterPickupLocations();
      if (!mounted) return;
      setState(() {
        _locations = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _openForm([ImporterPickupLocationModel? existing]) async {
    final saved = await showImporterPickupLocationForm(context, existing: existing);
    if (saved == true) await _load();
  }

  Future<void> _deactivate(ImporterPickupLocationModel loc) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Desactivar ubicación'),
        content: Text('¿Desactivar «${loc.label}»?'),
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
    await SupabaseService.upsertImporterPickupLocation(
      id: loc.id,
      label: loc.label,
      estado: loc.estado,
      ciudad: loc.ciudad,
      direccion: loc.direccion,
      latitude: loc.latitude,
      longitude: loc.longitude,
      mapsUrl: loc.mapsUrl,
      contactName: loc.contactName,
      contactPhone: loc.contactPhone,
      isActive: false,
      isDefault: false,
      sortOrder: loc.sortOrder,
    );
    await _load();
  }

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
            Row(
              children: [
                const Icon(Icons.place_outlined, color: AppColors.brandBlue),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    OrderPickupFlowCopy.ubicacionesTitulo,
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                ),
                TextButton.icon(
                  onPressed: _loading ? null : () => _openForm(),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Nueva'),
                ),
              ],
            ),
            Text(
              OrderPickupFlowCopy.ubicacionesIntro,
              style: TextStyle(fontSize: 12.5, height: 1.35, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 10),
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else if (_error != null)
              Text(_error!, style: TextStyle(color: Colors.red.shade700, fontSize: 12))
            else if (_locations.where((l) => l.isActive).isEmpty)
              Text(
                OrderPickupFlowCopy.ubicacionesVacias,
                style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
              )
            else
              ..._locations.where((l) => l.isActive).map(
                    (loc) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _LocationTile(
                        location: loc,
                        onEdit: () => _openForm(loc),
                        onDeactivate: () => _deactivate(loc),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

class _LocationTile extends StatelessWidget {
  const _LocationTile({
    required this.location,
    required this.onEdit,
    required this.onDeactivate,
  });

  final ImporterPickupLocationModel location;
  final VoidCallback onEdit;
  final VoidCallback onDeactivate;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceTinted,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    location.label,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                if (location.isDefault)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.brandBlue.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Por defecto',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              location.ubicacionMultilinea,
              style: TextStyle(fontSize: 12, height: 1.35, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                TextButton(
                  onPressed: onEdit,
                  child: const Text('Editar'),
                ),
                TextButton(
                  onPressed: onDeactivate,
                  child: Text('Desactivar', style: TextStyle(color: Colors.red.shade700)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ImporterPickupLocationDialog extends StatefulWidget {
  const _ImporterPickupLocationDialog({this.existing});

  final ImporterPickupLocationModel? existing;

  @override
  State<_ImporterPickupLocationDialog> createState() =>
      _ImporterPickupLocationDialogState();
}

class _ImporterPickupLocationDialogState extends State<_ImporterPickupLocationDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _label;
  late final TextEditingController _estado;
  late final TextEditingController _ciudad;
  late final TextEditingController _direccion;
  late final TextEditingController _mapsUrl;
  late final TextEditingController _contactName;
  late final TextEditingController _contactPhone;
  bool _isDefault = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _label = TextEditingController(text: e?.label ?? '');
    _estado = TextEditingController(text: e?.estado ?? '');
    _ciudad = TextEditingController(text: e?.ciudad ?? '');
    _direccion = TextEditingController(text: e?.direccion ?? '');
    _mapsUrl = TextEditingController(text: e?.mapsUrl ?? '');
    _contactName = TextEditingController(text: e?.contactName ?? '');
    _contactPhone = TextEditingController(text: e?.contactPhone ?? '');
    _isDefault = e?.isDefault ?? false;
  }

  @override
  void dispose() {
    _label.dispose();
    _estado.dispose();
    _ciudad.dispose();
    _direccion.dispose();
    _mapsUrl.dispose();
    _contactName.dispose();
    _contactPhone.dispose();
    super.dispose();
  }

  static const _estadosVenezuela = <String>[
    'Amazonas',
    'Anzoátegui',
    'Apure',
    'Aragua',
    'Barinas',
    'Bolívar',
    'Carabobo',
    'Cojedes',
    'Delta Amacuro',
    'Distrito Capital',
    'Falcón',
    'Guárico',
    'La Guaira',
    'Lara',
    'Mérida',
    'Miranda',
    'Monagas',
    'Nueva Esparta',
    'Portuguesa',
    'Sucre',
    'Táchira',
    'Trujillo',
    'Yaracuy',
    'Zulia',
  ];

  InputDecoration _field({
    required String label,
    String? hint,
    IconData? icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon == null ? null : Icon(icon, color: AppColors.textSecondary),
      filled: true,
      fillColor: AppColors.fieldFill,
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

  List<String> get _estados {
    final actual = _estado.text.trim();
    if (actual.isEmpty || _estadosVenezuela.contains(actual)) {
      return _estadosVenezuela;
    }
    return [actual, ..._estadosVenezuela];
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await SupabaseService.upsertImporterPickupLocation(
        id: widget.existing?.id,
        label: _label.text,
        estado: _estado.text,
        ciudad: _ciudad.text,
        direccion: _direccion.text,
        mapsUrl: _mapsUrl.text,
        contactName: _contactName.text,
        contactPhone: _contactPhone.text,
        isDefault: _isDefault,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 560;
    final lugar = wide
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _estadoField()),
              const SizedBox(width: 10),
              Expanded(child: _ciudadField()),
            ],
          )
        : Column(
            children: [
              _estadoField(),
              const SizedBox(height: 10),
              _ciudadField(),
            ],
          );
    return AlertDialog(
      scrollable: true,
      title: Text(widget.existing == null ? 'Nueva ubicación' : 'Editar ubicación'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Punto distinto al almacén, para cuando retiren el pedido en otra dirección.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _label,
                textCapitalization: TextCapitalization.sentences,
                decoration: _field(
                  label: 'Nombre *',
                  hint: 'Depósito norte',
                  icon: Icons.place_outlined,
                ),
                validator: (v) =>
                    (v ?? '').trim().length < 2 ? 'Indique un nombre' : null,
              ),
              const SizedBox(height: 10),
              lugar,
              const SizedBox(height: 10),
              TextFormField(
                controller: _direccion,
                textCapitalization: TextCapitalization.sentences,
                minLines: 2,
                maxLines: 3,
                decoration: _field(
                  label: 'Dirección *',
                  hint: 'Calle, edificio, referencia',
                  icon: Icons.signpost_outlined,
                ),
                validator: (v) =>
                    (v ?? '').trim().length < 5 ? 'Indique la dirección' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _contactName,
                textCapitalization: TextCapitalization.words,
                decoration: _field(
                  label: 'Quién recibe',
                  hint: 'Opcional',
                  icon: Icons.person_outline,
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _contactPhone,
                keyboardType: TextInputType.phone,
                decoration: _field(
                  label: 'Teléfono',
                  hint: 'Opcional',
                  icon: Icons.phone_outlined,
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _mapsUrl,
                keyboardType: TextInputType.url,
                decoration: _field(
                  label: 'Enlace de mapas',
                  hint: 'Opcional',
                  icon: Icons.map_outlined,
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _isDefault,
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _isDefault = value),
                title: const Text(
                  'Sugerir al confirmar el retiro',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
                subtitle: Text(
                  'Queda marcada como la otra ubicación por defecto.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Guardar'),
        ),
      ],
    );
  }

  Widget _estadoField() {
    final actual = _estado.text.trim();
    return DropdownButtonFormField<String>(
      value: actual.isEmpty ? null : actual,
      isExpanded: true,
      decoration: _field(label: 'Estado', icon: Icons.map_outlined),
      hint: const Text('Opcional'),
      items: [
        for (final estado in _estados)
          DropdownMenuItem(value: estado, child: Text(estado)),
      ],
      onChanged: _saving
          ? null
          : (value) => setState(() => _estado.text = value ?? ''),
    );
  }

  Widget _ciudadField() {
    return TextFormField(
      controller: _ciudad,
      textCapitalization: TextCapitalization.words,
      decoration: _field(label: 'Ciudad', hint: 'Opcional', icon: Icons.location_city_outlined),
    );
  }
}
