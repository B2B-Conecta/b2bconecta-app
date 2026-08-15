/// Pedido bloqueado porque el aliado no tiene estado/ciudad en el perfil.
class ProfileLocationException implements Exception {
  ProfileLocationException(this.message);

  final String message;

  @override
  String toString() => message;
}
