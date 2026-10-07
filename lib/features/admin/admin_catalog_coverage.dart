import 'package:motolink_pro_app/features/catalog/catalog_filters.dart';

/// Mayoristas registrados, separados por si tienen productos publicados.
class AdminCatalogCoverage {
  const AdminCatalogCoverage({
    required this.published,
    required this.withoutCatalog,
  });

  final List<ImporterOption> published;
  final List<ImporterOption> withoutCatalog;

  static const empty = AdminCatalogCoverage(
    published: [],
    withoutCatalog: [],
  );
}

AdminCatalogCoverage splitImportersByPublishedCatalog({
  required List<ImporterOption> importers,
  required Set<String> publishedOwnerIds,
}) {
  final published = <ImporterOption>[];
  final withoutCatalog = <ImporterOption>[];
  for (final importer in importers) {
    if (publishedOwnerIds.contains(importer.id)) {
      published.add(importer);
    } else {
      withoutCatalog.add(importer);
    }
  }
  return AdminCatalogCoverage(
    published: published,
    withoutCatalog: withoutCatalog,
  );
}
