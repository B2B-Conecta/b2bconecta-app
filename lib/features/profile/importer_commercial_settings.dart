import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'package:motolink_pro_app/core/layout/app_breakpoints.dart';
import 'package:motolink_pro_app/features/cart/min_order_currency.dart';
import 'package:motolink_pro_app/features/logistics/importer_envio_politica_panel.dart';
import 'package:motolink_pro_app/features/payments/importer_accepted_pago_metodos_section.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'profile_model.dart';
import 'profile_service.dart';

class ImporterCommercialSettings extends StatefulWidget {
  const ImporterCommercialSettings(
      {super.key, required this.profile, this.onChanged});
  final ProfileModel profile;
  final VoidCallback? onChanged;

  /// Diálogo de escritorio con la sección de monto mínimo.
  static Future<void> openDesktop(
    BuildContext context, {
    required ProfileModel profile,
    VoidCallback? onChanged,
  }) {
    final theme = B2BThemeExtension.of(context);
    return showDialog<void>(
      context: context,
      barrierColor: theme.textPrimary.withOpacity(0.45),
      builder: (ctx) => Dialog(
        backgroundColor: theme.dialogSurface,
        surfaceTintColor: theme.dialogSurface,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: theme.borderSubtle),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 560,
            maxHeight: MediaQuery.sizeOf(ctx).height * 0.86,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Configuración comercial',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: theme.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Cerrar',
                      onPressed: () => Navigator.pop(ctx),
                      icon: Icon(Icons.close, color: theme.textSecondary),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                  child: ImporterCommercialSettings(
                    profile: profile,
                    onChanged: onChanged,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  @override
  State<ImporterCommercialSettings> createState() =>
      _ImporterCommercialSettingsState();
}

class _ImporterCommercialSettingsState
    extends State<ImporterCommercialSettings> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _amount;
  late MinOrderCurrency _currency;
  late double _savedAmount;
  late MinOrderCurrency _savedCurrency;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _savedAmount = widget.profile.minOrderAmountRef;
    _savedCurrency = MinOrderCurrency.parse(widget.profile.minOrderCurrency);
    _currency = _savedCurrency;
    _amount = TextEditingController(text: _savedAmount.toStringAsFixed(2));
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  double? get _value =>
      double.tryParse(_amount.text.trim().replaceAll(',', '.'));

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ProfileService.updateMyMinimumOrder(
          amount: _value!, currency: _currency.dbValue);
      if (!mounted) return;
      _savedAmount = _value!;
      _savedCurrency = _currency;
      widget.onChanged?.call();
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pedido mínimo guardado.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(SupabaseService.profileSaveErrorMessage(error))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _cancel() {
    setState(() {
      _amount.text = _savedAmount.toStringAsFixed(2);
      _currency = _savedCurrency;
    });
    _form.currentState?.reset();
  }

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final desktop =
        MediaQuery.sizeOf(context).width >= AppBreakpoints.mobileMenu;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (desktop)
          _ImporterMinUsdSection(
            profile: widget.profile,
            onChanged: widget.onChanged,
          )
        else
        Form(
            key: _form,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Pedido mínimo',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: theme.textPrimary,
                      )),
                  const SizedBox(height: 4),
                  Text('0 = sin mínimo.',
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.textSecondary,
                      )),
                  const SizedBox(height: 12),
                  SegmentedButton<MinOrderCurrency>(
                      segments: const [
                        ButtonSegment(
                            value: MinOrderCurrency.ref, label: Text('REF')),
                        ButtonSegment(
                            value: MinOrderCurrency.usd, label: Text('USD')),
                      ],
                      selected: {
                        _currency
                      },
                      onSelectionChanged: _saving
                          ? null
                          : (values) =>
                              setState(() => _currency = values.first)),
                  const SizedBox(height: 12),
                  TextFormField(
                      controller: _amount,
                      enabled: !_saving,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                          labelText: 'Monto mínimo en ${_currency.unitLabel}',
                          filled: true,
                          fillColor: theme.inputFill,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: theme.borderSubtle),
                          ),
                      ),
                      validator: (_) =>
                          _value == null || !_value!.isFinite || _value! < 0
                              ? 'Indique un monto válido, mayor o igual a 0.'
                              : null),
                  const SizedBox(height: 12),
                  Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        TextButton(
                            onPressed: _saving ? null : _cancel,
                            style: TextButton.styleFrom(
                              foregroundColor: theme.textSecondary,
                              minimumSize: const Size(0, 40),
                            ),
                            child: const Text('Cancelar')),
                        FilledButton(
                            onPressed: _saving ? null : _save,
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(0, 40),
                            ),
                            child: Text(
                                _saving ? 'Guardando…' : 'Guardar mínimo')),
                      ]),
                ])),
        if (desktop) ...[
          const SizedBox(height: 20),
          _ImporterMinUnitsSection(
            profile: widget.profile,
            onChanged: widget.onChanged,
          ),
        ],
        const SizedBox(height: 16),
        ImporterAcceptedPagoMetodosSection(
            profile: widget.profile, onSaved: widget.onChanged),
        const SizedBox(height: 20),
        const ImporterEnvioPoliticaPanel(),
      ]);
  }
}

/// Monto mínimo en USD. Solo se pinta en el panel de escritorio.
class _ImporterMinUsdSection extends StatefulWidget {
  const _ImporterMinUsdSection({required this.profile, this.onChanged});

  final ProfileModel profile;
  final VoidCallback? onChanged;

  @override
  State<_ImporterMinUsdSection> createState() => _ImporterMinUsdSectionState();
}

class _ImporterMinUsdSectionState extends State<_ImporterMinUsdSection> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _amount;
  late String _savedText;
  bool _saving = false;

  bool get _hasOwnUsd =>
      widget.profile.minOrderAmountRef > 0 &&
      MinOrderCurrency.parse(widget.profile.minOrderCurrency) ==
          MinOrderCurrency.usd;

  @override
  void initState() {
    super.initState();
    _savedText =
        _hasOwnUsd ? widget.profile.minOrderAmountRef.toStringAsFixed(2) : '';
    _amount = TextEditingController(text: _savedText);
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  double? get _value {
    final raw = _amount.text.trim();
    if (raw.isEmpty) return 0;
    return double.tryParse(raw.replaceAll(',', '.'));
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    final amount = _value;
    if (amount == null) return;
    setState(() => _saving = true);
    try {
      await ProfileService.updateMyMinimumOrder(amount: amount, currency: 'usd');
      if (!mounted) return;
      _savedText = amount <= 0 ? '' : amount.toStringAsFixed(2);
      widget.onChanged?.call();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(amount <= 0
            ? 'Sin monto propio: los pedidos no exigen un piso.'
            : 'Monto mínimo guardado.'),
      ));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(SupabaseService.profileSaveErrorMessage(error)),
      ));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _cancel() {
    setState(() => _amount.text = _savedText);
    _form.currentState?.reset();
  }

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final own = _value != null && _value! > 0;
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Monto mínimo en USD',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: theme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Si dejas el campo vacío, tus pedidos no tienen monto mínimo. '
            'El número que guardes se exige en el carrito web.',
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: theme.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _amount,
            enabled: !_saving,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Monto mínimo en USD',
              helperText: own
                  ? 'Los pedidos por debajo de este monto no se confirman.'
                  : 'Vacío: no hay monto mínimo.',
              filled: true,
              fillColor: theme.inputFill,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: theme.borderSubtle),
              ),
            ),
            validator: (_) {
              final raw = _amount.text.trim();
              if (raw.isEmpty) return null;
              final n = double.tryParse(raw.replaceAll(',', '.'));
              if (n == null || !n.isFinite || n < 0) {
                return 'Indique un monto válido, mayor o igual a 0.';
              }
              return null;
            },
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              TextButton(
                onPressed: _saving ? null : _cancel,
                style: TextButton.styleFrom(
                  foregroundColor: theme.textSecondary,
                  minimumSize: const Size(0, 40),
                ),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                child: Text(_saving ? 'Guardando…' : 'Guardar mínimo'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Mínimo de unidades por pedido. Solo se pinta en el panel de escritorio.
class _ImporterMinUnitsSection extends StatefulWidget {
  const _ImporterMinUnitsSection({required this.profile, this.onChanged});

  final ProfileModel profile;
  final VoidCallback? onChanged;

  @override
  State<_ImporterMinUnitsSection> createState() =>
      _ImporterMinUnitsSectionState();
}

class _ImporterMinUnitsSectionState extends State<_ImporterMinUnitsSection> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _units;
  int? _saved;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _saved = widget.profile.minOrderUnits;
    _units = TextEditingController(text: _saved?.toString() ?? '');
  }

  @override
  void didUpdateWidget(covariant _ImporterMinUnitsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile.minOrderUnits != widget.profile.minOrderUnits &&
        !_saving) {
      _saved = widget.profile.minOrderUnits;
      _units.text = _saved?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _units.dispose();
    super.dispose();
  }

  int? get _value {
    final raw = _units.text.trim();
    if (raw.isEmpty) return null;
    return int.tryParse(raw);
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ProfileService.updateMyMinimumOrderUnits(_value);
      if (!mounted) return;
      _saved = _value;
      widget.onChanged?.call();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_value == null
            ? 'Sin unidades mínimas: los pedidos no exigen un piso.'
            : 'Mínimo de $_value unidades guardado.'),
      ));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(SupabaseService.profileSaveErrorMessage(error))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _cancel() {
    setState(() => _units.text = _saved?.toString() ?? '');
    _form.currentState?.reset();
  }

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final own = _value != null && _value! >= 1;
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Unidades mínimas por pedido',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: theme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Suma todas las unidades de tu catálogo en un mismo pedido, '
            'aunque sean de varios productos. Si no escribes un número, '
            'no hay mínimo de unidades.',
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: theme.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _units,
            enabled: !_saving,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: 'Unidades mínimas',
              helperText: own
                  ? 'Este pedido debe sumar al menos ${_value!} unidades.'
                  : 'Vacío: no hay mínimo de unidades.',
              filled: true,
              fillColor: theme.inputFill,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: theme.borderSubtle),
              ),
            ),
            validator: (_) {
              final raw = _units.text.trim();
              if (raw.isEmpty) return null;
              final n = int.tryParse(raw);
              if (n == null || n < 1) return 'Indica un entero de 1 o más.';
              return null;
            },
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              TextButton(
                onPressed: _saving ? null : _cancel,
                style: TextButton.styleFrom(
                  foregroundColor: theme.textSecondary,
                  minimumSize: const Size(0, 40),
                ),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                child: Text(_saving ? 'Guardando…' : 'Guardar unidades'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
