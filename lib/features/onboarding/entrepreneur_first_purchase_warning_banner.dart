import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';
import 'package:motolink_pro_app/features/onboarding/entrepreneur_status_modal.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';

/// Banner crítico: quedan 3 días hábiles para la primera compra.
class EntrepreneurFirstPurchaseWarningBanner extends StatelessWidget {
  const EntrepreneurFirstPurchaseWarningBanner({
    super.key,
    required this.profile,
  });

  final ProfileModel profile;

  static Widget? maybe(ProfileModel profile) {
    if (!profile.isEntrepreneurFirstPurchaseWarning) return null;
    return EntrepreneurFirstPurchaseWarningBanner(profile: profile);
  }

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final alert = Theme.of(context).colorScheme.error;

    return Material(
      color: theme.warningBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: alert.withOpacity(0.35)),
      ),
      child: InkWell(
        onTap: () =>
            showEntrepreneurStatusModal(context: context, profile: profile),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: theme.surfaceCard,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: alert.withOpacity(0.28)),
                ),
                child: LucideIcon(
                  LucideGlyph.triangleAlert,
                  size: 20,
                  color: alert,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cuenta regresiva · 3 días hábiles',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: theme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Te quedan 3 días hábiles para realizar tu primera compra. '
                      'De lo contrario, tu cuenta será bloqueada temporalmente.',
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.4,
                        color: theme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
