import 'package:flutter/material.dart';
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
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Form(
            key: _form,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Pedido mínimo',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  const Text(
                      'Monto mínimo por pedido. Usa 0 para permitir pedidos sin monto mínimo.'),
                  const SizedBox(height: 16),
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
                  const SizedBox(height: 16),
                  TextFormField(
                      controller: _amount,
                      enabled: !_saving,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                          labelText: 'Monto mínimo en ${_currency.unitLabel}'),
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
                            child: const Text('Cancelar')),
                        FilledButton(
                            onPressed: _saving ? null : _save,
                            child: Text(
                                _saving ? 'Guardando…' : 'Guardar mínimo')),
                      ]),
                ])),
        const SizedBox(height: 24),
        ImporterAcceptedPagoMetodosSection(
            profile: widget.profile, onSaved: widget.onChanged),
        const SizedBox(height: 20),
        const ImporterEnvioPoliticaPanel(),
      ]);
}
