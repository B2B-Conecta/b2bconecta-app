import 'package:flutter/material.dart';

import '../models/part_model.dart';

/// Ficha completa de un repuesto del catálogo.
class ProductDetailScreen extends StatelessWidget {
  const ProductDetailScreen({super.key, required this.part});

  final PartModel part;

  static String heroImageTag(PartModel p) => 'product-image-${p.id}';

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.secondary;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          part.nombre,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 1.15,
              child: Material(
                color: Colors.white,
                child: Hero(
                  tag: heroImageTag(part),
                  child: part.imagenUrl != null && part.imagenUrl!.isNotEmpty
                      ? Image.network(
                          part.imagenUrl!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          errorBuilder: (_, __, ___) => _imagePlaceholder(),
                        )
                      : _imagePlaceholder(),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    part.nombre,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      height: 1.25,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '\$${part.precio.toStringAsFixed(2)} USD',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: accent,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Stock disponible: ${part.stock}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _ImporterBlock(part: part),
                  if (part.descripcion != null &&
                      part.descripcion!.trim().isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const _SectionTitle(title: 'Descripción'),
                    const SizedBox(height: 8),
                    Text(
                      part.descripcion!,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.45,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ],
                  if (part.compatibilidad != null &&
                      part.compatibilidad!.trim().isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const _SectionTitle(title: 'Compatibilidad'),
                    const SizedBox(height: 8),
                    Text(
                      part.compatibilidad!,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.45,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Text(
                    'Referencia: ${part.id}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imagePlaceholder() {
    return ColoredBox(
      color: Colors.grey.shade200,
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.4,
        color: Colors.black54,
      ),
    );
  }
}

class _ImporterBlock extends StatelessWidget {
  const _ImporterBlock({required this.part});

  final PartModel part;

  @override
  Widget build(BuildContext context) {
    final name = part.ownerBusinessName?.trim();
    final hasName = name != null && name.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.storefront_outlined,
              color: Colors.grey.shade700, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Importador',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hasName ? name : 'Sin importador asignado',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: hasName ? Colors.black87 : Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
