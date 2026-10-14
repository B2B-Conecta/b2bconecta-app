import 'package:flutter/material.dart';

import 'package:motolink_pro_app/core/widgets/motolink_pro_logo.dart';

/// Miniatura de la foto de catálogo de un producto del pedido.
class OrderProductThumb extends StatelessWidget {
  const OrderProductThumb({super.key, required this.size, this.url});

  final double size;
  final String? url;

  @override
  Widget build(BuildContext context) {
    final src = url?.trim();
    final radius = BorderRadius.circular(size * 0.16);
    if (src == null || src.isEmpty) {
      return BusinessLogoPlaceholder(size: size);
    }
    return ClipRRect(
      borderRadius: radius,
      child: Image.network(
        src,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => BusinessLogoPlaceholder(size: size),
      ),
    );
  }
}
