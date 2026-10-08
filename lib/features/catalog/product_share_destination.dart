import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/features/catalog/catalog_service.dart';
import 'package:motolink_pro_app/features/catalog/product_detail_screen.dart';

/// Abre la ficha si el catálogo la deja ver. Si no, un aviso sin datos del producto.
class ProductShareDestinationScreen extends StatefulWidget {
  const ProductShareDestinationScreen({super.key, required this.productId});

  final String productId;

  @override
  State<ProductShareDestinationScreen> createState() =>
      _ProductShareDestinationScreenState();
}

class _ProductShareDestinationScreenState
    extends State<ProductShareDestinationScreen> {
  late final Future<bool?> _open;

  @override
  void initState() {
    super.initState();
    _open = _load();
  }

  /// `true` si abrió la ficha, `false` si no está disponible, `null` si falló la red.
  Future<bool?> _load() async {
    try {
      final part =
          await CatalogService.fetchCatalogProductById(widget.productId);
      if (!mounted) return false;
      if (part == null) return false;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => ProductDetailScreen(part: part),
        ),
      );
      return true;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool?>(
      future: _open,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done ||
            snapshot.data == true) {
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(title: const Text('Producto')),
            body: Center(
              child: CircularProgressIndicator(color: AppColors.brand),
            ),
          );
        }
        if (snapshot.data == null) {
          return _unavailable(
            'No se pudo abrir el producto. Revisa la conexión e inténtalo de nuevo.',
          );
        }
        return _unavailable(
          'Este producto no está disponible. Puede que ya no se publique o que no tengas acceso al catálogo.',
        );
      },
    );
  }

  Widget _unavailable(String message) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Producto')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.inventory_2_outlined,
                size: 48,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: 16),
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
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('Volver'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
