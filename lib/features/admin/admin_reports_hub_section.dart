/// Secciones del hub de Reportes (admin).
enum AdminReportsHubSection {
  encomiendas,
  promos,
  referidos,
  devoluciones,
}

extension AdminReportsHubSectionLabel on AdminReportsHubSection {
  String get labelEs => switch (this) {
        AdminReportsHubSection.encomiendas => 'Encomiendas',
        AdminReportsHubSection.promos => 'Promos',
        AdminReportsHubSection.referidos => 'Referidos',
        AdminReportsHubSection.devoluciones => 'Devoluciones',
      };

  String get hintEs => switch (this) {
        AdminReportsHubSection.encomiendas =>
          'Métricas, exportación Excel y detalle de pedidos en el periodo.',
        AdminReportsHubSection.promos =>
          'Campañas y banners promocionales del marketplace.',
        AdminReportsHubSection.referidos =>
          'Red de referidos y comisiones de captación.',
        AdminReportsHubSection.devoluciones =>
          'Postventa, frecuencia y saldo por importador.',
      };

  String get titleEs => labelEs;

  static const mobileSegments = <AdminReportsHubSection>[
    AdminReportsHubSection.encomiendas,
    AdminReportsHubSection.promos,
    AdminReportsHubSection.referidos,
    AdminReportsHubSection.devoluciones,
  ];
}
