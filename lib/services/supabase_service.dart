import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/part_model.dart';

class SupabaseService {
  SupabaseService._();

  static SupabaseClient get _client => Supabase.instance.client;

  /// Obtiene repuestos desde [products] con paginacion.
  static Future<List<PartModel>> fetchParts({
    int limit = 5,
    int offset = 0,
  }) async {
    final response = await _client
        .from('products')
        .select()
        .order('id', ascending: true)
        .range(offset, offset + limit - 1);
    final list = response as List<dynamic>;
    return list
        .map((row) => PartModel.fromJson(row as Map<String, dynamic>))
        .toList();
  }
}
