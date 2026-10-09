import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'catalog_service.dart';
import 'part_model.dart';
import 'product_detail_screen.dart';

/// Producto abierto desde un enlace, sin cuenta.
class GuestSharedProductScreen extends StatefulWidget {
  const GuestSharedProductScreen({
    super.key,
    required this.productId,
    required this.onRegister,
  });

  final String productId;
  final VoidCallback onRegister;

  @override
  State<GuestSharedProductScreen> createState() =>
      _GuestSharedProductScreenState();
}

class _GuestSharedProductScreenState extends State<GuestSharedProductScreen> {
  late final Future<PartModel?> _product = CatalogService.fetchPublicSharedProduct(
    widget.productId,
  );

  void _openStore(PartModel part) {
    final owner = part.ownerId?.trim();
    if (owner == null || owner.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GuestSupplierStoreScreen(
          importerId: owner,
          onRegister: widget.onRegister,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PartModel?>(
      future: _product,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _GuestWait(title: 'Producto');
        }
        final part = snapshot.data;
        if (snapshot.hasError || part == null) {
          return _GuestUnavailable(
            message: snapshot.hasError
                ? 'No se pudo abrir el producto. Revisa la conexión e inténtalo de nuevo.'
                : 'Este producto no está disponible.',
            onRegister: widget.onRegister,
          );
        }
        return ProductDetailScreen(
          part: part,
          guestPreview: true,
          onRegisterToOrder: widget.onRegister,
          onOpenStore: () => _openStore(part),
        );
      },
    );
  }
}

class GuestSupplierStoreScreen extends StatefulWidget {
  const GuestSupplierStoreScreen({
    super.key,
    required this.importerId,
    required this.onRegister,
  });

  final String importerId;
  final VoidCallback onRegister;

  @override
  State<GuestSupplierStoreScreen> createState() =>
      _GuestSupplierStoreScreenState();
}

class _GuestSupplierStoreScreenState extends State<GuestSupplierStoreScreen> {
  late final Future<
      ({
        String name,
        String? estado,
        String? ciudad,
        List<PartModel> products,
      })?> _store = CatalogService.fetchPublicSharedStore(widget.importerId);

  void _openProduct(PartModel part) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProductDetailScreen(
          part: part,
          guestPreview: true,
          onRegisterToOrder: widget.onRegister,
          onOpenStore: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(future: _store, builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const _GuestWait(title: 'Vitrina');
      }
      final store = snapshot.data;
      if (snapshot.hasError || store == null) {
        return _GuestUnavailable(
          message: 'No se pudo abrir la vitrina del proveedor.',
          onRegister: widget.onRegister,
        );
      }
      final place = [
        store.estado?.trim(),
        store.ciudad?.trim(),
      ].where((s) => s != null && s.isNotEmpty).join(' · ');
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: Text(store.name)),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            if (place.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  place,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            if (store.products.isEmpty)
              const Text('Este proveedor no tiene productos publicados.')
            else
              for (final part in store.products)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(12),
                    child: ListTile(
                      title: Text(part.nombre),
                      subtitle: Text(
                        '${part.precio.toStringAsFixed(2)} USD',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _openProduct(part),
                    ),
                  ),
                ),
          ],
        ),
      );
    });
  }
}

class _GuestWait extends StatelessWidget {
  const _GuestWait({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(title)),
      body: Center(child: CircularProgressIndicator(color: AppColors.brand)),
    );
  }
}

class _GuestUnavailable extends StatelessWidget {
  const _GuestUnavailable({
    required this.message,
    required this.onRegister,
  });

  final String message;
  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Producto')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: onRegister,
                child: const Text('Regístrate para pedir'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
