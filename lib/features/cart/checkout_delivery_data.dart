import '../../core/data/supabase_access.dart';

class SavedDeliveryAddress {
  const SavedDeliveryAddress(
      {this.id,
      required this.label,
      required this.state,
      required this.city,
      required this.address,
      required this.mapsUrl,
      this.isDefault = false});
  final String? id;
  final String label, state, city, address, mapsUrl;
  final bool isDefault;
  String get summary => '$state, $city, $address';
  factory SavedDeliveryAddress.fromJson(Map<String, dynamic> row) =>
      SavedDeliveryAddress(
          id: row['id'] as String,
          label: row['label'] as String,
          state: row['estado'] as String,
          city: row['ciudad'] as String,
          address: row['direccion'] as String,
          mapsUrl: row['maps_url'] as String,
          isDefault: row['is_default'] == true);
}

class CheckoutPickupOption {
  const CheckoutPickupOption(
      {required this.id,
      required this.supplierId,
      required this.label,
      required this.state,
      required this.city,
      required this.address,
      required this.mapsUrl,
      this.instructions = ''});
  final String id,
      supplierId,
      label,
      state,
      city,
      address,
      mapsUrl,
      instructions;
  String get summary => '$state, $city, $address';
  factory CheckoutPickupOption.fromJson(Map<String, dynamic> row) =>
      CheckoutPickupOption(
          id: row['id'] as String,
          supplierId: row['importador_id'] as String,
          label: row['label'] as String,
          state: row['estado'] as String,
          city: row['ciudad'] as String,
          address: row['direccion'] as String,
          mapsUrl: row['maps_url'] as String,
          instructions: row['instructions'] as String? ?? '');
}

class CheckoutDeliveryData {
  static Future<List<SavedDeliveryAddress>> loadAddresses() async {
    final uid = SupabaseAccess.currentUserId;
    if (uid == null) throw StateError('No hay sesión activa.');
    final rows = await SupabaseAccess.client
        .from('retailer_delivery_addresses')
        .select()
        .eq('user_id', uid)
        .order('is_default', ascending: false)
        .order('label');
    return rows.map((row) => SavedDeliveryAddress.fromJson(row)).toList();
  }

  static Future<SavedDeliveryAddress> saveAddress(
      SavedDeliveryAddress address) async {
    final result = await SupabaseAccess.client
        .rpc('save_retailer_delivery_address', params: {
      'p_id': address.id,
      'p_label': address.label.trim(),
      'p_estado': address.state.trim(),
      'p_ciudad': address.city.trim(),
      'p_direccion': address.address.trim(),
      'p_maps_url': address.mapsUrl.trim(),
      'p_is_default': address.isDefault
    });
    return SavedDeliveryAddress(
        id: result.toString(),
        label: address.label.trim(),
        state: address.state.trim(),
        city: address.city.trim(),
        address: address.address.trim(),
        mapsUrl: address.mapsUrl.trim(),
        isDefault: address.isDefault);
  }

  static Future<void> deleteAddress(String id) async {
    final uid = SupabaseAccess.currentUserId;
    if (uid == null) throw StateError('No hay sesión activa.');
    await SupabaseAccess.client
        .from('retailer_delivery_addresses')
        .delete()
        .eq('id', id)
        .eq('user_id', uid);
  }

  static Future<List<CheckoutPickupOption>> loadPickups(
      String supplierId) async {
    final rows = await SupabaseAccess.client.rpc(
        'list_customer_pickup_for_checkout',
        params: {'p_importador_id': supplierId});
    return (rows as List)
        .map((row) => CheckoutPickupOption.fromJson(
            Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  static Future<String?> resolveAttempt(String id) async {
    final result = await SupabaseAccess.client
        .rpc('resolve_checkout_attempt', params: {'p_request_id': id});
    return result?.toString();
  }
}
