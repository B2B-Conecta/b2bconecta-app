import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/config/public_legal_route.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';

Future<void> openPublicLegal(
  BuildContext context,
  PublicLegalKind kind,
) async {
  final title = PublicLegalRoute.titleFor(kind);
  final body = PublicLegalRoute.bodyFor(kind);
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      final maxH = MediaQuery.sizeOf(ctx).height * 0.85;
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxH),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: Text(
                    body,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
