import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/features/inventory/product_custom_fields.dart';
import 'package:motolink_pro_app/features/inventory/product_custom_fields_section.dart';
import 'aliado_catalog_categories.dart';
import 'part_model.dart';
import 'product_warranty_seal.dart';

/// Product identity leads the detail page; a database ID is never a SKU.
class ProductDetailHeading extends StatelessWidget {
  const ProductDetailHeading(
      {super.key, required this.part, this.desktop = false});

  final PartModel part;
  final bool desktop;

  @override
  Widget build(BuildContext context) {
    final category = part.category?.trim() ?? '';
    final sku = part.sku?.trim() ?? '';
    final showMeta =
        category.isNotEmpty || sku.isNotEmpty || part.hasWarranty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          container: true,
          child: Text(part.nombre,
              style: TextStyle(
                  fontSize: desktop ? 30 : 22,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
        ),
        if (showMeta) ...[
          const SizedBox(height: 8),
          Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (category.isNotEmpty)
                  DecoratedBox(
                    decoration: BoxDecoration(
                        color: AppColors.brandBlueContainer,
                        borderRadius: BorderRadius.circular(6)),
                    child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        child: Text(formatCatalogCategoryLabel(category),
                            style: TextStyle(
                                fontSize: 11.5,
                                height: 1.3,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary))),
                  ),
                if (sku.isNotEmpty)
                  SelectableText('Código: $sku',
                      style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: AppColors.textSecondary)),
                if (part.hasWarranty) const ProductWarrantySeal(compact: true),
              ]),
        ],
      ],
    );
  }
}

/// Only supplier-provided content and published specifications are presented.
class ProductDetailInformation extends StatelessWidget {
  const ProductDetailInformation({
    super.key,
    required this.part,
    this.showInternalReference = false,
  });

  final PartModel part;
  final bool showInternalReference;

  @override
  Widget build(BuildContext context) {
    final description = part.descripcion?.trim() ?? '';
    final compatibility = part.compatibilidad?.trim() ?? '';
    final hasSpecs =
        productCustomFieldsDisplayEntries(part.customFields, aliadoView: true)
            .isNotEmpty;
    final sections = <Widget>[
      if (description.isNotEmpty)
        _InformationSection(
            title: 'Descripción', child: _ProductText(description)),
      if (compatibility.isNotEmpty)
        _InformationSection(
            title: 'Compatibilidad', child: _ProductText(compatibility)),
      if (hasSpecs)
        _InformationSection(
            title: 'Especificaciones',
            child: ProductCustomFieldsAliadoSpecs(
                customFields: part.customFields)),
    ];

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (sections.isEmpty)
        Text('El proveedor aún no ha añadido información técnica.',
            style: TextStyle(
                fontSize: 14, height: 1.5, color: AppColors.textSecondary)),
      for (var i = 0; i < sections.length; i++) ...[
        if (i > 0) const SizedBox(height: 16),
        sections[i],
      ],
      if (showInternalReference) ...[
        const SizedBox(height: 20),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(bottom: 12),
          title: const Text('Información para soporte',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: SelectableText(part.id,
                  style:
                      TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            ),
          ],
        ),
      ],
    ]);
  }
}

class _InformationSection extends StatelessWidget {
  const _InformationSection({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            container: true,
            child: Text(title,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
          ),
          const SizedBox(height: 8),
          child,
        ],
      );
}

class _ProductText extends StatelessWidget {
  const _ProductText(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: SelectableText(text,
              style: TextStyle(
                  fontSize: 14, height: 1.5, color: AppColors.textPrimary)),
        ),
      );
}
