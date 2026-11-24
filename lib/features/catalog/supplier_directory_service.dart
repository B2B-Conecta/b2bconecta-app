import 'package:motolink_pro_app/core/data/supabase_access.dart';
import 'package:motolink_pro_app/core/data/jwt_clock_skew.dart';
import 'importer_store_profile.dart';

enum SupplierDirectoryFilter { all, purchased, rated }

class SupplierDirectoryEntry {
  const SupplierDirectoryEntry(
      {required this.profile,
      this.purchased = false,
      this.categories = const []});
  final ImporterStoreProfile profile;
  final bool purchased;
  final List<String> categories;

  factory SupplierDirectoryEntry.fromJson(Map<String, dynamic> json) =>
      SupplierDirectoryEntry(
          profile: ImporterStoreProfile.fromJson(json),
          purchased: json['purchased'] == true,
          categories: _strings(json['categories']));
}

List<String> _strings(dynamic value) => value is List
    ? value.whereType<String>().where((e) => e.trim().isNotEmpty).toList()
    : const [];

class SupplierDirectoryPage {
  const SupplierDirectoryPage(
      {required this.items,
      required this.total,
      this.states = const [],
      this.categories = const []});
  final List<SupplierDirectoryEntry> items;
  final int total;
  final List<String> states;
  final List<String> categories;

  factory SupplierDirectoryPage.fromJson(Map<String, dynamic> json) =>
      SupplierDirectoryPage(
          items: (json['items'] as List? ?? const [])
              .map((e) => SupplierDirectoryEntry.fromJson(
                  Map<String, dynamic>.from(e as Map)))
              .toList(),
          total: (json['total'] as num?)?.toInt() ?? 0,
          states: _strings(json['states']),
          categories: _strings(json['categories']));
}

typedef SupplierDirectoryLoader = Future<SupplierDirectoryPage> Function({
  required String query,
  required SupplierDirectoryFilter filter,
  required String? state,
  required String? category,
  required int offset,
});

class SupplierDirectoryService {
  static Future<SupplierDirectoryPage> load(
          {required String query,
          required SupplierDirectoryFilter filter,
          required String? state,
          required String? category,
          required int offset}) =>
      retryOnJwtIssuedAtFuture(() async {
        final data = await SupabaseAccess.client
            .rpc('aliado_supplier_directory', params: {
          'p_query': query.trim(),
          'p_filter': filter.name,
          'p_estado': state,
          'p_category': category,
          'p_limit': 40,
          'p_offset': offset,
        });
        return SupplierDirectoryPage.fromJson(
            Map<String, dynamic>.from(data as Map));
      });
}
