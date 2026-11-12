import 'package:flutter/material.dart';

import 'package:motolink_pro_app/features/admin/admin_catalog_seals_panel.dart';

/// Compatibilidad: redirige a [AdminCatalogSealsPanel] (Usuarios › Sellos y Vitrina).
@Deprecated('Usar AdminCatalogSealsPanel en el hub de Usuarios')
class AdminCatalogFeaturedSection extends StatelessWidget {
  const AdminCatalogFeaturedSection({
    super.key,
    this.onChanged,
  });

  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) => const AdminCatalogSealsPanel();
}
