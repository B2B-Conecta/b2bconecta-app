import 'package:flutter/material.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'part_model.dart';
import 'product_variants.dart';

class ProductVariantSelector extends StatelessWidget {
  const ProductVariantSelector({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final List<PartModel> options;
  final PartModel selected;
  final ValueChanged<PartModel> onSelected;

  @override
  Widget build(BuildContext context) {
    final axes = variantAttributeAxes(options);
    if (axes.length <= 1) {
      return _SingleAxisVariantSelector(
        options: options,
        selectedId: selected.id,
        onSelected: onSelected,
      );
    }

    final selection = selectionFromVariant(selected);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < axes.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          Text(
            axes[i],
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final value in availableAttributeValues(
                options: options,
                axis: axes[i],
                selection: selection,
              ))
                FilterChip(
                  label: Text(value),
                  selected: selection[axes[i]] == value,
                  showCheckmark: false,
                  onSelected: (_) {
                    final next = Map<String, String>.from(selection)
                      ..[axes[i]] = value;
                    onSelected(
                      pickVariantForAttributes(
                        options: options,
                        selection: next,
                        preferredAxis: axes[i],
                      ),
                    );
                  },
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _SingleAxisVariantSelector extends StatelessWidget {
  const _SingleAxisVariantSelector({
    required this.options,
    required this.selectedId,
    required this.onSelected,
  });

  final List<PartModel> options;
  final String selectedId;
  final ValueChanged<PartModel> onSelected;

  String get _heading {
    final axes = variantAttributeAxes(options);
    if (axes.length == 1) return axes.first;
    final names = options
        .map((option) => option.variantAttributeName?.trim() ?? '')
        .where((name) => name.isNotEmpty)
        .toSet();
    if (names.length == 1) return names.first;
    return 'Opciones';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _heading,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in options)
              FilterChip(
                label: Text(option.variantOptionLabel),
                selected: option.id == selectedId,
                showCheckmark: false,
                onSelected: (_) => onSelected(option),
              ),
          ],
        ),
      ],
    );
  }
}
