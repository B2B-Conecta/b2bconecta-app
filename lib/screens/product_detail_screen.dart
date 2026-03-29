import 'package:flutter/material.dart';

import '../models/part_model.dart';
import '../theme/app_theme.dart';

/// Ficha de producto alineada a la referencia (imagen, specs en grid, CTA fijo).
class ProductDetailScreen extends StatelessWidget {
  const ProductDetailScreen({super.key, required this.part});

  final PartModel part;

  static String heroImageTag(PartModel p) => 'product-image-${p.id}';

  static List<String> _specLines(PartModel p) {
    final lines = <String>[];
    if (p.compatibilidad != null && p.compatibilidad!.trim().isNotEmpty) {
      lines.add('Compatibilidad: ${p.compatibilidad!.trim()}');
    }
    lines.add('Stock: ${p.stock} unidades');
    final desc = p.descripcion?.trim();
    if (desc != null && desc.isNotEmpty) {
      final first = desc.split(RegExp(r'[\n.]')).first.trim();
      if (first.isNotEmpty) {
        lines.add(first.length > 48 ? '${first.substring(0, 45)}…' : first);
      }
    }
    lines.add('Ref: ${p.id}');
    final out = lines.take(4).toList();
    while (out.length < 4) {
      out.add('—');
    }
    return out;
  }

  String get _skuDisplay {
    final id = part.id;
    if (id.length <= 14) return id;
    return id.substring(0, 12);
  }

  @override
  Widget build(BuildContext context) {
    final importer = (part.ownerBusinessName ?? '').trim().toUpperCase();
    final specs = _specLines(part);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      AspectRatio(
                        aspectRatio: 1,
                        child: Material(
                          color: Colors.white,
                          child: Hero(
                            tag: heroImageTag(part),
                            child: part.imagenUrl != null &&
                                    part.imagenUrl!.isNotEmpty
                                ? Image.network(
                                    part.imagenUrl!,
                                    fit: BoxFit.contain,
                                    width: double.infinity,
                                    errorBuilder: (_, __, ___) =>
                                        _imagePlaceholder(),
                                  )
                                : _imagePlaceholder(),
                          ),
                        ),
                      ),
                      Positioned(
                        top: MediaQuery.paddingOf(context).top + 4,
                        right: 8,
                        child: Material(
                          color: Colors.white.withOpacity(0.92),
                          shape: const CircleBorder(),
                          child: IconButton(
                            icon: const Icon(Icons.close),
                            color: AppColors.textPrimary,
                            onPressed: () => Navigator.of(context).maybePop(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'SKU: $_skuDisplay',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (importer.isNotEmpty)
                        Text(
                          importer,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      if (importer.isNotEmpty) const SizedBox(height: 6),
                      Text(
                        part.nombre,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '\$${part.precio.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: AppColors.brand,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: AppColors.successGreen,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${part.stock} unidades disponibles',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ],
                      ),
                      if (part.descripcion != null &&
                          part.descripcion!.trim().isNotEmpty) ...[
                        const SizedBox(height: 24),
                        const Text(
                          'Descripción Técnica',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          part.descripcion!.trim(),
                          style: const TextStyle(
                            fontSize: 15,
                            height: 1.45,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      const Text(
                        'Especificaciones',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 4,
                        children: specs
                            .map(
                              (s) => Container(
                                alignment: Alignment.center,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.fieldFill,
                                  borderRadius: AppDecorations.radius12,
                                ),
                                child: Text(
                                  s,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 28),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _ServicePill(
                            icon: Icons.inventory_2_outlined,
                            label: 'Envío B2B',
                          ),
                          _ServicePill(
                            icon: Icons.local_shipping_outlined,
                            label: 'Despacho 24h',
                          ),
                          _ServicePill(
                            icon: Icons.verified_user_outlined,
                            label: 'Garantía',
                          ),
                        ],
                      ),
                      SizedBox(
                        height: MediaQuery.paddingOf(context).bottom + 100,
                      ),
                    ]),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              MediaQuery.paddingOf(context).bottom + 12,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Negociación próximamente disponible.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: const Text('Iniciar Negociación'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _imagePlaceholder() {
    return ColoredBox(
      color: Colors.grey.shade100,
      child: Center(
        child: Icon(
          Icons.precision_manufacturing_outlined,
          size: 72,
          color: Colors.grey.shade500,
        ),
      ),
    );
  }
}

class _ServicePill extends StatelessWidget {
  const _ServicePill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 26, color: AppColors.textSecondary),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
