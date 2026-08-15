import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/app_theme.dart';

/// Visibilidad de productos **nuevos** al importar (no afecta códigos ya registrados).
enum ImporterNewProductsVisibility {
  paused,
  active,
}

extension ImporterNewProductsVisibilityX on ImporterNewProductsVisibility {
  bool get isActive => this == ImporterNewProductsVisibility.active;

  String get title => switch (this) {
        ImporterNewProductsVisibility.paused => 'En pausa (recomendado)',
        ImporterNewProductsVisibility.active => 'Visibles en catálogo',
      };

  String get subtitle => switch (this) {
        ImporterNewProductsVisibility.paused =>
          'Los códigos nuevos quedan ocultos para aliados. Revísalos y actívalos '
          'cuando quieras publicarlos.',
        ImporterNewProductsVisibility.active =>
          'Los códigos nuevos se publican de inmediato para aliados. '
          'Úsalo si ya validaste el archivo.',
      };

  IconData get icon => switch (this) {
        ImporterNewProductsVisibility.paused => Icons.visibility_off_outlined,
        ImporterNewProductsVisibility.active => Icons.visibility_outlined,
      };
}

/// Selector de visibilidad para productos nuevos en flujos de importación.
class ImporterNewProductsVisibilitySection extends StatelessWidget {
  const ImporterNewProductsVisibilitySection({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.compact = false,
  });

  final ImporterNewProductsVisibility value;
  final ValueChanged<ImporterNewProductsVisibility>? onChanged;
  final bool enabled;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return DropdownButtonFormField<ImporterNewProductsVisibility>(
        value: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: 'Productos nuevos',
          filled: true,
          fillColor: AppColors.fieldFill,
          border: OutlineInputBorder(
            borderRadius: AppDecorations.radius12,
            borderSide: BorderSide.none,
          ),
        ),
        items: ImporterNewProductsVisibility.values
            .map(
              (v) => DropdownMenuItem(
                value: v,
                child: Text(v.title),
              ),
            )
            .toList(),
        onChanged: enabled
            ? (v) {
                if (v != null) onChanged?.call(v);
              }
            : null,
      );
    }

    return Column(
      children: ImporterNewProductsVisibility.values.map((option) {
        final selected = value == option;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Material(
            color: selected
                ? AppColors.brand.withOpacity(0.08)
                : AppColors.fieldFill,
            borderRadius: AppDecorations.radius12,
            child: InkWell(
              borderRadius: AppDecorations.radius12,
              onTap: enabled && onChanged != null
                  ? () => onChanged!(option)
                  : null,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                decoration: BoxDecoration(
                  borderRadius: AppDecorations.radius12,
                  border: Border.all(
                    color: selected
                        ? AppColors.brand.withOpacity(0.45)
                        : Colors.transparent,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.75),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        option.icon,
                        size: 20,
                        color: selected
                            ? AppColors.brand
                            : AppColors.brandBlue,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            option.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            option.subtitle,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: AppColors.textSecondary,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Radio<ImporterNewProductsVisibility>(
                      value: option,
                      groupValue: value,
                      activeColor: AppColors.brand,
                      onChanged: enabled && onChanged != null
                          ? (v) {
                              if (v != null) onChanged!(v);
                            }
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Diálogo previo a la importación (reservado para flujos legacy).
Future<ImporterNewProductsVisibility?> showImporterImportVisibilityDialog(
  BuildContext context, {
  required int rowCount,
}) {
  var selection = ImporterNewProductsVisibility.paused;

  return showDialog<ImporterNewProductsVisibility>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setLocal) => AlertDialog(
        title: const Text('Opciones de importación'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Se procesarán $rowCount fila(s) del archivo. '
                'Los códigos que ya existen solo actualizan precio y stock '
                '(según tu elección en conflicto de SKU).',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Productos nuevos',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                'Solo aplica a códigos que aún no están en tu inventario.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              ImporterNewProductsVisibilitySection(
                value: selection,
                onChanged: (v) => setLocal(() => selection = v),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, selection),
            child: const Text('Continuar'),
          ),
        ],
      ),
    ),
  );
}
