import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Shared Supabase client, storage buckets, and small helpers.
/// Domain services use this instead of reaching into [SupabaseService].
abstract final class SupabaseAccess {
  static const productImagesBucket = 'product-images';
  static const profileDocumentsBucket = 'profile-documents';
  static const orderInvoicesBucket = 'order-invoices';
  static const orderPaymentProofsBucket = 'order-payment-proofs';
  static const commissionSettlementInvoicesBucket =
      'commission-settlement-invoices';
  static const profileLogosBucket = 'profile-logos';
  static const promoCampaignsBucket = 'promo-campaigns';

  static SupabaseClient get client => Supabase.instance.client;

  static String? get currentUserId => client.auth.currentUser?.id;

  static bool get isLocalSupabase {
    final url = client.rest.url;
    return url.contains('127.0.0.1') ||
        url.contains('localhost:54321') ||
        url.contains('localhost:54321/');
  }

  static Future<void> unsubscribeChannel(RealtimeChannel? channel) async {
    if (channel == null) return;
    await client.removeChannel(channel);
  }

  static List<dynamic> decodeRpcJsonArray(dynamic res) {
    if (res is List) return res;
    if (res is String && res.isNotEmpty) {
      final decoded = jsonDecode(res);
      if (decoded is List) return decoded;
    }
    return const [];
  }

  static String? nullableUuid(String? raw) {
    final s = raw?.trim();
    if (s == null || s.isEmpty) return null;
    return s;
  }

  static String sanitizeIlike(String input) {
    return input
        .replaceAll('%', ' ')
        .replaceAll('_', ' ')
        .replaceAll(RegExp(r'[(),.]'), ' ')
        .trim();
  }

  static String profileDocExtension(String fileName) {
    final i = fileName.lastIndexOf('.');
    if (i < 0 || i == fileName.length - 1) return '';
    return fileName.substring(i + 1).toLowerCase();
  }

  static bool isAllowedProfileDocExtension(String ext) {
    const ok = {'pdf', 'jpg', 'jpeg', 'png', 'webp'};
    final e = ext == 'jpg' ? 'jpeg' : ext;
    return ok.contains(e);
  }

  static String mimeForProfileDocExtension(String ext) {
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'pdf':
      default:
        return 'application/pdf';
    }
  }
}
