import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/widgets/motolink_app_bar.dart';
import 'package:motolink_pro_app/features/catalog/aliado_favorites_service.dart';
import 'package:motolink_pro_app/features/catalog/catalog_product_price_display.dart';
import 'package:motolink_pro_app/features/catalog/catalog_route_lock.dart';
import 'package:motolink_pro_app/features/catalog/favorite_heart_button.dart';
import 'package:motolink_pro_app/features/catalog/part_model.dart';
import 'package:motolink_pro_app/features/catalog/product_detail_screen.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';

class AliadoFavoritesScreen extends StatefulWidget {
  const AliadoFavoritesScreen({
    super.key,
    required this.profile,
    required this.onNotificationTap,
    required this.unreadNotifications,
    this.onMessagesTap,
    this.unreadMessages = 0,
    this.embedInDesktopShell = false,
  });

  final ProfileModel profile;
  final VoidCallback onNotificationTap;
  final int unreadNotifications;
  final VoidCallback? onMessagesTap;
  final int unreadMessages;
  final bool embedInDesktopShell;

  @override
  State<AliadoFavoritesScreen> createState() => _AliadoFavoritesScreenState();
}

class _AliadoFavoritesScreenState extends State<AliadoFavoritesScreen> {
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      await AliadoFavoritesService.instance.refresh();
      if (mounted) setState(() => _error = null);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: widget.embedInDesktopShell
          ? null
          : MotolinkAppBar(
              currentUserProfile: widget.profile,
              logoHeight: MotolinkAppBarLogoSizes.aliado,
              onNotificationTap: widget.onNotificationTap,
              unreadNotifications: widget.unreadNotifications,
              onMessagesTap: widget.onMessagesTap,
              unreadMessages: widget.unreadMessages,
            ),
      body: ListenableBuilder(
        listenable: AliadoFavoritesService.instance,
        builder: (context, _) {
          final service = AliadoFavoritesService.instance;
          if (!service.loaded && _error == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!service.loaded && _error != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'No se pudieron cargar los favoritos.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _load,
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            );
          }
          final parts = service.parts;
          if (parts.isEmpty) {
            return const _FavoritesEmpty();
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: parts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              return _FavoriteRow(part: parts[index]);
            },
          );
        },
      ),
    );
  }
}

class _FavoritesEmpty extends StatelessWidget {
  const _FavoritesEmpty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.favorite_border, size: 48, color: AppColors.brand),
            const SizedBox(height: 12),
            Text(
              'Aún no tienes favoritos',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Marca el corazón en un repuesto del catálogo para volver a comprarlo desde aquí.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FavoriteRow extends StatelessWidget {
  const _FavoriteRow({required this.part});

  final PartModel part;

  bool get _purchasable => part.isActive && part.stockCoversMinOrder;

  String get _availability {
    if (!part.isActive) return 'Pausado por el proveedor';
    if (part.stock < 1) return 'Sin stock';
    if (!part.stockCoversMinOrder) {
      return 'Stock insuficiente para el mínimo';
    }
    return '${part.stock} en stock · ${part.minOrderQtyLabelEs}';
  }

  @override
  Widget build(BuildContext context) {
    final importer = (part.ownerBusinessName ?? '').trim();
    return Opacity(
      opacity: _purchasable ? 1 : 0.72,
      child: Material(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            CatalogRouteLock.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => ProductDetailScreen(part: part),
              ),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 72,
                    height: 72,
                    child: part.coverImageUrl != null &&
                            part.coverImageUrl!.isNotEmpty
                        ? Image.network(
                            part.coverImageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const _FavoriteThumb(),
                          )
                        : const _FavoriteThumb(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        part.nombre,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (importer.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          importer,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      CatalogProductPriceDisplay(
                        listPriceUsd: part.precio,
                        salePriceUsd: part.salePriceUsd,
                        discountRules: part.discountRules,
                        catalogGrid: true,
                        compact: true,
                        showPromotionChips: false,
                        ownerPagoSoloDivisas: part.ownerPagoSoloDivisas,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _availability,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: _purchasable
                              ? AppColors.successGreen
                              : AppColors.brand,
                        ),
                      ),
                    ],
                  ),
                ),
                FavoriteHeartButton(productId: part.id, compact: true),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FavoriteThumb extends StatelessWidget {
  const _FavoriteThumb();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.borderSubtle,
      child: Icon(
        Icons.precision_manufacturing_outlined,
        color: AppColors.textMuted,
      ),
    );
  }
}
