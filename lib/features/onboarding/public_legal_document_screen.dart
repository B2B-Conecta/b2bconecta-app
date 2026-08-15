import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/config/auth_redirect_config.dart';
import 'package:motolink_pro_app/app/config/public_legal_route.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'public_legal_home_nav.dart';
import 'package:motolink_pro_app/core/widgets/motolink_pro_logo.dart';

/// Documento legal público (privacidad / términos) sin autenticación.
class PublicLegalDocumentScreen extends StatelessWidget {
  const PublicLegalDocumentScreen({
    super.key,
    required this.kind,
  });

  final PublicLegalKind kind;

  /// URL canónica de producción para Play Console / enlaces externos.
  static String productionUrlFor(PublicLegalKind kind) {
    return '${AuthRedirectConfig.productionWebRedirectUrl}/?${PublicLegalRoute.queryFor(kind)}';
  }

  static String publicUrlFor(PublicLegalKind kind) {
    if (kIsWeb) {
      final origin = Uri.base.origin.trim();
      if (origin.isNotEmpty && origin != 'null') {
        return '$origin/?${PublicLegalRoute.queryFor(kind)}';
      }
    }
    return productionUrlFor(kind);
  }

  @override
  Widget build(BuildContext context) {
    final title = PublicLegalRoute.titleFor(kind);
    final body = PublicLegalRoute.bodyFor(kind);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          kind == PublicLegalKind.privacy ? 'Privacidad' : 'Términos',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: navigateToAppHome,
            child: Text(
              'Ir al inicio',
              style: TextStyle(
                color: AppColors.brand,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: MotoLinkProLogo(height: 56),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              SelectableText(
                body,
                style: TextStyle(
                  fontSize: 14.5,
                  height: 1.55,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
