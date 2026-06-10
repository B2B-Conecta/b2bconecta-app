import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Etiqueta de fecha del pedido o «Pedido activo» en fichas del importador.
class ImporterOrderDateBadge extends StatelessWidget {
  const ImporterOrderDateBadge({
    super.key,
    required this.label,
    required this.isActive,
  });

  final String label;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final bg = isActive ? AppColors.brandBlue.withOpacity(0.1) : Colors.grey.shade100;
    final fg = isActive ? AppColors.brandBlue : Colors.grey.shade800;
    final border = isActive
        ? AppColors.brandBlue.withOpacity(0.35)
        : Colors.grey.shade300;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isActive ? Icons.schedule_rounded : Icons.event_available_outlined,
            size: 13,
            color: fg,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
