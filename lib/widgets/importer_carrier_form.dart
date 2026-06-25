import 'package:flutter/material.dart';

import '../models/importer_carrier_model.dart';
import '../models/pago_metodo.dart';
import '../models/carrier_flete_pago_modo.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_breakpoints.dart';
import 'carrier_pago_metodos_editor.dart';

/// Abre el formulario de transportista (diálogo en web, sheet en móvil).
Future<bool?> showImporterCarrierForm(
  BuildContext context, {
  ImporterCarrierModel? existing,
}) {
  final isWide = MediaQuery.sizeOf(context).width >= 720;
  if (isWide) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppBreakpoints.formMaxWidth,
            maxHeight: 860,
          ),
          child: _ImporterCarrierForm(existing: existing),
        ),
      ),
    );
  }

  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      builder: (_, scrollController) => _ImporterCarrierForm(
        existing: existing,
        scrollController: scrollController,
      ),
    ),
  );
}

class _ImporterCarrierForm extends StatefulWidget {
  const _ImporterCarrierForm({
    this.existing,
    this.scrollController,
  });

  final ImporterCarrierModel? existing;
  final ScrollController? scrollController;

  @override
  State<_ImporterCarrierForm> createState() => _ImporterCarrierFormState();
}

class _ImporterCarrierFormState extends State<_ImporterCarrierForm> {
  final _company = TextEditingController();
  final _contactName = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _whatsapp = TextEditingController();
  final _estados = TextEditingController();
  final _ciudades = TextEditingController();
  final _baseEstado = TextEditingController();
  final _baseCiudad = TextEditingController();
  final _etaBase = TextEditingController(text: '24');
  final _etaPerKm = TextEditingController(text: '0.15');
  final _maxKm = TextEditingController();
  final _flatFee = TextEditingController();
  final _pricePerKm = TextEditingController();
  final _notes = TextEditingController();
  late Set<String> _pagoMetodos;
  late Map<String, TextEditingController> _instruccionesControllers;
  late String _fletePagoModo;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _company.text = e.companyName;
      _contactName.text = e.contactName ?? '';
      _phone.text = e.contactPhone;
      _email.text = e.contactEmail ?? '';
      _whatsapp.text = e.contactWhatsapp ?? '';
      _estados.text = e.coverageEstados.join(', ');
      _ciudades.text = e.coverageCiudades.join(', ');
      _baseEstado.text = e.baseEstado ?? '';
      _baseCiudad.text = e.baseCiudad ?? '';
      _etaBase.text = e.etaBaseHours.toString();
      _etaPerKm.text = e.etaHoursPerKm.toString();
      _maxKm.text = e.maxCoverageKm?.toString() ?? '';
      _flatFee.text = e.flatFeeUsd?.toString() ?? '';
      _pricePerKm.text = e.pricePerKmUsd?.toString() ?? '';
      _notes.text = e.notes ?? '';
      _pagoMetodos = e.acceptedPagoMetodos.toSet();
      _fletePagoModo = e.fletePagoModo;
    } else {
      _pagoMetodos = {'efectivo', 'zelle_divisas'};
      _fletePagoModo = CarrierFletePagoModo.incluidoFactura;
    }
    _instruccionesControllers = _buildInstruccionesControllers(
      widget.existing?.pagoMetodoInstrucciones ?? const {},
    );
  }

  Map<String, TextEditingController> _buildInstruccionesControllers(
    Map<String, String> existing,
  ) {
    final map = <String, TextEditingController>{};
    for (final code in PagoMetodo.valuesMotoconecta) {
      map[code] = TextEditingController(text: existing[code] ?? '');
    }
    return map;
  }

  @override
  void dispose() {
    _company.dispose();
    _contactName.dispose();
    _phone.dispose();
    _email.dispose();
    _whatsapp.dispose();
    _estados.dispose();
    _ciudades.dispose();
    _baseEstado.dispose();
    _baseCiudad.dispose();
    _etaBase.dispose();
    _etaPerKm.dispose();
    _maxKm.dispose();
    _flatFee.dispose();
    _pricePerKm.dispose();
    _notes.dispose();
    for (final c in _instruccionesControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  InputDecoration _fieldDecoration({
    required String label,
    String? hint,
    IconData? icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon != null ? Icon(icon, color: AppColors.textSecondary) : null,
      filled: true,
      fillColor: AppColors.fieldFill,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.brandOrange, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    );
  }

  List<String> _splitCsv(String raw) {
    return raw
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  double? _parseOpt(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    return double.tryParse(t.replaceAll(',', '.'));
  }

  Map<String, String> _instruccionesToSave() {
    final out = <String, String>{};
    for (final code in _pagoMetodos) {
      final text = _instruccionesControllers[code]?.text.trim() ?? '';
      if (text.isNotEmpty) out[code] = text;
    }
    return out;
  }

  Future<void> _save() async {
    if (_company.text.trim().length < 2 || _phone.text.trim().length < 6) {
      _snack('Complete nombre de empresa y teléfono.');
      return;
    }
    if (_pagoMetodos.isEmpty) {
      _snack('Seleccione al menos un método de pago.');
      return;
    }

    final sinDatos = _pagoMetodos.where((code) {
      final t = _instruccionesControllers[code]?.text.trim() ?? '';
      return t.isEmpty;
    }).toList();
    if (sinDatos.isNotEmpty) {
      final labels = sinDatos.map(PagoMetodo.labelEs).join(', ');
      _snack(
        'Complete los datos de pago para: $labels.',
        duration: const Duration(seconds: 4),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final instrucciones = _instruccionesToSave();
      final common = (
        companyName: _company.text.trim(),
        contactPhone: _phone.text.trim(),
        contactName: _contactName.text.trim(),
        contactEmail: _email.text.trim(),
        contactWhatsapp: _whatsapp.text.trim(),
        coverageEstados: _splitCsv(_estados.text),
        coverageCiudades: _splitCsv(_ciudades.text),
        baseEstado: _baseEstado.text.trim(),
        baseCiudad: _baseCiudad.text.trim(),
        etaBaseHours: double.tryParse(_etaBase.text.trim()) ?? 24,
        etaHoursPerKm: double.tryParse(_etaPerKm.text.trim()) ?? 0.15,
        maxCoverageKm: _parseOpt(_maxKm.text),
        flatFeeUsd: _parseOpt(_flatFee.text),
        pricePerKmUsd: _parseOpt(_pricePerKm.text),
        notes: _notes.text.trim(),
        acceptedPagoMetodos: _pagoMetodos.toList(),
        pagoMetodoInstrucciones: instrucciones,
      );

      if (widget.existing != null) {
        final e = widget.existing!;
        await SupabaseService.updateImporterCarrier(
          carrierId: e.id,
          companyName: common.companyName,
          contactPhone: common.contactPhone,
          contactName: common.contactName,
          contactEmail: common.contactEmail,
          contactWhatsapp: common.contactWhatsapp,
          coverageEstados: common.coverageEstados,
          coverageCiudades: common.coverageCiudades,
          baseEstado: common.baseEstado,
          baseCiudad: common.baseCiudad,
          baseLatitude: e.baseLatitude,
          baseLongitude: e.baseLongitude,
          baseMapsUrl: e.baseMapsUrl,
          etaBaseHours: common.etaBaseHours,
          etaHoursPerKm: common.etaHoursPerKm,
          maxCoverageKm: common.maxCoverageKm,
          flatFeeUsd: common.flatFeeUsd,
          pricePerKmUsd: common.pricePerKmUsd,
          notes: common.notes,
          acceptedPagoMetodos: common.acceptedPagoMetodos,
          pagoMetodoInstrucciones: common.pagoMetodoInstrucciones,
          fletePagoModo: _fletePagoModo,
          isActive: e.isActive,
        );
      } else {
        await SupabaseService.createImporterCarrier(
          companyName: common.companyName,
          contactPhone: common.contactPhone,
          contactName: common.contactName,
          contactEmail: common.contactEmail,
          contactWhatsapp: common.contactWhatsapp,
          coverageEstados: common.coverageEstados,
          coverageCiudades: common.coverageCiudades,
          baseEstado: common.baseEstado,
          baseCiudad: common.baseCiudad,
          etaBaseHours: common.etaBaseHours,
          etaHoursPerKm: common.etaHoursPerKm,
          maxCoverageKm: common.maxCoverageKm,
          flatFeeUsd: common.flatFeeUsd,
          pricePerKmUsd: common.pricePerKmUsd,
          notes: common.notes,
        acceptedPagoMetodos: common.acceptedPagoMetodos,
        pagoMetodoInstrucciones: common.pagoMetodoInstrucciones,
        fletePagoModo: _fletePagoModo,
        );
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      _snack('$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String message, {Duration duration = const Duration(seconds: 3)}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: duration),
    );
  }

  Widget _section({
    required String title,
    String? subtitle,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: AppColors.brandBlue,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700, height: 1.35),
          ),
        ],
        const SizedBox(height: 10),
        ...children,
      ],
    );
  }

  Widget _twoCol({required Widget left, required Widget right}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 520;
        if (!wide) {
          return Column(
            children: [
              left,
              const SizedBox(height: 10),
              right,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: left),
            const SizedBox(width: 12),
            Expanded(child: right),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDialog = widget.scrollController == null;
    final title =
        widget.existing == null ? 'Nuevo transportista' : 'Editar transportista';

    return Material(
      color: isDialog ? Colors.white : AppColors.background,
      borderRadius: isDialog ? BorderRadius.circular(12) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              controller: widget.scrollController,
              padding: EdgeInsets.fromLTRB(
                20,
                8,
                20,
                MediaQuery.viewInsetsOf(context).bottom + 16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _section(
                    title: 'Empresa y contacto',
                    children: [
                      TextField(
                        controller: _company,
                        decoration: _fieldDecoration(
                          label: 'Empresa *',
                          icon: Icons.business_outlined,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _twoCol(
                        left: TextField(
                          controller: _contactName,
                          decoration: _fieldDecoration(
                            label: 'Persona de contacto',
                            icon: Icons.person_outline,
                          ),
                        ),
                        right: TextField(
                          controller: _phone,
                          keyboardType: TextInputType.phone,
                          decoration: _fieldDecoration(
                            label: 'Teléfono *',
                            icon: Icons.phone_outlined,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _twoCol(
                        left: TextField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          decoration: _fieldDecoration(
                            label: 'Correo',
                            icon: Icons.email_outlined,
                          ),
                        ),
                        right: TextField(
                          controller: _whatsapp,
                          keyboardType: TextInputType.phone,
                          decoration: _fieldDecoration(
                            label: 'WhatsApp',
                            icon: Icons.chat_outlined,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _section(
                    title: 'Cobertura y base operativa',
                    subtitle:
                        'Separe estados y ciudades con comas. Deje vacío para cubrir todo el país.',
                    children: [
                      TextField(
                        controller: _estados,
                        decoration: _fieldDecoration(
                          label: 'Estados cubiertos',
                          hint: 'Distrito Capital, Miranda',
                          icon: Icons.map_outlined,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _ciudades,
                        decoration: _fieldDecoration(
                          label: 'Ciudades cubiertas',
                          hint: 'Caracas, Los Teques',
                          icon: Icons.location_city_outlined,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _twoCol(
                        left: TextField(
                          controller: _baseEstado,
                          decoration: _fieldDecoration(label: 'Base — estado'),
                        ),
                        right: TextField(
                          controller: _baseCiudad,
                          decoration: _fieldDecoration(label: 'Base — ciudad'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _section(
                    title: 'Tiempos y tarifas',
                    subtitle:
                        'Se usan para estimar ETA y costo de envío en el checkout del aliado.',
                    children: [
                      _twoCol(
                        left: TextField(
                          controller: _etaBase,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: _fieldDecoration(
                            label: 'ETA base (horas)',
                            icon: Icons.schedule_outlined,
                          ),
                        ),
                        right: TextField(
                          controller: _etaPerKm,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: _fieldDecoration(label: 'ETA por km (h)'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _twoCol(
                        left: TextField(
                          controller: _flatFee,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: _fieldDecoration(
                            label: 'Tarifa fija USD',
                            icon: Icons.attach_money,
                          ),
                        ),
                        right: TextField(
                          controller: _pricePerKm,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: _fieldDecoration(label: 'USD por km'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _maxKm,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: _fieldDecoration(
                          label: 'Radio máximo (km)',
                          hint: 'Opcional',
                          icon: Icons.radar_outlined,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _section(
                    title: 'Pago del flete',
                    subtitle:
                        'Indique al aliado si el envío va en su factura o se paga aparte al transportista.',
                    children: [
                      ...CarrierFletePagoModo.values.map(
                        (mode) => RadioListTile<String>(
                          value: mode,
                          groupValue: _fletePagoModo,
                          onChanged: _saving
                              ? null
                              : (v) {
                                  if (v == null) return;
                                  setState(() => _fletePagoModo = v);
                                },
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: Text(
                            CarrierFletePagoModo.labelEs(mode),
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _section(
                    title: 'Métodos de pago aceptados',
                    children: [
                      CarrierPagoMetodosEditor(
                        selected: _pagoMetodos,
                        controllers: _instruccionesControllers,
                        saving: _saving,
                        onSelectionChanged: (code, checked) {
                          setState(() {
                            if (checked) {
                              _pagoMetodos.add(code);
                            } else {
                              _pagoMetodos.remove(code);
                            }
                          });
                        },
                        onInstructionsChanged: () => setState(() {}),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _section(
                    title: 'Notas internas',
                    subtitle: 'Opcional. No se muestran al aliado en checkout.',
                    children: [
                      TextField(
                        controller: _notes,
                        minLines: 2,
                        maxLines: 4,
                        decoration: _fieldDecoration(
                          label: 'Notas',
                          icon: Icons.notes_outlined,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.brand,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Guardar transportista',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Chips de métodos de pago para tarjetas de listado.
class CarrierPagoMetodoChips extends StatelessWidget {
  const CarrierPagoMetodoChips({
    super.key,
    required this.metodos,
    this.maxVisible = 4,
  });

  final List<String> metodos;
  final int maxVisible;

  @override
  Widget build(BuildContext context) {
    if (metodos.isEmpty) {
      return Text(
        'Sin métodos de pago',
        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
      );
    }
    final visible = metodos.take(maxVisible).toList();
    final extra = metodos.length - visible.length;
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final code in visible)
          Chip(
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            labelPadding: const EdgeInsets.symmetric(horizontal: 2),
            label: Text(
              PagoMetodo.labelEs(code),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
            backgroundColor: AppColors.brandBlueContainer,
            side: BorderSide.none,
          ),
        if (extra > 0)
          Text(
            '+$extra',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
      ],
    );
  }
}

/// Detalle de instrucciones de pago del transportista (checkout).
class CarrierPagoInstruccionesPanel extends StatelessWidget {
  const CarrierPagoInstruccionesPanel({
    super.key,
    required this.metodos,
    required this.instrucciones,
  });

  final List<String> metodos;
  final Map<String, String> instrucciones;

  @override
  Widget build(BuildContext context) {
    final items = metodos
        .map((code) => MapEntry(code, instrucciones[code]))
        .where((e) => e.value != null && e.value!.trim().isNotEmpty)
        .toList();
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Datos de pago del transportista',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 6),
        for (final item in items) ...[
          DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    PagoMetodo.labelEs(item.key),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.brandBlue,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.value!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade800,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
        ],
      ],
    );
  }
}
