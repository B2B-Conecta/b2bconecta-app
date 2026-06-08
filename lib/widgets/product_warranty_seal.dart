import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Sello / icono de garantía para catálogo aliado y detalle de producto.
class ProductWarrantySeal extends StatelessWidget {
  const ProductWarrantySeal({
    super.key,
    this.compact = false,
  });

  /// `true` = badge sobre imagen del catálogo; `false` = icono en detalle.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.brandBlue.withOpacity(0.92),
          borderRadius: BorderRadius.circular(6),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.verified_user,
              size: 12,
              color: Colors.white,
            ),
            SizedBox(width: 3),
            Text(
              'Garantía',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.verified_user_outlined,
          size: 26,
          color: AppColors.brandBlue,
        ),
        const SizedBox(height: 6),
        Text(
          'Garantía',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.brandBlue,
          ),
        ),
      ],
    );
  }
}
