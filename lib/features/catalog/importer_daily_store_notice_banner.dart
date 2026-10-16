import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'importer_daily_store_notice.dart';

class ImporterDailyStoreNoticeBanner extends StatelessWidget {
  const ImporterDailyStoreNoticeBanner({
    super.key,
    required this.notice,
    required this.onDismiss,
  });

  final ImporterDailyStoreNotice notice;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final message = notice.message;
    if (message == null) return const SizedBox.shrink();
    return Material(
      color: AppColors.brandBlueContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
        child: Row(
          children: [
            const Icon(Icons.storefront_outlined, color: AppColors.brand),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            TextButton(onPressed: onDismiss, child: const Text('Entendido')),
          ],
        ),
      ),
    );
  }
}
