import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Banner destacado cuando MotoLink valida el acceso de un aliado a la plataforma.
class AliadoAccessApprovedBanner extends StatelessWidget {
  const AliadoAccessApprovedBanner({
    super.key,
    required this.message,
    this.onDismiss,
    this.compact = false,
  });

  final String message;
  final VoidCallback? onDismiss;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.green.shade50,
      child: Padding(
        padding: EdgeInsets.fromLTRB(14, compact ? 10 : 14, 14, compact ? 10 : 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.verified_outlined,
              color: Colors.green.shade800,
              size: compact ? 22 : 26,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Acceso validado',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: compact ? 13 : 14,
                      color: Colors.green.shade900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: TextStyle(
                      fontSize: compact ? 12 : 13,
                      height: 1.35,
                      color: Colors.green.shade900,
                    ),
                  ),
                ],
              ),
            ),
            if (onDismiss != null)
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: onDismiss,
                icon: const Icon(
                  Icons.close,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
