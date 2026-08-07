import 'package:flutter/material.dart';

import '../models/pago_metodo.dart';
import '../models/profile_model.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import 'profile_section_helpers.dart';

/// Importador: métodos aceptados + datos de cuenta para que el aliado transfiera.
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
  late Map<String, TextEditingController> _instruccionesControllers;
  late bool _pagoSoloDivisas;
  bool _saving = false;
  bool _dirty = false;
  bool _soloDivisasDirty = false;

  @override
  void initState() {
    super.initState();
    _pagoSoloDivisas = widget.profile.pagoSoloDivisas;
    _selected = _initialSelection(widget.profile);
    _instruccionesControllers = _buildControllers(widget.profile);
  }

  @override
  void didUpdateWidget(covariant ImporterAcceptedPagoMetodosSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile.id != widget.profile.id ||
        oldWidget.profile.acceptedPagoMetodos !=
            widget.profile.acceptedPagoMetodos ||
        oldWidget.profile.pagoMetodoInstrucciones !=
            widget.profile.pagoMetodoInstrucciones ||
        oldWidget.profile.pagoSoloDivisas != widget.profile.pagoSoloDivisas) {
      _disposeControllers();
      _pagoSoloDivisas = widget.profile.pagoSoloDivisas;
      _selected = _initialSelection(widget.profile);
      _instruccionesControllers = _buildControllers(widget.profile);
      _dirty = false;
      _soloDivisasDirty = false;
    }
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  void _disposeControllers() {
    for (final c in _instruccionesControllers.values) {
      c.dispose();
    }
  }

  Set<String> _initialSelection(ProfileModel profile) {
    final accepted = profile.effectiveAcceptedPagoMetodos;
    return accepted.toSet();
  }

  Map<String, TextEditingController> _buildControllers(ProfileModel profile) {
    final map = <String, TextEditingController>{};
    for (final code in PagoMetodo.valuesMotoconecta) {
      map[code] = TextEditingController(
        text: profile.pagoMetodoInstrucciones[code] ?? '',
      );
    }
    return map;
  }

  Map<String, String> _instruccionesToSave() {
    final out = <String, String>{};
    for (final code in _selected) {
      final text = _instruccionesControllers[code]?.text.trim() ?? '';
      if (text.isNotEmpty) {
        out[code] = text;
      }
    }
    return out;
  }

  List<String> get _visibleMetodos {
    if (_pagoSoloDivisas) {
      return PagoMetodo.valuesMotoconecta
          .where((m) => !PagoMetodo.isBolivares(m))
          .toList();
    }
    return PagoMetodo.valuesMotoconecta;
  }

  int get _selectedDivisasCount => _selected
      .where((m) => !PagoMetodo.isBolivares(m))
      .length;

  Future<void> _onSoloDivisasChanged(bool? value) async {
    if (value == null || _saving) return;
    if (value == _pagoSoloDivisas) return;

    if (value) {
      if (_selectedDivisasCount == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Active al menos un método en divisas (Zelle, Binance, USDT o efectivo) '
              'antes de deshabilitar pagos en Bs.',
            ),
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Solo pagos en divisas (USD)'),
          content: const Text(
            'Los aliados ya no podrán pagar en bolívares (Pago Móvil ni transferencia en Bs). '
            'Se quitarán los descuentos línea USD de todos sus productos; '
            'los descuentos por volumen se mantienen.\n\n¿Continuar?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Activar'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }

    setState(() {
      _pagoSoloDivisas = value;
      _soloDivisasDirty = true;
      if (value) {
        _selected.removeWhere(PagoMetodo.isBolivares);
      }
      _dirty = _dirty || value;
    });
  }

  Future<void> _save() async {
    if (_selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleccione al menos un método de pago.')),
      );
      return;
    }

    if (_pagoSoloDivisas && _selectedDivisasCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Con pagos solo en USD debe tener al menos un método en divisas activo.',
          ),
        ),
      );
      return;
    }

    final sinDatos = _selected.where((code) {
      final t = _instruccionesControllers[code]?.text.trim() ?? '';
      return t.isEmpty;
    }).toList();
    if (sinDatos.isNotEmpty) {
      final labels = sinDatos.map(PagoMetodo.labelEs).join(', ');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Complete los datos de transferencia para: $labels. '
            'El aliado los verá al elegir cada método.',
          ),
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      if (_soloDivisasDirty) {
        await SupabaseService.importadorSetPagoSoloDivisas(_pagoSoloDivisas);
      }
      await SupabaseService.importadorSetAcceptedPagoMetodos(
        _selected.toList(),
      );
      await SupabaseService.importadorSetPagoMetodoInstrucciones(
        _instruccionesToSave(),
      );
      if (!mounted) return;
      setState(() {
        _dirty = false;
        _soloDivisasDirty = false;
      });
      widget.onSaved?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _pagoSoloDivisas
                ? 'Pagos solo en USD activados. Métodos y cuentas actualizados.'
                : 'Métodos y datos de pago actualizados.',
          ),
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

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  String _pagoSectionSubtitle() {
    final n = _selected.length;
    if (n == 0) return 'Ningún método activo';
    if (n == 1) return '1 método activo';
    return '$n métodos activos';
  }

  @override
  Widget build(BuildContext context) {
    final showSave = _dirty || _soloDivisasDirty;

    return ProfileCollapsibleSection(
      title: 'Métodos de pago y cuentas',
      subtitle: _pagoSectionSubtitle(),
      initiallyExpanded: false,
      infoMessage:
          'Active los métodos que acepta e indique los datos de cada cuenta. '
          'El aliado los verá al pagar el pedido.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Colors.white,
            borderRadius: AppDecorations.radius12,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: AppDecorations.radius12,
                border: Border.all(
                  color: _pagoSoloDivisas
                      ? Colors.green.shade400
                      : AppColors.borderSubtle,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: SwitchListTile(
                        value: _pagoSoloDivisas,
                        onChanged: _saving ? null : _onSoloDivisasChanged,
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Solo pagos en divisas (USD)',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const ProfileInfoIcon(
                      title: 'Solo pagos en divisas',
                      message:
                          'Si lo activa, los aliados solo podrán pagar en Zelle, Binance, USDT o efectivo. '
                          'Se ocultan Pago Móvil y transferencia en Bs y no podrá ofrecer descuento línea USD; '
                          'los descuentos por volumen se mantienen.',
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          ..._visibleMetodos.map(
            (code) => _ImporterPagoMetodoTile(
              code: code,
              checked: _selected.contains(code),
              saving: _saving,
              controller: _instruccionesControllers[code]!,
              showUsdDiscountInfo: !_pagoSoloDivisas &&
                  PagoMetodo.qualifiesForUsdDiscount(code),
              onCheckedChanged: (v) {
                setState(() {
                  if (v) {
                    _selected.add(code);
                  } else {
                    _selected.remove(code);
                  }
                  _dirty = true;
                });
              },
              onInstructionsChanged: _markDirty,
            ),
          ),
          if (showSave) ...[
            const SizedBox(height: 4),
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
                    : const Text('Guardar métodos y cuentas'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ImporterPagoMetodoTile extends StatefulWidget {
  const _ImporterPagoMetodoTile({
    required this.code,
    required this.checked,
    required this.saving,
    required this.controller,
    required this.showUsdDiscountInfo,
    required this.onCheckedChanged,
    required this.onInstructionsChanged,
  });

  final String code;
  final bool checked;
  final bool saving;
  final TextEditingController controller;
  final bool showUsdDiscountInfo;
  final ValueChanged<bool> onCheckedChanged;
  final VoidCallback onInstructionsChanged;

  @override
  State<_ImporterPagoMetodoTile> createState() => _ImporterPagoMetodoTileState();
}

class _ImporterPagoMetodoTileState extends State<_ImporterPagoMetodoTile> {
  bool _detailsOpen = false;

  @override
  void didUpdateWidget(covariant _ImporterPagoMetodoTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.checked && widget.checked) {
      _detailsOpen = true;
    }
    if (!widget.checked) {
      _detailsOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasData = widget.controller.text.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: AppDecorations.radius12,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: AppDecorations.radius12,
            border: Border.all(
              color: widget.checked
                  ? AppColors.brandBlue.withOpacity(0.35)
                  : AppColors.borderSubtle,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CheckboxListTile(
                value: widget.checked,
                onChanged: widget.saving
                    ? null
                    : (v) => widget.onCheckedChanged(v == true),
                dense: true,
                contentPadding: const EdgeInsets.fromLTRB(4, 0, 8, 0),
                controlAffinity: ListTileControlAffinity.leading,
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        PagoMetodo.labelEs(widget.code),
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (widget.showUsdDiscountInfo)
                      const ProfileInfoIcon(
                        title: 'Descuento en catálogo',
                        message:
                            'Este método puede aplicar al descuento por pago en divisas o efectivo en su catálogo.',
                        iconSize: 16,
                      ),
                  ],
                ),
                secondary: widget.checked
                    ? IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: _detailsOpen
                            ? 'Ocultar datos de cuenta'
                            : 'Ver datos de cuenta',
                        onPressed: widget.saving
                            ? null
                            : () => setState(() => _detailsOpen = !_detailsOpen),
                        icon: Icon(
                          _detailsOpen ? Icons.expand_less : Icons.expand_more,
                          color: AppColors.textSecondary,
                        ),
                      )
                    : null,
              ),
              if (widget.checked && !_detailsOpen && hasData)
                Padding(
                  padding: const EdgeInsets.fromLTRB(48, 0, 12, 8),
                  child: Text(
                    'Datos registrados · toque ⌄ para editar',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              if (widget.checked && _detailsOpen)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                  child: TextFormField(
                    controller: widget.controller,
                    enabled: !widget.saving,
                    maxLines: 4,
                    minLines: 3,
                    maxLength: 2000,
                    onChanged: (_) => widget.onInstructionsChanged(),
                    decoration: InputDecoration(
                      labelText: 'Datos para transferencia',
                      alignLabelWithHint: true,
                      hintText: PagoMetodo.instructionHintEs(widget.code),
                      hintMaxLines: 6,
                      border: const OutlineInputBorder(),
                      isDense: true,
                      counterText: '',
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
