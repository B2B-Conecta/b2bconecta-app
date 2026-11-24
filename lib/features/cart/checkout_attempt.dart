import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

class CheckoutAttempt {
  const CheckoutAttempt(
      {required this.id, required this.signature, this.cartSignature});
  final String id;
  final String signature;
  final String? cartSignature;

  static String signatureFor(Map<String, dynamic> payload) {
    Object? canonical(Object? value) {
      if (value is Map<String, dynamic>) {
        final keys = value.keys.toList()..sort();
        return {for (final key in keys) key: canonical(value[key])};
      }
      if (value is List) return value.map(canonical).toList();
      return value;
    }

    return sha256
        .convert(utf8.encode(jsonEncode(canonical(payload))))
        .toString();
  }

  factory CheckoutAttempt.create(String signature, {String? cartSignature}) {
    final random = Random.secure();
    final bytes = List.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return CheckoutAttempt(
        id: '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}',
        signature: signature,
        cartSignature: cartSignature);
  }

  Map<String, String> toJson() => {
        'id': id,
        'signature': signature,
        if (cartSignature != null) 'cart_signature': cartSignature!
      };
  static CheckoutAttempt? fromJson(Object? value) {
    if (value is! Map) return null;
    final id = value['id'], signature = value['signature'];
    if (id is! String ||
        signature is! String ||
        !RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')
            .hasMatch(id) ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(signature)) return null;
    return CheckoutAttempt(
        id: id,
        signature: signature,
        cartSignature: value['cart_signature'] is String
            ? value['cart_signature'] as String
            : null);
  }
}

class CheckoutRecoveredException implements Exception {
  const CheckoutRecoveredException(this.orderId, {this.samePayload = false});
  final String orderId;
  final bool samePayload;
}
