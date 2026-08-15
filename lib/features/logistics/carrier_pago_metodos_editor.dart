import 'package:flutter/material.dart';

import 'package:motolink_pro_app/features/payments/pago_metodo.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';

/// Editor de métodos de pago y datos de cuenta para transportistas.
class CarrierPagoMetodosEditor extends StatelessWidget {
  const CarrierPagoMetodosEditor({
    super.key,
    required this.selected,
    required this.controllers,
    required this.saving,
    required this.onSelectionChanged,
    required this.onInstructionsChanged,
  });

  final Set<String> selected;
  final Map<String, TextEditingController> controllers;
  final bool saving;
  final void Function(String code, bool checked) onSelectionChanged;
  final VoidCallback onInstructionsChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Indique los datos de cada método activo. '
          'El aliado los verá al elegir transportista en el checkout.',
          style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.4),
        ),
        const SizedBox(height: 10),
        ...PagoMetodo.valuesMotoconecta.map(
          (code) => _CarrierPagoMetodoTile(
            code: code,
            checked: selected.contains(code),
            saving: saving,
            controller: controllers[code]!,
            onCheckedChanged: (v) => onSelectionChanged(code, v),
            onInstructionsChanged: onInstructionsChanged,
          ),
        ),
      ],
    );
  }
}

class _CarrierPagoMetodoTile extends StatefulWidget {
  const _CarrierPagoMetodoTile({
    required this.code,
    required this.checked,
    required this.saving,
    required this.controller,
    required this.onCheckedChanged,
    required this.onInstructionsChanged,
  });

  final String code;
  final bool checked;
  final bool saving;
  final TextEditingController controller;
  final ValueChanged<bool> onCheckedChanged;
  final VoidCallback onInstructionsChanged;

  @override
  State<_CarrierPagoMetodoTile> createState() => _CarrierPagoMetodoTileState();
}

class _CarrierPagoMetodoTileState extends State<_CarrierPagoMetodoTile> {
  bool _detailsOpen = false;

  @override
  void didUpdateWidget(covariant _CarrierPagoMetodoTile oldWidget) {
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
                title: Text(
                  PagoMetodo.labelEs(widget.code),
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
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
                      labelText: 'Datos para el aliado',
                      alignLabelWithHint: true,
                      hintText: PagoMetodo.instructionHintEs(widget.code),
                      hintMaxLines: 6,
                      filled: true,
                      fillColor: AppColors.fieldFill,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
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
