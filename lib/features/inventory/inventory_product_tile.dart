import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/features/catalog/part_model.dart';

/// Las acciones secundarias no le quitan ancho al nombre en móvil.
class InventoryProductTile extends StatelessWidget {
  const InventoryProductTile(
      {super.key,
      required this.part,
      required this.onEdit,
      required this.onShare,
      required this.onDelete,
      required this.onVisibilityChanged,
      this.soloDivisas = false,
      this.selecting = false,
      this.selected = false,
      this.onSelect});

  final PartModel part;
  final VoidCallback onEdit, onShare, onDelete;
  final ValueChanged<bool>? onVisibilityChanged;
  final bool soloDivisas, selecting, selected;
  final VoidCallback? onSelect;

  Widget _image() => ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
          width: 64,
          height: 64,
          child: part.coverImageUrl?.isNotEmpty == true
              ? Image.network(part.coverImageUrl!,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => _placeholder())
              : _placeholder()));

  Widget _placeholder() => ColoredBox(
      color: AppColors.fieldFill,
      child:
          Icon(Icons.image_outlined, color: AppColors.textSecondary, size: 24));

  @override
  Widget build(BuildContext context) {
    final color = part.stock <= 0
        ? Theme.of(context).colorScheme.error
        : !part.stockCoversMinOrder
            ? AppColors.brandAccent
            : AppColors.textSecondary;
    final name =
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(part.nombre,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.w700, height: 1.25)),
      const SizedBox(height: 4),
      Text(part.sku?.trim().isNotEmpty == true ? 'SKU ${part.sku}' : 'Sin SKU',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
    ]);
    final price =
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('${part.precio.toStringAsFixed(2)} ${soloDivisas ? 'USD' : 'REF'}',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
      if (!soloDivisas && part.tieneOfertaDirecta)
        Text('${part.salePriceUsd!.toStringAsFixed(2)} USD en divisas',
            style:
                const TextStyle(fontSize: 12, color: AppColors.successGreen)),
    ]);
    final stock =
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(part.stock <= 0 ? 'Sin stock' : '${part.stock} en stock',
          style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600, color: color)),
      Text(part.minOrderQtyLabelEs,
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
    ]);
    final visibility = Row(mainAxisSize: MainAxisSize.min, children: [
      Text(part.isActive ? 'Publicado' : 'Pausado',
          style: TextStyle(
              fontSize: 12,
              color: part.isActive
                  ? AppColors.successGreen
                  : AppColors.textSecondary)),
      const SizedBox(width: 4),
      Semantics(
          label: part.isActive
              ? 'Pausar ${part.nombre}'
              : 'Publicar ${part.nombre}',
          child: Switch(value: part.isActive, onChanged: onVisibilityChanged)),
    ]);
    final menu = selecting
        ? const SizedBox.shrink()
        : PopupMenuButton<String>(
            tooltip: 'Opciones de ${part.nombre}',
            icon: const Icon(Icons.more_horiz),
            constraints: const BoxConstraints(minWidth: 180),
            onSelected: (action) {
              switch (action) {
                case 'edit':
                  onEdit();
                case 'share':
                  onShare();
                case 'delete':
                  onDelete();
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                  value: 'edit', child: Text('Editar producto')),
              const PopupMenuItem(
                  value: 'share', child: Text('Compartir producto')),
              PopupMenuItem(
                  value: 'delete',
                  child: Text('Eliminar producto',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error))),
            ],
          );
    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= 720;
      return Material(
          color: AppColors.card,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                  color: selected ? AppColors.brand : AppColors.borderSubtle)),
          clipBehavior: Clip.antiAlias,
          child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (selecting)
                            Checkbox(
                                value: selected,
                                onChanged: (_) => onSelect?.call()),
                          Expanded(
                              flex: wide ? 4 : 1,
                              child: InkWell(
                                  onTap: selecting ? onSelect : onEdit,
                                  borderRadius: BorderRadius.circular(10),
                                  child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 4),
                                      child: Row(children: [
                                        _image(),
                                        const SizedBox(width: 12),
                                        Expanded(child: name)
                                      ])))),
                          if (wide) ...[
                            const SizedBox(width: 16),
                            Expanded(flex: 2, child: price),
                            const SizedBox(width: 12),
                            Expanded(flex: 2, child: stock),
                            if (!selecting) visibility,
                          ],
                          menu,
                        ]),
                    if (!wide) ...[
                      const SizedBox(height: 8),
                      Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: price),
                            const SizedBox(width: 8),
                            Expanded(child: stock),
                          ]),
                    ],
                    if (!wide || !part.hasPhotos)
                      Row(children: [
                        Expanded(
                            child: !part.hasPhotos && !selecting
                                ? Align(
                                    alignment: Alignment.centerLeft,
                                    child: TextButton.icon(
                                        onPressed: onEdit,
                                        icon: const Icon(
                                            Icons.add_photo_alternate_outlined,
                                            size: 17),
                                        label: const Text('Agregar foto'),
                                        style: TextButton.styleFrom(
                                            minimumSize: const Size(44, 44),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 4))))
                                : const SizedBox.shrink()),
                        if (!wide && !selecting) visibility,
                      ]),
                  ])));
    });
  }
}
