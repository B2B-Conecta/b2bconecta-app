import 'package:shared_preferences/shared_preferences.dart';

/// Only product IDs, quantities and campaign IDs belong in the local draft.
/// Prices, permissions and stock are read again from the catalog on restore.
abstract interface class CartDraftStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

class PreferencesCartDraftStorage implements CartDraftStorage {
  @override
  Future<String?> read(String key) async =>
      (await SharedPreferences.getInstance()).getString(key);

  @override
  Future<void> write(String key, String value) async {
    final saved =
        await (await SharedPreferences.getInstance()).setString(key, value);
    if (!saved) {
      throw StateError('No se pudo guardar el carrito en este dispositivo.');
    }
  }
}
