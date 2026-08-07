import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Banner destacado cuando B2B Conecta valida el acceso de un aliado a la plataforma.
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
    final topInset = MediaQuery.paddingOf(context).top;
    final vertical = compact ? 10.0 : 14.0;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Material(
        color: Colors.green.shade50,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            14,
            vertical + topInset,
            14,
            vertical,
          ),
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
                icon: Icon(
                  Icons.close,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
              ),
          ],
        ),
      ),
    ),
    );
  }
}
