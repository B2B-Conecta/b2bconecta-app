import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/part_model.dart';

class SupabaseService {
  SupabaseService._();

  static SupabaseClient get _client => Supabase.instance.client;

  /// Obtiene todos los repuestos desde la tabla [products].
  static Future<List<PartModel>> fetchParts() async {
    final response = await _client.from('products').select();
    final list = response as List<dynamic>;
    return list
        .map((row) => PartModel.fromJson(row as Map<String, dynamic>))
        .toList();
  }
}
