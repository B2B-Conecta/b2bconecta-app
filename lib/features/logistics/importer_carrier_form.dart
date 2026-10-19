import 'package:flutter/material.dart';

import 'importer_carrier_model.dart';
import 'package:motolink_pro_app/features/payments/pago_metodo.dart';
import 'carrier_flete_pago_modo.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/layout/app_breakpoints.dart';
import 'package:flutter/services.dart';

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

enum _TarifaModo { fija, agencia, gratis }

class _EtaOpcion {
  const _EtaOpcion(this.key, this.horas, this.label);
  final String key;
  final double horas;
  final String label;
}

const _etaOpciones = <_EtaOpcion>[
  _EtaOpcion('24_48', 24, '24 a 48 horas'),
  _EtaOpcion('2_3', 48, '2 a 3 días'),
  _EtaOpcion('3_5', 72, '3 a 5 días'),
  _EtaOpcion('5_7', 120, '5 a 7 días'),
];

const _estadosVenezuela = <String>[
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

class _ImporterCarrierFormState extends State<_ImporterCarrierForm> {
  final _company = TextEditingController();
  final _contactName = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _whatsapp = TextEditingController();
  final _baseEstado = TextEditingController();
  final _baseCiudad = TextEditingController();
  final _flatFee = TextEditingController();
  final _notes = TextEditingController();
  late Set<String> _pagoMetodos;
  late Map<String, TextEditingController> _instruccionesControllers;
  late String _fletePagoModo;
  late _TarifaModo _tarifa;
  late String _etaKey;
  bool _todoElPais = true;
  final Set<String> _estados = {};
  List<String> _ciudades = const [];
  double? _maxCoverageKm;
  int _step = 0;
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
      _baseEstado.text = e.baseEstado ?? '';
      _baseCiudad.text = e.baseCiudad ?? '';
      _notes.text = e.notes ?? '';
      _ciudades = List<String>.from(e.coverageCiudades);
      _maxCoverageKm = e.maxCoverageKm;
      _todoElPais = e.coverageEstados.isEmpty && e.coverageCiudades.isEmpty;
      for (final raw in e.coverageEstados) {
        final match = _matchEstado(raw);
        _estados.add(match ?? raw.trim());
      }
      _tarifa = _tarifaFrom(e);
      _etaKey = _etaKeyFromHours(e.etaBaseHours);
      if (_tarifa == _TarifaModo.fija && e.flatFeeUsd != null) {
        _flatFee.text = e.flatFeeUsd!.toStringAsFixed(2);
      }
      _pagoMetodos = e.acceptedPagoMetodos.toSet();
      _fletePagoModo = e.fletePagoModo;
    } else {
      _tarifa = _TarifaModo.agencia;
      _etaKey = _etaOpciones.first.key;
      _pagoMetodos = {'zelle_divisas'};
      _fletePagoModo = CarrierFletePagoModo.incluidoFactura;
    }
    _instruccionesControllers = _buildInstruccionesControllers(
      widget.existing?.pagoMetodoInstrucciones ?? const {},
    );
  }

  String? _matchEstado(String raw) {
    final key = raw.trim().toLowerCase();
    for (final estado in _estadosVenezuela) {
      if (estado.toLowerCase() == key) return estado;
    }
    return null;
  }

  _TarifaModo _tarifaFrom(ImporterCarrierModel carrier) {
    final flat = carrier.flatFeeUsd;
    final perKm = carrier.pricePerKmUsd;
    if (flat != null && flat <= 0 && (perKm == null || perKm <= 0)) {
      return _TarifaModo.gratis;
    }
    if (flat != null && flat > 0) return _TarifaModo.fija;
    return _TarifaModo.agencia;
  }

  String _etaKeyFromHours(double hours) {
    if (hours <= 36) return '24_48';
    if (hours <= 60) return '2_3';
    if (hours <= 96) return '3_5';
    return '5_7';
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
    _baseEstado.dispose();
    _baseCiudad.dispose();
    _flatFee.dispose();
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
        borderSide: BorderSide(color: AppColors.borderSubtle),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.brand, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    );
  }

  double? _parseOpt(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    return double.tryParse(t.replaceAll(',', '.'));
  }

  _EtaOpcion get _etaElegida =>
      _etaOpciones.firstWhere((e) => e.key == _etaKey, orElse: () => _etaOpciones.first);

  bool _datosEsencialesOk() {
    if (_company.text.trim().length < 2 || _phone.text.trim().length < 6) {
      _snack('Complete nombre de empresa y teléfono.');
      return false;
    }
    if (_tarifa == _TarifaModo.fija) {
      final monto = _parseOpt(_flatFee.text);
      if (monto == null || monto <= 0) {
        _snack('Indique la tarifa fija en USD.');
        return false;
      }
    }
    if (!_todoElPais && _estados.isEmpty) {
      _snack('Elija al menos un estado o marque todo el país.');
      return false;
    }
    return true;
  }

  void _siguiente() {
    if (!_datosEsencialesOk()) return;
    setState(() => _step = 1);
  }

  ({double? fija, double? porKm}) _tarifasParaGuardar() {
    switch (_tarifa) {
      case _TarifaModo.fija:
        return (fija: _parseOpt(_flatFee.text), porKm: null);
      case _TarifaModo.gratis:
        return (fija: 0, porKm: 0);
      case _TarifaModo.agencia:
        return (fija: null, porKm: null);
    }
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
    if (!_datosEsencialesOk()) {
      setState(() => _step = 0);
      return;
    }

    setState(() => _saving = true);
    try {
      final instrucciones = _instruccionesToSave();
      final tarifas = _tarifasParaGuardar();
      final common = (
        companyName: _company.text.trim(),
        contactPhone: _phone.text.trim(),
        contactName: _contactName.text.trim(),
        contactEmail: _email.text.trim(),
        contactWhatsapp: _whatsapp.text.trim(),
        coverageEstados: _todoElPais ? const <String>[] : _estados.toList(),
        coverageCiudades: _todoElPais ? const <String>[] : _ciudades,
        baseEstado: _baseEstado.text.trim(),
        baseCiudad: _baseCiudad.text.trim(),
        etaBaseHours: _etaElegida.horas,
        etaHoursPerKm: 0.0,
        maxCoverageKm: _maxCoverageKm,
        flatFeeUsd: tarifas.fija,
        pricePerKmUsd: tarifas.porKm,
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
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: _pasos(),
          ),
          Expanded(
            child: SingleChildScrollView(
              controller: widget.scrollController,
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: _step == 0 ? _pasoDatos() : _pasoPago(),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              8,
              20,
              MediaQuery.viewInsetsOf(context).bottom + 16,
            ),
            child: Row(
              children: [
                if (_step == 1)
                  OutlinedButton(
                    onPressed: _saving ? null : () => setState(() => _step = 0),
                    child: const Text('Atrás'),
                  ),
                const Spacer(),
                FilledButton(
                  onPressed: _saving ? null : (_step == 0 ? _siguiente : _save),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 14,
                    ),
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
                      : Text(
                          _step == 0 ? 'Siguiente' : 'Guardar transportista',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pasos() {
    return Row(
      children: [
        _pasoMarca(1, 'Datos', _step == 0),
        Expanded(
          child: Container(
            height: 2,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            color: _step == 1 ? AppColors.brand : AppColors.borderSubtle,
          ),
        ),
        _pasoMarca(2, 'Pago', _step == 1),
      ],
    );
  }

  Widget _pasoMarca(int numero, String label, bool activo) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: activo ? AppColors.brand : AppColors.brandBlueContainer,
          child: Text(
            '$numero',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: activo ? Colors.white : AppColors.brand,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: activo ? AppColors.brand : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _pasoDatos() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Transportista',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: AppColors.brandBlue,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _company,
          textCapitalization: TextCapitalization.words,
          decoration: _fieldDecoration(
            label: 'Empresa *',
            icon: Icons.business_outlined,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          decoration: _fieldDecoration(
            label: 'Teléfono *',
            icon: Icons.phone_outlined,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Cobertura',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: AppColors.brandBlue,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilterChip(
              label: const Text('Todo el país'),
              selected: _todoElPais,
              showCheckmark: false,
              selectedColor: AppColors.brand,
              labelStyle: TextStyle(
                fontWeight: FontWeight.w800,
                color: _todoElPais ? Colors.white : AppColors.textPrimary,
              ),
              side: BorderSide(
                color: _todoElPais ? AppColors.brand : AppColors.borderSubtle,
              ),
              onSelected: (_) => setState(() {
                _todoElPais = true;
                _estados.clear();
              }),
            ),
            FilterChip(
              label: const Text('Estados'),
              selected: !_todoElPais,
              showCheckmark: false,
              selectedColor: AppColors.brand,
              labelStyle: TextStyle(
                fontWeight: FontWeight.w800,
                color: !_todoElPais ? Colors.white : AppColors.textPrimary,
              ),
              side: BorderSide(
                color: !_todoElPais ? AppColors.brand : AppColors.borderSubtle,
              ),
              onSelected: (_) => setState(() => _todoElPais = false),
            ),
          ],
        ),
        if (!_todoElPais) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final estado in _estadosVisibles)
                FilterChip(
                  label: Text(estado),
                  selected: _estados.contains(estado),
                  showCheckmark: false,
                  visualDensity: VisualDensity.compact,
                  selectedColor: AppColors.brandBlueContainer,
                  labelStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                  onSelected: (selected) => setState(() {
                    if (selected) {
                      _estados.add(estado);
                    } else {
                      _estados.remove(estado);
                    }
                  }),
                ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _etaKey,
          decoration: _fieldDecoration(label: 'Tiempo estimado'),
          items: [
            for (final opcion in _etaOpciones)
              DropdownMenuItem(value: opcion.key, child: Text(opcion.label)),
          ],
          onChanged: _saving
              ? null
              : (value) {
                  if (value == null) return;
                  setState(() => _etaKey = value);
                },
        ),
        const SizedBox(height: 16),
        const Text(
          'Tarifa',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: AppColors.brandBlue,
          ),
        ),
        const SizedBox(height: 8),
        SegmentedButton<_TarifaModo>(
          style: _segmentedStyle(),
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: _TarifaModo.fija, label: Text('Fija')),
            ButtonSegment(value: _TarifaModo.agencia, label: Text('Agencia')),
            ButtonSegment(value: _TarifaModo.gratis, label: Text('Gratis')),
          ],
          selected: {_tarifa},
          onSelectionChanged: _saving
              ? null
              : (value) => setState(() => _tarifa = value.first),
        ),
        const SizedBox(height: 6),
        Text(
          _tarifaAyuda,
          style: TextStyle(
            fontSize: 12.5,
            height: 1.35,
            color: AppColors.textSecondary,
          ),
        ),
        if (_tarifa == _TarifaModo.fija) ...[
          const SizedBox(height: 10),
          TextField(
            controller: _flatFee,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            decoration: _fieldDecoration(
              label: 'Monto fijo (USD)',
              hint: '5.00',
              icon: Icons.attach_money,
            ),
          ),
        ],
      ],
    );
  }

  List<String> get _estadosVisibles {
    final extra = _estados.where((e) => !_estadosVenezuela.contains(e));
    return [..._estadosVenezuela, ...extra];
  }

  String get _tarifaAyuda {
    switch (_tarifa) {
      case _TarifaModo.fija:
        return 'La tienda ve un monto fijo, por ejemplo 5.00 USD.';
      case _TarifaModo.agencia:
        return 'Según tarifa de la agencia, con cobro en destino. No se estima por kilómetro.';
      case _TarifaModo.gratis:
        return 'El envío no suma tarifa en el pedido.';
    }
  }

  Widget _pasoPago() {
    final tieneExtra = _contactName.text.trim().isNotEmpty ||
        _email.text.trim().isNotEmpty ||
        _whatsapp.text.trim().isNotEmpty ||
        _notes.text.trim().isNotEmpty ||
        _baseEstado.text.trim().isNotEmpty ||
        _baseCiudad.text.trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Pago del flete',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: AppColors.brandBlue,
          ),
        ),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          style: _segmentedStyle(),
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(
              value: CarrierFletePagoModo.incluidoFactura,
              label: Text('En la factura'),
            ),
            ButtonSegment(
              value: CarrierFletePagoModo.pagoSeparado,
              label: Text('Pago aparte'),
            ),
          ],
          selected: {_fletePagoModo},
          onSelectionChanged: _saving
              ? null
              : (value) => setState(() => _fletePagoModo = value.first),
        ),
        const SizedBox(height: 6),
        Text(
          _fletePagoModo == CarrierFletePagoModo.incluidoFactura
              ? 'El flete va en la factura del proveedor.'
              : 'La tienda paga el flete directo al transportista.',
          style: TextStyle(
            fontSize: 12.5,
            height: 1.35,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Métodos de pago',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: AppColors.brandBlue,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Opcional. Si indica datos de cuenta, la tienda los ve al elegir este transportista.',
          style: TextStyle(
            fontSize: 12.5,
            height: 1.35,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final code in PagoMetodo.valuesMotoconecta)
              FilterChip(
                label: Text(PagoMetodo.labelEs(code)),
                selected: _pagoMetodos.contains(code),
                showCheckmark: false,
                selectedColor: AppColors.brand,
                labelStyle: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: _pagoMetodos.contains(code)
                      ? Colors.white
                      : AppColors.textPrimary,
                ),
                side: BorderSide(
                  color: _pagoMetodos.contains(code)
                      ? AppColors.brand
                      : AppColors.borderSubtle,
                ),
                onSelected: _saving
                    ? null
                    : (selected) => setState(() {
                          if (selected) {
                            _pagoMetodos.add(code);
                          } else {
                            _pagoMetodos.remove(code);
                          }
                        }),
              ),
          ],
        ),
        for (final code in PagoMetodo.valuesMotoconecta)
          if (_pagoMetodos.contains(code)) ...[
            const SizedBox(height: 10),
            TextField(
              controller: _instruccionesControllers[code],
              minLines: 1,
              maxLines: 3,
              decoration: _fieldDecoration(
                label: 'Datos de ${PagoMetodo.labelEs(code)}',
                hint: 'Opcional',
              ),
            ),
          ],
        const SizedBox(height: 8),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          initiallyExpanded: tieneExtra,
          title: const Text(
            'Contacto y notas',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          ),
          subtitle: Text(
            'Opcional. No hace falta para guardar.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          children: [
            TextField(
              controller: _contactName,
              decoration: _fieldDecoration(label: 'Persona de contacto'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: _fieldDecoration(label: 'Correo'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _whatsapp,
              keyboardType: TextInputType.phone,
              decoration: _fieldDecoration(label: 'WhatsApp'),
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
            const SizedBox(height: 10),
            TextField(
              controller: _notes,
              minLines: 2,
              maxLines: 3,
              decoration: _fieldDecoration(label: 'Notas internas'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ],
    );
  }

  ButtonStyle _segmentedStyle() {
    return ButtonStyle(
      visualDensity: VisualDensity.compact,
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return Colors.white;
        return AppColors.brand;
      }),
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return AppColors.brand;
        return AppColors.brandBlueContainer;
      }),
      side: WidgetStateProperty.all(
        BorderSide(color: AppColors.borderSubtle),
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
        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
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
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
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
            color: AppColors.textPrimary,
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
                      color: AppColors.textPrimary,
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
