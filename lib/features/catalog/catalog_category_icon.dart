import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/widgets/lucide_icon.dart';
import 'catalog_taxonomy.dart';

enum CatalogCategoryArt {
  tires('caucho.svg', Color(0xFFE3EDFF), Color(0xFF1B51DB)),
  brakes('freno-de-disco.png', Color(0xFFDCF6E9), Color(0xFF08794A)),
  transmission('transmision.svg', Color(0xFFEFE6FF), Color(0xFF7040BA)),
  electrical('bateria.svg', Color(0xFFFFF1D0), Color(0xFF966000)),
  engine('motor.svg', Color(0xFFDFF3FF), Color(0xFF00689D)),
  maintenance('lubricantes.svg', Color(0xFFFFEBDB), Color(0xFFB7370D)),
  oil('aceite.svg', Color(0xFFFFEBDB), Color(0xFFB7370D)),
  suspension('amortiguador.svg', Color(0xFFE3F4F2), Color(0xFF136D65)),
  fuel('admision-combustible.svg', Color(0xFFF3EAFF), Color(0xFF7345A4)),
  exhaust('escape.svg', Color(0xFFEDF0F6), Color(0xFF48556E)),
  accessories('casco.svg', Color(0xFFE8EEFF), Color(0xFF4253AB));

  const CatalogCategoryArt(this.file, this.surface, this.ink);

  final String file;
  final Color surface;
  final Color ink;

  Color iconColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? Color.lerp(ink, Colors.white, .44)!
          : ink;

  static CatalogCategoryArt? forLabel(String label) {
    final path = canonicalCatalogCategory(label);
    if (path == 'Lubricantes y mantenimiento / Aceites') return oil;
    return switch (path == null ? null : categoryFamily(path)) {
      'Cauchos y ruedas' => tires,
      'Frenos' => brakes,
      'Transmisión' => transmission,
      'Eléctrico e iluminación' => electrical,
      'Motor' => engine,
      'Lubricantes y mantenimiento' => maintenance,
      'Suspensión' => suspension,
      'Admisión y combustible' => fuel,
      'Escape' => exhaust,
      'Accesorios' => accessories,
      _ => null,
    };
  }
}

class CatalogCategoryIcon extends StatelessWidget {
  const CatalogCategoryIcon({
    super.key,
    required this.art,
    required this.size,
    this.color,
  });

  final CatalogCategoryArt? art;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final categoryArt = art;
    if (categoryArt == null) {
      return LucideIcon(LucideGlyph.wrench, size: size, color: color);
    }
    final asset = 'assets/catalog_categories/${categoryArt.file}';
    final ink = color ?? categoryArt.iconColor(context);
    if (categoryArt == CatalogCategoryArt.brakes) {
      return Image.asset(asset, width: size, height: size, color: ink);
    }
    return SvgPicture.asset(
      asset,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(ink, BlendMode.srcIn),
    );
  }
}
