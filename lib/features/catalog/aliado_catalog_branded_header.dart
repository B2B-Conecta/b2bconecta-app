import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/widgets/aliado_branded_header.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';

/// Encabezado azul del Catálogo: chrome compartido + búsqueda con filtros.
class AliadoCatalogBrandedHeader extends StatelessWidget {
  const AliadoCatalogBrandedHeader({
    super.key,
    required this.profile,
    required this.searchController,
    required this.onSearchSubmitted,
    required this.onOpenFilters,
    this.onMessagesTap,
    this.onNotificationTap,
    this.unreadMessages = 0,
    this.unreadNotifications = 0,
    this.filterBadge = 0,
  });

  final ProfileModel profile;
  final TextEditingController searchController;
  final VoidCallback onSearchSubmitted;
  final VoidCallback? onOpenFilters;
  final VoidCallback? onMessagesTap;
  final VoidCallback? onNotificationTap;
  final int unreadMessages;
  final int unreadNotifications;
  final int filterBadge;

  @override
  Widget build(BuildContext context) {
    return AliadoBrandedHeader(
      profile: profile,
      onMessagesTap: onMessagesTap,
      onNotificationTap: onNotificationTap,
      unreadMessages: unreadMessages,
      unreadNotifications: unreadNotifications,
      footer: _SearchField(
        controller: searchController,
        onSubmitted: onSearchSubmitted,
        onOpenFilters: onOpenFilters,
        filterBadge: filterBadge,
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onSubmitted,
    required this.onOpenFilters,
    required this.filterBadge,
  });

  final TextEditingController controller;
  final VoidCallback onSubmitted;
  final VoidCallback? onOpenFilters;
  final int filterBadge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final muted =
        dark ? theme.colorScheme.onSurfaceVariant : const Color(0xFF64748B);
    final outline = OutlineInputBorder(
      borderRadius: BorderRadius.circular(20),
      borderSide: BorderSide.none,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
      child: TextField(
        controller: controller,
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => onSubmitted(),
        textAlignVertical: TextAlignVertical.center,
        decoration: InputDecoration(
          hintText: 'Buscar repuestos, bujías, cauchos…',
          hintStyle: TextStyle(color: muted, fontSize: 14),
          prefixIcon: IconButton(
            tooltip: 'Buscar en el catálogo',
            onPressed: onSubmitted,
            icon: LucideIcon(LucideGlyph.search, size: 19, color: muted),
          ),
          suffixIcon: Padding(
            padding: const EdgeInsets.only(right: 4),
            child: IconButton(
              tooltip: 'Filtros del catálogo',
              onPressed: onOpenFilters,
              style: IconButton.styleFrom(
                minimumSize: const Size.square(44),
                padding: EdgeInsets.zero,
                foregroundColor: AliadoBrandedHeader.filterBlue,
              ),
              icon: Badge(
                isLabelVisible: filterBadge > 0,
                label: Text('$filterBadge'),
                backgroundColor: AppColors.brandAccent,
                child: const SizedBox.square(
                  dimension: 32,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AliadoBrandedHeader.filterBlue,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: LucideIcon(LucideGlyph.slidersHorizontal,
                          size: 17, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
          ),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 9),
          filled: true,
          fillColor: dark ? theme.colorScheme.surface : Colors.white,
          border: outline,
          enabledBorder: outline,
          focusedBorder: outline.copyWith(
            borderSide: BorderSide(color: theme.colorScheme.primary),
          ),
        ),
      ),
    );
  }
}
