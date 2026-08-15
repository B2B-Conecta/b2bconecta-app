/// Pedido bloqueado por política KYC (documentación no aprobada).
class KycVerificationException implements Exception {
  KycVerificationException(this.message);

  final String message;

  @override
  String toString() => message;
}
