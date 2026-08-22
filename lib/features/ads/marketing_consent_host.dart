import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/config/public_legal_route.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/features/onboarding/open_public_legal.dart';

import 'marketing_consent.dart';
import 'marketing_consent_storage.dart';
import 'meta_pixel.dart';

/// Web: banner de cookies de marketing y carga del Pixel si hay consentimiento.
class MarketingConsentHost extends StatefulWidget {
  const MarketingConsentHost({super.key, required this.child});

  final Widget child;

  @override
  State<MarketingConsentHost> createState() => _MarketingConsentHostState();
}

class _MarketingConsentHostState extends State<MarketingConsentHost> {
  late MarketingConsent _consent;

  @override
  void initState() {
    super.initState();
    _consent = kIsWeb ? readMarketingConsent() : MarketingConsent.denied;
    if (_consent == MarketingConsent.accepted) {
      syncMetaPixel(marketingAllowed: true);
    }
  }

  void _choose(MarketingConsent next) {
    writeMarketingConsent(next);
    if (next == MarketingConsent.accepted) {
      syncMetaPixel(marketingAllowed: true);
    }
    if (mounted) setState(() => _consent = next);
  }

  @override
  Widget build(BuildContext context) {
    final showBanner = kIsWeb && _consent == MarketingConsent.unknown;
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (showBanner)
          Align(
            alignment: Alignment.bottomCenter,
            child: _MarketingCookieBanner(
              onAccept: () => _choose(MarketingConsent.accepted),
              onReject: () => _choose(MarketingConsent.denied),
            ),
          ),
      ],
    );
  }
}

class _MarketingCookieBanner extends StatelessWidget {
  const _MarketingCookieBanner({
    required this.onAccept,
    required this.onReject,
  });

  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: SafeArea(
        minimum: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderSubtle),
              boxShadow: AppDecorations.cardShadow,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Cookies de marketing',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Usamos cookies de marketing (Meta Pixel) para medir anuncios. '
                    'Las cookies técnicas de sesión no requieren este aviso.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () => openPublicLegal(
                        context,
                        PublicLegalKind.privacy,
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 0),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Privacidad',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.brand,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      TextButton(
                        onPressed: onReject,
                        child: const Text('Rechazar'),
                      ),
                      FilledButton(
                        onPressed: onAccept,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.brand,
                          foregroundColor: AppColors.white,
                        ),
                        child: const Text('Aceptar'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
