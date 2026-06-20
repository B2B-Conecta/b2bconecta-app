import 'package:flutter/material.dart';

import '../../models/profile_model.dart';
import '../../models/profile_role_labels.dart';
import '../../theme/app_theme.dart';

/// Barra superior compartida en shells de escritorio (admin / B2B).
class DesktopShellTopBar extends StatelessWidget {
  const DesktopShellTopBar({
    super.key,
    required this.profile,
    required this.unreadNotifications,
    required this.onNotificationTap,
    required this.onOpenSettings,
    this.contextLabel = 'MotoLink',
    this.trailingActions = const [],
  });

  final ProfileModel profile;
  final int unreadNotifications;
  final VoidCallback onNotificationTap;
  final VoidCallback onOpenSettings;
  final String contextLabel;
  final List<Widget> trailingActions;

  @override
  Widget build(BuildContext context) {
    final business = profile.businessName?.trim();
    final role = ProfileRoleLabels.labelEs(profile.role);

    return Material(
      color: Colors.white,
      elevation: 0,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.brandBlueContainer.withOpacity(0.65),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  contextLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.brandBlue,
                    letterSpacing: 0.15,
                  ),
                ),
              ),
              const Spacer(),
              ...trailingActions,
              if (business != null && business.isNotEmpty) ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      business,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      role,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
              ],
              IconButton(
                tooltip: 'Ajustes de cuenta',
                onPressed: onOpenSettings,
                icon: Icon(Icons.settings_outlined, color: Colors.grey.shade700),
              ),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    tooltip: 'Notificaciones',
                    onPressed: onNotificationTap,
                    icon: Icon(Icons.notifications_outlined, color: Colors.grey.shade700),
                  ),
                  if (unreadNotifications > 0)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.brandOrange,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                        child: Text(
                          unreadNotifications > 99 ? '99+' : '$unreadNotifications',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
