import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/product_custom_fields.dart';

/// Muestra campos ERP configurados (solo lectura, vista importador).
class ProductCustomFieldsChips extends StatelessWidget {
  const ProductCustomFieldsChips({
    super.key,
    required this.customFields,
    this.limit = 3,
  });

  final Map<String, dynamic>? customFields;
  final int limit;

  @override
  Widget build(BuildContext context) {
    final entries = productCustomFieldsDisplayEntries(customFields, limit: limit);
    if (entries.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: entries.map(_chip).toList(),
      ),
    );
  }

  Widget _chip(ProductCustomFieldEntry e) {
    final internal = !e.visibleToAliado;
    return Chip(
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      avatar: Icon(
        internal ? Icons.lock_outline : Icons.visibility_outlined,
        size: 14,
        color: internal ? AppColors.textSecondary : AppColors.successGreen,
      ),
      backgroundColor: internal
          ? AppColors.brandBlueContainer.withOpacity(0.55)
          : Colors.green.shade50,
      label: Text(
        '${e.label}: ${e.value}${internal ? '' : ' · aliado'}',
        style: const TextStyle(fontSize: 10.5, height: 1.2),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// Bloque de campos ERP visibles para el aliado en ficha de producto.
class ProductCustomFieldsAliadoSpecs extends StatelessWidget {
  const ProductCustomFieldsAliadoSpecs({
    super.key,
    required this.customFields,
  });

  final Map<String, dynamic>? customFields;

  @override
  Widget build(BuildContext context) {
    final entries =
        productCustomFieldsDisplayEntries(customFields, aliadoView: true);
    if (entries.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final e in entries) ...[
          _AliadoSpecRow(label: e.label, value: e.value),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _AliadoSpecRow extends StatelessWidget {
  const _AliadoSpecRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: AppDecorations.radius12,
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Colors.grey.shade600,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: Colors.grey.shade800,
            ),
          ),
        ],
      ),
    );
  }
}

/// Editor de pares clave-valor para la ficha del producto.
class ProductCustomFieldsEditor extends StatefulWidget {
  const ProductCustomFieldsEditor({
    super.key,
    required this.initial,
    required this.onChanged,
    this.enabled = true,
  });

  final Map<String, dynamic> initial;
  final ValueChanged<Map<String, dynamic>> onChanged;
  final bool enabled;

  @override
  State<ProductCustomFieldsEditor> createState() =>
      _ProductCustomFieldsEditorState();
}

class _CustomFieldRow {
  _CustomFieldRow({
    required this.fieldKey,
    required this.label,
    required this.value,
    required this.visibleToAliado,
  });

  String fieldKey;
  final TextEditingController label;
  final TextEditingController value;
  bool visibleToAliado;
}

class _ProductCustomFieldsEditorState extends State<ProductCustomFieldsEditor> {
  final List<_CustomFieldRow> _rows = [];

  @override
  void initState() {
    super.initState();
    _loadInitial(widget.initial);
  }

  @override
  void dispose() {
    for (final r in _rows) {
      r.label.dispose();
      r.value.dispose();
    }
    super.dispose();
  }

  void _loadInitial(Map<String, dynamic> initial) {
    for (final r in _rows) {
      r.label.dispose();
      r.value.dispose();
    }
    _rows.clear();

    final visible = parseAliadoVisibleCustomFieldKeys(initial);
    final values = productCustomFieldValues(initial);
    for (final e in values.entries) {
      _rows.add(
        _CustomFieldRow(
          fieldKey: e.key,
          label: TextEditingController(
            text: formatProductCustomFieldLabel(e.key),
          ),
          value: TextEditingController(text: e.value.toString()),
          visibleToAliado: visible.contains(e.key),
        ),
      );
    }
  }

  void _notify() {
    final values = <String, dynamic>{};
    final visibleKeys = <String>{};

    for (final r in _rows) {
      final label = r.label.text.trim();
      final value = r.value.text.trim();
      if (label.isEmpty || value.isEmpty) continue;

      final key = slugProductCustomFieldKey(label);
      r.fieldKey = key;
      values[key] = value;
      if (r.visibleToAliado) visibleKeys.add(key);
    }

    widget.onChanged(
      buildCustomFieldsPayload(
        values: values,
        aliadoVisibleKeys: visibleKeys,
      ),
    );
  }

  void _addRow({String? label, String? value}) {
    setState(() {
      _rows.add(
        _CustomFieldRow(
          fieldKey: '',
          label: TextEditingController(text: label ?? ''),
          value: TextEditingController(text: value ?? ''),
          visibleToAliado: false,
        ),
      );
    });
    _notify();
  }

  void _removeRow(int index) {
    setState(() {
      _rows[index].label.dispose();
      _rows[index].value.dispose();
      _rows.removeAt(index);
    });
    _notify();
  }

  void _setAllAliadoVisibility(bool visible) {
    setState(() {
      for (final r in _rows) {
        r.visibleToAliado = visible;
      }
    });
    _notify();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Datos adicionales (ERP)',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
        const SizedBox(height: 4),
        const Text(
          'Información de tu sistema interno. Usa el botón del ojo para decidir '
          'qué campos puede ver el aliado en la ficha del repuesto.',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
            height: 1.35,
          ),
        ),
        if (_rows.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              OutlinedButton.icon(
                onPressed:
                    widget.enabled ? () => _setAllAliadoVisibility(false) : null,
                icon: const Icon(Icons.lock_outline, size: 16),
                label: const Text('Ocultar todos para aliados'),
              ),
              OutlinedButton.icon(
                onPressed:
                    widget.enabled ? () => _setAllAliadoVisibility(true) : null,
                icon: const Icon(Icons.visibility_outlined, size: 16),
                label: const Text('Mostrar todos a aliados'),
              ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        ...List.generate(_rows.length, (i) {
          final row = _rows[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  tooltip: row.visibleToAliado
                      ? 'Visible para aliados (tocar para ocultar)'
                      : 'Solo interno (tocar para mostrar a aliados)',
                  onPressed: widget.enabled
                      ? () {
                          setState(() {
                            row.visibleToAliado = !row.visibleToAliado;
                          });
                          _notify();
                        }
                      : null,
                  icon: Icon(
                    row.visibleToAliado
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: row.visibleToAliado
                        ? AppColors.successGreen
                        : AppColors.textSecondary,
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: TextFormField(
                    controller: row.label,
                    enabled: widget.enabled,
                    decoration: InputDecoration(
                      labelText: 'Nombre del campo',
                      hintText: 'Ej. Marca',
                      filled: true,
                      fillColor: AppColors.fieldFill,
                      border: OutlineInputBorder(
                        borderRadius: AppDecorations.radius12,
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (_) => _notify(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 5,
                  child: TextFormField(
                    controller: row.value,
                    enabled: widget.enabled,
                    decoration: InputDecoration(
                      labelText: 'Valor',
                      filled: true,
                      fillColor: AppColors.fieldFill,
                      border: OutlineInputBorder(
                        borderRadius: AppDecorations.radius12,
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (_) => _notify(),
                  ),
                ),
                IconButton(
                  tooltip: 'Quitar campo',
                  onPressed: widget.enabled ? () => _removeRow(i) : null,
                  icon: Icon(Icons.close, color: Colors.red.shade400, size: 20),
                ),
              ],
            ),
          );
        }),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: widget.enabled ? () => _addRow() : null,
            icon: const Icon(Icons.add),
            label: const Text('Agregar campo'),
          ),
        ),
      ],
    );
  }
}

class ImportCustomFieldMappingRow {
  ImportCustomFieldMappingRow({
    required this.fieldLabel,
    this.sourceColumn,
    this.visibleToAliado = false,
  });

  String fieldLabel;
  String? sourceColumn;

  /// Si el aliado puede ver este campo en la ficha del producto.
  bool visibleToAliado;
}
