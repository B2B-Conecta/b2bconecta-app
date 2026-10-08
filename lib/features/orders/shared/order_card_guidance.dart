import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/app_theme.dart';

/// Pista corta y acceso etiquetado al detalle de un pedido.
class OrderCardGuidance extends StatelessWidget {
  const OrderCardGuidance({
    super.key,
    required this.hint,
    required this.expanded,
    required this.onToggle,
  });

  final String hint;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!expanded && hint.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
            child: Text(
              hint,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.35,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        Material(
          color: AppColors.brandBlueContainer,
          child: InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                    color: AppColors.brand,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      expanded
                          ? 'Ocultar detalle'
                          : 'Ver detalle y seguimiento',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                        color: AppColors.brand,
                      ),
                    ),
                  ),
                  Icon(
                    expanded ? Icons.unfold_less : Icons.chevron_right,
                    size: 18,
                    color: AppColors.brand,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
