import 'package:flutter/material.dart';

import '../models/pago_metodo.dart';
import '../models/profile_model.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';

/// Importador: métodos de pago que el aliado puede elegir al registrar comprobante.
class ImporterAcceptedPagoMetodosSection extends StatefulWidget {
  const ImporterAcceptedPagoMetodosSection({
    super.key,
    required this.profile,
    this.onSaved,
  });

  final ProfileModel profile;
  final VoidCallback? onSaved;

  @override
  State<ImporterAcceptedPagoMetodosSection> createState() =>
      _ImporterAcceptedPagoMetodosSectionState();
}

class _ImporterAcceptedPagoMetodosSectionState
    extends State<ImporterAcceptedPagoMetodosSection> {
  late Set<String> _selected;
  bool _saving = false;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _selected = _initialSelection(widget.profile);
  }

  @override
  void didUpdateWidget(covariant ImporterAcceptedPagoMetodosSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile.id != widget.profile.id ||
        oldWidget.profile.acceptedPagoMetodos !=
            widget.profile.acceptedPagoMetodos) {
      _selected = _initialSelection(widget.profile);
      _dirty = false;
    }
  }

  Set<String> _initialSelection(ProfileModel profile) {
    final accepted = profile.acceptedPagoMetodos;
    if (accepted == null || accepted.isEmpty) {
      return PagoMetodo.valuesMotoconecta.toSet();
    }
    return accepted.toSet();
  }

  Future<void> _save() async {
    if (_selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleccione al menos un método de pago.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await SupabaseService.importadorSetAcceptedPagoMetodos(
        _selected.toList(),
      );
      if (!mounted) return;
      setState(() => _dirty = false);
      widget.onSaved?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Métodos de pago actualizados.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'MÉTODOS DE PAGO ACEPTADOS',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'El aliado solo verá los métodos que active aquí al adjuntar el comprobante. '
          'Zelle, Binance, USDT y efectivo pueden activar el descuento en divisas del catálogo.',
          style: TextStyle(
            fontSize: 11.5,
            height: 1.35,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 10),
        ...PagoMetodo.valuesMotoconecta.map((code) {
          final checked = _selected.contains(code);
          return CheckboxListTile(
            value: checked,
            onChanged: _saving
                ? null
                : (v) {
                    setState(() {
                      if (v == true) {
                        _selected.add(code);
                      } else {
                        _selected.remove(code);
                      }
                      _dirty = true;
                    });
                  },
            dense: true,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(
              PagoMetodo.labelEs(code),
              style: const TextStyle(fontSize: 13.5),
            ),
            subtitle: PagoMetodo.qualifiesForUsdDiscount(code)
                ? Text(
                    'Elegible para descuento divisas/efectivo del producto',
                    style: TextStyle(fontSize: 10.5, color: Colors.green.shade800),
                  )
                : null,
          );
        }),
        if (_dirty) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Guardar métodos de pago'),
            ),
          ),
        ],
      ],
    );
  }
}
