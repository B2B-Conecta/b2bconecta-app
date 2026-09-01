import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:motolink_pro_app/core/data/supabase_access.dart';
import 'package:motolink_pro_app/core/notifications/in_app_notification_model.dart';
import 'package:motolink_pro_app/core/notifications/notifications_service.dart';
import 'package:motolink_pro_app/features/admin/admin_service.dart';
import 'package:motolink_pro_app/features/admin/admin_user_activity_row_model.dart';
import 'package:motolink_pro_app/features/catalog/catalog_filters.dart';
import 'package:motolink_pro_app/features/catalog/catalog_service.dart';
import 'package:motolink_pro_app/features/catalog/part_model.dart';
import 'package:motolink_pro_app/features/catalog/promo_campaign_model.dart';
import 'package:motolink_pro_app/features/commissions/commission_settlement_document_type.dart';
import 'package:motolink_pro_app/features/commissions/commission_settlement_model.dart';
import 'package:motolink_pro_app/features/commissions/commission_volume_tiers.dart';
import 'package:motolink_pro_app/features/commissions/commissions_service.dart';
import 'package:motolink_pro_app/features/commissions/importer_commission_volume_context.dart';
import 'package:motolink_pro_app/features/inventory/catalog_import/catalog_import_mapping.dart';
import 'package:motolink_pro_app/features/inventory/catalog_import/catalog_import_result.dart';
import 'package:motolink_pro_app/features/inventory/catalog_import_validator.dart';
import 'package:motolink_pro_app/features/inventory/inventory_service.dart';
import 'package:motolink_pro_app/features/inventory/product_image_bulk_result.dart';
import 'package:motolink_pro_app/features/kyc/admin_aliado_morosidad_flag.dart';
import 'package:motolink_pro_app/features/kyc/kyc_approved_aliado_model.dart';
import 'package:motolink_pro_app/features/kyc/kyc_service.dart';
import 'package:motolink_pro_app/features/kyc/profile_document_model.dart';
import 'package:motolink_pro_app/features/logistics/carrier_flete_pago_modo.dart';
import 'package:motolink_pro_app/features/logistics/importer_carrier_driver_model.dart';
import 'package:motolink_pro_app/features/logistics/importer_carrier_model.dart';
import 'package:motolink_pro_app/features/logistics/importer_pickup_location_model.dart';
import 'package:motolink_pro_app/features/logistics/logistics_service.dart';
import 'package:motolink_pro_app/features/orders/shared/orders_service.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_message_model.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_model.dart';
import 'package:motolink_pro_app/features/payments/aliado_pago_frecuente_model.dart';
import 'package:motolink_pro_app/features/payments/payments_service.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';
import 'package:motolink_pro_app/features/profile/profile_service.dart';
import 'package:motolink_pro_app/features/referrals/admin_referral_row_model.dart';
import 'package:motolink_pro_app/features/referrals/external_referrer_model.dart';
import 'package:motolink_pro_app/features/referrals/referrals_service.dart';
import 'package:motolink_pro_app/features/reputation/admin_order_rating_row_model.dart';
import 'package:motolink_pro_app/features/reputation/aliado_received_rating_model.dart';
import 'package:motolink_pro_app/features/reputation/importador_received_rating_model.dart';
import 'package:motolink_pro_app/features/reputation/rating_questionnaire_model.dart';
import 'package:motolink_pro_app/features/reputation/reputation_service.dart';
import 'package:motolink_pro_app/features/reputation/reputation_weekly_snapshot_model.dart';
import 'package:motolink_pro_app/features/support/support_service.dart';
import 'package:motolink_pro_app/features/support/support_ticket_message_model.dart';
import 'package:motolink_pro_app/features/support/support_ticket_model.dart';

export 'package:motolink_pro_app/core/notifications/notifications_service.dart'
    show NotificationOrderSummary;
export 'package:motolink_pro_app/features/inventory/inventory_service.dart'
    show InventoryMetrics;

/// Compatibility facade. New code should call the domain service directly
/// (`OrdersService`, `CatalogService`, …). Existing `SupabaseService.*` calls
/// keep working.
class SupabaseService {
  SupabaseService._();

  static String? get currentUserId => SupabaseAccess.currentUserId;

  static bool get isLocalSupabase => SupabaseAccess.isLocalSupabase;

  static double get logisticFeeRate => PaymentsService.logisticFeeRate;

  static double calculateAliadoUnitPrice(double precioUnitarioProveedor) =>
      PaymentsService.calculateAliadoUnitPrice(precioUnitarioProveedor);

  static Future<void> unsubscribeChannel(RealtimeChannel? channel) =>
      SupabaseAccess.unsubscribeChannel(channel);

  static Future<List<InAppNotificationModel>> fetchMyNotifications({
    int limit = 100,
  }) =>
      NotificationsService.fetchMyNotifications(limit: limit);

  static Future<void> markNotificationAsRead(String notificationId) =>
      NotificationsService.markNotificationAsRead(notificationId);

  static Future<void> markAllNotificationsAsRead() =>
      NotificationsService.markAllNotificationsAsRead();

  static Future<void> markNotificationsReadForRelatedOrder(
          String transactionRequestId) =>
      NotificationsService.markNotificationsReadForRelatedOrder(
          transactionRequestId);

  static Future<void> deleteOldNotifications({
    int olderThanDays = 30,
    bool onlyRead = true,
  }) =>
      NotificationsService.deleteOldNotifications(
          olderThanDays: olderThanDays, onlyRead: onlyRead);

  static Future<void> deleteNotificationsByIds(List<String> notificationIds) =>
      NotificationsService.deleteNotificationsByIds(notificationIds);

  static Future<void> deleteAllMyNotifications() =>
      NotificationsService.deleteAllMyNotifications();

  static Future<TransactionRequestModel?> fetchTransactionRequestById(
    String requestId,
  ) =>
      OrdersService.fetchTransactionRequestById(requestId);

  static Future<List<TransactionRequestModel>>
      fetchCheckoutGroupLinesForTransactionRequest(String requestId) =>
          OrdersService.fetchCheckoutGroupLinesForTransactionRequest(requestId);

  static Future<Map<String, NotificationOrderSummary>>
      fetchNotificationOrderSummariesByRequestIds(
    List<String> requestIds,
  ) =>
          NotificationsService.fetchNotificationOrderSummariesByRequestIds(
              requestIds);

  static RealtimeChannel subscribeToMyNotifications({
    required void Function(InAppNotificationModel notification) onInsert,
  }) =>
      NotificationsService.subscribeToMyNotifications(onInsert: onInsert);

  static RealtimeChannel subscribeToTransactionRequestMessages({
    required String transactionRequestId,
    required void Function() onInsert,
  }) =>
      OrdersService.subscribeToTransactionRequestMessages(
          transactionRequestId: transactionRequestId, onInsert: onInsert);

  static RealtimeChannel subscribeToMyProfileAccess({
    required void Function() onAccessActive,
  }) =>
      ProfileService.subscribeToMyProfileAccess(onAccessActive: onAccessActive);

  static Future<ProfileModel?> fetchMyProfile() =>
      ProfileService.fetchMyProfile();

  static Future<String?> fetchProfileBusinessName(String profileId) =>
      ProfileService.fetchProfileBusinessName(profileId);

  static Future<ProfileModel?> fetchProfileById(String profileId) =>
      ProfileService.fetchProfileById(profileId);

  static Future<void> updateMyGeolocation({
    required double latitude,
    required double longitude,
  }) =>
      ProfileService.updateMyGeolocation(
          latitude: latitude, longitude: longitude);

  static String? normalizeHttpUrl(String? raw) =>
      ProfileService.normalizeHttpUrl(raw);

  static Future<void> upsertMyProfile({
    required String businessName,
    required String rif,
    required String role,
    String? phone,
    String? estado,
    String? ciudad,
    String? direccion,
    String? fiscalMapsUrl,
    String? legalContactName,
    String? legalContactEmail,
    String? legalContactPhone,
  }) =>
      ProfileService.upsertMyProfile(
          businessName: businessName,
          rif: rif,
          role: role,
          phone: phone,
          estado: estado,
          ciudad: ciudad,
          direccion: direccion,
          fiscalMapsUrl: fiscalMapsUrl,
          legalContactName: legalContactName,
          legalContactEmail: legalContactEmail,
          legalContactPhone: legalContactPhone);

  static String profileSaveErrorMessage(Object error) =>
      ProfileService.profileSaveErrorMessage(error);

  static Future<void> importadorSetAcceptedPagoMetodos(
    List<String> metodos,
  ) =>
      PaymentsService.importadorSetAcceptedPagoMetodos(metodos);

  static Future<void> importadorSetPagoSoloDivisas(bool enabled) =>
      PaymentsService.importadorSetPagoSoloDivisas(enabled);

  static Future<int> importadorBulkSetUsdPaymentDiscount({
    required double pct,
    required String scope,
  }) =>
      InventoryService.importadorBulkSetUsdPaymentDiscount(
          pct: pct, scope: scope);

  static Future<CatalogImportResult> importadorBulkUpsertProducts({
    required List<CatalogImportNormalizedRow> rows,
    CatalogImportOptions options = const CatalogImportOptions(),
  }) =>
      InventoryService.importadorBulkUpsertProducts(
          rows: rows, options: options);

  static Future<CatalogImportResult> runFlexibleCatalogImport({
    required List<CatalogImportParseBatch> batches,
    CatalogImportOptions options = const CatalogImportOptions(),
  }) =>
      InventoryService.runFlexibleCatalogImport(
          batches: batches, options: options);

  static Future<void> importadorSetPagoMetodoInstrucciones(
    Map<String, String> instrucciones,
  ) =>
      PaymentsService.importadorSetPagoMetodoInstrucciones(instrucciones);

  static Future<List<AliadoPagoFrecuenteModel>>
      fetchAliadoPagoFrecuenteImportador(String importadorId) =>
          PaymentsService.fetchAliadoPagoFrecuenteImportador(importadorId);

  static Future<String> createSignedUrlForProfileLogo(String storagePath) =>
      ProfileService.createSignedUrlForProfileLogo(storagePath);

  static Future<void> uploadMyProfileLogo({
    required Uint8List bytes,
    required String fileExtension,
  }) =>
      ProfileService.uploadMyProfileLogo(
          bytes: bytes, fileExtension: fileExtension);

  static Future<void> clearMyProfileLogo() =>
      ProfileService.clearMyProfileLogo();

  static Future<List<ImporterOption>> fetchImporterOptions() =>
      CatalogService.fetchImporterOptions();

  static Future<int> fetchProductsCount({CatalogFilters? filters}) =>
      CatalogService.fetchProductsCount(filters: filters);

  static Future<InventoryMetrics> fetchMyInventoryMetrics() =>
      InventoryService.fetchMyInventoryMetrics();

  static Future<List<PartModel>> fetchMyInventory({
    int limit = 200,
    int offset = 0,
    String? searchQuery,
    String? category,
    bool onlyLowStock = false,
    bool onlyInactive = false,
    bool onlyActive = false,
  }) =>
      InventoryService.fetchMyInventory(
          limit: limit,
          offset: offset,
          searchQuery: searchQuery,
          category: category,
          onlyLowStock: onlyLowStock,
          onlyInactive: onlyInactive,
          onlyActive: onlyActive);

  static Future<Map<String, dynamic>?> fetchProductDiscountRulesById(
    String productId,
  ) =>
      InventoryService.fetchProductDiscountRulesById(productId);

  static Future<String?> findProductIdByOwnerSku(String sku) =>
      InventoryService.findProductIdByOwnerSku(sku);

  static Future<void> setProductActive({
    required String productId,
    required bool isActive,
  }) =>
      InventoryService.setProductActive(
          productId: productId, isActive: isActive);

  static Future<void> setProductsActiveBulk({
    required List<String> productIds,
    required bool isActive,
  }) =>
      InventoryService.setProductsActiveBulk(
          productIds: productIds, isActive: isActive);

  static Future<void> deleteProduct({required String productId}) =>
      InventoryService.deleteProduct(productId: productId);

  static Future<int> deleteProductsBulk({
    required List<String> productIds,
  }) =>
      InventoryService.deleteProductsBulk(productIds: productIds);

  static Future<String> uploadProductImage({
    required Uint8List bytes,
    required String fileExtension,
    String? productId,
    int? slot,
  }) =>
      InventoryService.uploadProductImage(
          bytes: bytes,
          fileExtension: fileExtension,
          productId: productId,
          slot: slot);

  static Future<String> insertProduct({
    required String sku,
    required String name,
    String? description,
    required double priceUsd,
    double? salePriceUsd,
    Map<String, dynamic>? discountRules,
    required int stock,
    String? category,
    String? compatibility,
    String? imageUrl,
    List<String>? imageUrls,
    bool isActive = true,
    bool hasWarranty = false,
    Map<String, dynamic>? customFields,
  }) =>
      InventoryService.insertProduct(
          sku: sku,
          name: name,
          description: description,
          priceUsd: priceUsd,
          salePriceUsd: salePriceUsd,
          discountRules: discountRules,
          stock: stock,
          category: category,
          compatibility: compatibility,
          imageUrl: imageUrl,
          imageUrls: imageUrls,
          isActive: isActive,
          hasWarranty: hasWarranty,
          customFields: customFields);

  static Future<void> updateProduct({
    required String productId,
    required String sku,
    required String name,
    String? description,
    required double priceUsd,
    double? salePriceUsd,
    bool clearSalePrice = false,
    Map<String, dynamic>? discountRules,
    bool clearDiscountRules = false,
    required int stock,
    String? category,
    String? compatibility,
    String? imageUrl,
    List<String>? imageUrls,
    required bool isActive,
    bool hasWarranty = false,
    Map<String, dynamic>? customFields,
    bool clearCustomFields = false,
  }) =>
      InventoryService.updateProduct(
          productId: productId,
          sku: sku,
          name: name,
          description: description,
          priceUsd: priceUsd,
          salePriceUsd: salePriceUsd,
          clearSalePrice: clearSalePrice,
          discountRules: discountRules,
          clearDiscountRules: clearDiscountRules,
          stock: stock,
          category: category,
          compatibility: compatibility,
          imageUrl: imageUrl,
          imageUrls: imageUrls,
          isActive: isActive,
          hasWarranty: hasWarranty,
          customFields: customFields,
          clearCustomFields: clearCustomFields);

  static Future<void> setProductImageUrls({
    required String productId,
    required List<String> imageUrls,
  }) =>
      InventoryService.setProductImageUrls(
          productId: productId, imageUrls: imageUrls);

  static Future<Map<String, ProductSkuImageIndexEntry>>
      fetchMyInventorySkuImageIndex({
    int limit = 5000,
  }) =>
          InventoryService.fetchMyInventorySkuImageIndex(limit: limit);

  static Future<ProductImageBulkResult> importadorBulkSetProductImages({
    required List<Map<String, dynamic>> rows,
  }) =>
      InventoryService.importadorBulkSetProductImages(rows: rows);

  static Future<void> updateProductPriceAndStock({
    required String productId,
    required double priceUsd,
    required int stock,
    double? salePriceUsd,
    bool clearSalePrice = false,
    Map<String, dynamic>? discountRules,
    bool clearDiscountRules = false,
    bool? hasWarranty,
  }) =>
      InventoryService.updateProductPriceAndStock(
          productId: productId,
          priceUsd: priceUsd,
          stock: stock,
          salePriceUsd: salePriceUsd,
          clearSalePrice: clearSalePrice,
          discountRules: discountRules,
          clearDiscountRules: clearDiscountRules,
          hasWarranty: hasWarranty);

  static Future<List<TransactionRequestModel>> fetchMyTransactionRequests() =>
      OrdersService.fetchMyTransactionRequests();

  static Future<List<TransactionRequestModel>>
      fetchMyPedidosActivosYCerradosForAliado() =>
          OrdersService.fetchMyPedidosActivosYCerradosForAliado();

  static Future<List<TransactionRequestModel>>
      fetchValidatedTransactionRequestsForImporter() =>
          OrdersService.fetchValidatedTransactionRequestsForImporter();

  static Future<List<TransactionRequestModel>>
      fetchActiveTransactionRequestsForImporter() =>
          OrdersService.fetchActiveTransactionRequestsForImporter();

  static Future<List<TransactionRequestModel>>
      fetchSubOrderSlicesForImporterUnified() =>
          OrdersService.fetchSubOrderSlicesForImporterUnified();

  static Future<List<TransactionRequestModel>>
      fetchUnifiedTransactionRequestsForImporter() =>
          OrdersService.fetchUnifiedTransactionRequestsForImporter();

  static Future<List<TransactionRequestModel>>
      fetchValidatedTransactionRequestsForProduct(String productId) =>
          OrdersService.fetchValidatedTransactionRequestsForProduct(productId);

  static Future<List<TransactionRequestModel>>
      fetchTransactionRequestsForAdmin() =>
          OrdersService.fetchTransactionRequestsForAdmin();

  static Future<List<TransactionRequestModel>>
      fetchActiveTransactionRequestsForAdmin() =>
          OrdersService.fetchActiveTransactionRequestsForAdmin();

  static Future<List<TransactionRequestModel>>
      fetchClosedTransactionRequestsForAdmin() =>
          OrdersService.fetchClosedTransactionRequestsForAdmin();

  static Future<List<TransactionRequestModel>>
      fetchUnifiedTransactionRequestsForAdmin() =>
          OrdersService.fetchUnifiedTransactionRequestsForAdmin();

  static Future<List<TransactionRequestModel>>
      fetchTransactionRequestsForAdminReport({
    required DateTime createdFromLocal,
    required DateTime createdToLocal,
    List<String>? statuses,
    String? ownerId,
    int limit = 2500,
  }) =>
          OrdersService.fetchTransactionRequestsForAdminReport(
              createdFromLocal: createdFromLocal,
              createdToLocal: createdToLocal,
              statuses: statuses,
              ownerId: ownerId,
              limit: limit);

  static Future<List<ProfileModel>> fetchB2BProfilesForAdminKycReview() =>
      KycService.fetchB2BProfilesForAdminKycReview();

  static Future<void> adminSetProfileKycStatus({
    required String profileId,
    required String status,
    String? note,
  }) =>
      KycService.adminSetProfileKycStatus(
          profileId: profileId, status: status, note: note);

  static Future<void> adminSetImportadorAccountAccess({
    required String profileId,
    required String status,
    String? note,
  }) =>
      KycService.adminSetImportadorAccountAccess(
          profileId: profileId, status: status, note: note);

  static Future<Map<String, AdminAliadoMorosidadFlag>>
      adminAliadosPedidosMorososFlags() =>
          KycService.adminAliadosPedidosMorososFlags();

  static Future<void> adminSetAliadoPedidosSuspendidosMorosidad({
    required String aliadoId,
    required bool suspend,
  }) =>
      KycService.adminSetAliadoPedidosSuspendidosMorosidad(
          aliadoId: aliadoId, suspend: suspend);

  static Future<void> adminSetProfileDocumentReviewStatus({
    required String profileId,
    required String docType,
    required String status,
    String? note,
  }) =>
      KycService.adminSetProfileDocumentReviewStatus(
          profileId: profileId, docType: docType, status: status, note: note);

  static Future<void> profileSubmitKycForReview() =>
      KycService.profileSubmitKycForReview();

  static Future<void> profileSubmitImportadorForReview() =>
      KycService.profileSubmitImportadorForReview();

  static Future<void> upsertDevicePushToken({required String token}) =>
      NotificationsService.upsertDevicePushToken(token: token);

  static Future<void> removeDevicePushToken({required String token}) =>
      NotificationsService.removeDevicePushToken(token: token);

  static Future<void> acceptTerms({required String version}) =>
      ProfileService.acceptTerms(version: version);

  static Future<List<ProfileDocumentModel>> fetchMyProfileDocuments() =>
      KycService.fetchMyProfileDocuments();

  static Future<List<ProfileDocumentModel>> fetchProfileDocumentsForProfile(
    String profileId,
  ) =>
      KycService.fetchProfileDocumentsForProfile(profileId);

  static Future<String> createSignedUrlForProfileDocument(
    String storagePath,
  ) =>
      KycService.createSignedUrlForProfileDocument(storagePath);

  static Future<void> uploadMyProfileDocument({
    required String docType,
    required Uint8List bytes,
    required String fileName,
  }) =>
      KycService.uploadMyProfileDocument(
          docType: docType, bytes: bytes, fileName: fileName);

  static Future<int> fetchOpenTransactionRequestCountForCurrentAliado() =>
      OrdersService.fetchOpenTransactionRequestCountForCurrentAliado();

  static Future<void> insertTransactionRequest({
    required String productId,
    required String ownerId,
    required int cantidad,
    required double precioUnitarioProveedor,
    bool destinoEntregaUsaPerfil = true,
    String? destinoEntregaTexto,
    String? destinoEntregaMapsUrl,
  }) =>
      OrdersService.insertTransactionRequest(
          productId: productId,
          ownerId: ownerId,
          cantidad: cantidad,
          precioUnitarioProveedor: precioUnitarioProveedor,
          destinoEntregaUsaPerfil: destinoEntregaUsaPerfil,
          destinoEntregaTexto: destinoEntregaTexto,
          destinoEntregaMapsUrl: destinoEntregaMapsUrl);

  static Future<String> checkoutMultiImportadorCart({
    required List<Map<String, dynamic>> lines,
    bool destinoEntregaUsaPerfil = true,
    String? destinoEntregaTexto,
    String? destinoEntregaMapsUrl,
    Map<String, String> promoByImportador = const {},
    Map<String, Map<String, String?>> carriersByImportador = const {},
  }) =>
      OrdersService.checkoutMultiImportadorCart(
          lines: lines,
          destinoEntregaUsaPerfil: destinoEntregaUsaPerfil,
          destinoEntregaTexto: destinoEntregaTexto,
          destinoEntregaMapsUrl: destinoEntregaMapsUrl,
          promoByImportador: promoByImportador,
          carriersByImportador: carriersByImportador);

  static Future<double?> fetchGlobalTasaBcv() =>
      CommissionsService.fetchGlobalTasaBcv();

  static Future<({double tasa, DateTime updatedAt, String? effectiveDate})?>
      fetchGlobalTasaBcvRecord() =>
          CommissionsService.fetchGlobalTasaBcvRecord();

  static bool globalTasaBcvNeedsDailySync(DateTime? updatedAt) =>
      CommissionsService.globalTasaBcvNeedsDailySync(updatedAt);

  static Future<void> adminSetTasaBcv(double tasa) =>
      CommissionsService.adminSetTasaBcv(tasa);

  static Future<int> runDailyTasaBcvNotifyIfDue() =>
      CommissionsService.runDailyTasaBcvNotifyIfDue();

  static Future<double?> syncGlobalTasaBcvFromReference() =>
      CommissionsService.syncGlobalTasaBcvFromReference();

  static Future<double> resolveTasaBcvEmision() =>
      CommissionsService.resolveTasaBcvEmision();

  static Future<void> adminUpdateTransactionRequest({
    required String id,
    required String status,
    String? notasAdmin,
  }) =>
      OrdersService.adminUpdateTransactionRequest(
          id: id, status: status, notasAdmin: notasAdmin);

  static Future<String> createSignedUrlForOrderInvoice(String storagePath) =>
      PaymentsService.createSignedUrlForOrderInvoice(storagePath);

  static Future<String> createSignedUrlForComprobantePago(String storagePath) =>
      PaymentsService.createSignedUrlForComprobantePago(storagePath);

  static Future<String> createSignedUrlForEfectivoRespaldo(
          String storagePath) =>
      PaymentsService.createSignedUrlForEfectivoRespaldo(storagePath);

  static Future<void> aliadoSubmitComprobantePago({
    required String transactionRequestId,
    required String metodo,
    required Uint8List bytes,
    required String fileName,
  }) =>
      PaymentsService.aliadoSubmitComprobantePago(
          transactionRequestId: transactionRequestId,
          metodo: metodo,
          bytes: bytes,
          fileName: fileName);

  static Future<void> aliadoSubmitComprobantePagoBundle({
    required List<TransactionRequestModel> lines,
    required String metodo,
    required Uint8List bytes,
    required String fileName,
  }) =>
      PaymentsService.aliadoSubmitComprobantePagoBundle(
          lines: lines, metodo: metodo, bytes: bytes, fileName: fileName);

  static Future<void> aliadoDeclaraPagoEfectivo({
    required String transactionRequestId,
  }) =>
      PaymentsService.aliadoDeclaraPagoEfectivo(
          transactionRequestId: transactionRequestId);

  static Future<void> aliadoDeclaraPagoEfectivoBundle({
    required List<TransactionRequestModel> lines,
  }) =>
      PaymentsService.aliadoDeclaraPagoEfectivoBundle(lines: lines);

  static Future<void> importadorSetPagoRevisionEstadoBundle({
    required List<String> transactionRequestIds,
    required String nuevoEstado,
    String? rechazoNota,
  }) =>
      PaymentsService.importadorSetPagoRevisionEstadoBundle(
          transactionRequestIds: transactionRequestIds,
          nuevoEstado: nuevoEstado,
          rechazoNota: rechazoNota);

  static Future<void> importadorSetPagoRevisionEstado({
    required String transactionRequestId,
    required String nuevoEstado,
    String? rechazoNota,
  }) =>
      PaymentsService.importadorSetPagoRevisionEstado(
          transactionRequestId: transactionRequestId,
          nuevoEstado: nuevoEstado,
          rechazoNota: rechazoNota);

  static Future<void> registrarRespaldoCobroEfectivo({
    required String transactionRequestId,
    required Uint8List bytes,
    required String fileName,
  }) =>
      PaymentsService.registrarRespaldoCobroEfectivo(
          transactionRequestId: transactionRequestId,
          bytes: bytes,
          fileName: fileName);

  static Future<void> adminAprobarPagoAliado(String requestId) =>
      PaymentsService.adminAprobarPagoAliado(requestId);

  static Future<void> adminRechazarComprobantePago({
    required String requestId,
    required String nota,
  }) =>
      PaymentsService.adminRechazarComprobantePago(
          requestId: requestId, nota: nota);

  static Future<void> importerSubmitMotoconectaProveedorFactura({
    required String transactionRequestId,
    required Uint8List bytes,
    required String fileName,
  }) =>
      OrdersService.importerSubmitMotoconectaProveedorFactura(
          transactionRequestId: transactionRequestId,
          bytes: bytes,
          fileName: fileName);

  static Future<void> importerSubmitMotoconectaProveedorFacturaBundle({
    required List<String> transactionRequestIds,
    required Uint8List bytes,
    required String fileName,
  }) =>
      OrdersService.importerSubmitMotoconectaProveedorFacturaBundle(
          transactionRequestIds: transactionRequestIds,
          bytes: bytes,
          fileName: fileName);

  static Future<void> importerSubmitOrderInvoice({
    required String transactionRequestId,
    required Uint8List bytes,
    required String fileName,
  }) =>
      OrdersService.importerSubmitOrderInvoice(
          transactionRequestId: transactionRequestId,
          bytes: bytes,
          fileName: fileName);

  static Future<void> importerMarcaPedidoEnTransito({
    required String requestId,
    required int transitEtaDays,
    required int transitEtaHours,
  }) =>
      OrdersService.importerMarcaPedidoEnTransito(
          requestId: requestId,
          transitEtaDays: transitEtaDays,
          transitEtaHours: transitEtaHours);

  static Future<void> adminMarcaPedidoEnTransito({
    required String requestId,
    int transitEtaDays = 0,
    int transitEtaHours = 0,
  }) =>
      OrdersService.adminMarcaPedidoEnTransito(
          requestId: requestId,
          transitEtaDays: transitEtaDays,
          transitEtaHours: transitEtaHours);

  static Future<void> adminSetTransactionRequestRutaMapsUrl({
    required String requestId,
    required String? urlOrNull,
  }) =>
      OrdersService.adminSetTransactionRequestRutaMapsUrl(
          requestId: requestId, urlOrNull: urlOrNull);

  static Future<List<TransactionRequestMessageModel>>
      fetchTransactionRequestMessages(String transactionRequestId) =>
          OrdersService.fetchTransactionRequestMessages(transactionRequestId);

  static Future<List<TransactionRequestMessageModel>>
      fetchTransactionRequestMessagesForRequests(
    List<String> transactionRequestIds,
  ) =>
          OrdersService.fetchTransactionRequestMessagesForRequests(
              transactionRequestIds);

  static List<RealtimeChannel> subscribeToTransactionRequestMessagesMany({
    required List<String> transactionRequestIds,
    required void Function() onInsert,
  }) =>
      OrdersService.subscribeToTransactionRequestMessagesMany(
          transactionRequestIds: transactionRequestIds, onInsert: onInsert);

  static Future<List<KycApprovedAliadoModel>>
      listKycApprovedAliadosForImportador() =>
          KycService.listKycApprovedAliadosForImportador();

  static Future<List<ProfileDocumentModel>> fetchCounterpartyProfileDocuments(
    String counterpartyProfileId,
  ) =>
      KycService.fetchCounterpartyProfileDocuments(counterpartyProfileId);

  static Future<void> insertTransactionRequestMessageAsImportador({
    required String transactionRequestId,
    required String body,
  }) =>
      OrdersService.insertTransactionRequestMessageAsImportador(
          transactionRequestId: transactionRequestId, body: body);

  static Future<void> insertTransactionRequestMessageAsAliado({
    required String transactionRequestId,
    required String body,
  }) =>
      OrdersService.insertTransactionRequestMessageAsAliado(
          transactionRequestId: transactionRequestId, body: body);

  static Future<void> insertTransactionRequestMessageAsAdmin({
    required String transactionRequestId,
    required String body,
  }) =>
      OrdersService.insertTransactionRequestMessageAsAdmin(
          transactionRequestId: transactionRequestId, body: body);

  static Future<void> adminAnulaPedidoPorMotolink({
    required String transactionRequestId,
    required String motivo,
  }) =>
      OrdersService.adminAnulaPedidoPorMotolink(
          transactionRequestId: transactionRequestId, motivo: motivo);

  static Future<void> aliadoCancelaPedidoPendiente({
    required String transactionRequestId,
    required String motivo,
  }) =>
      OrdersService.aliadoCancelaPedidoPendiente(
          transactionRequestId: transactionRequestId, motivo: motivo);

  static Future<void> importerProponeAjusteCantidad({
    required String transactionRequestId,
    required int offeredQty,
    String note = '',
  }) =>
      OrdersService.importerProponeAjusteCantidad(
          transactionRequestId: transactionRequestId,
          offeredQty: offeredQty,
          note: note);

  static Future<void> aliadoRespondeAjusteCantidad({
    required String transactionRequestId,
    required bool aceptar,
  }) =>
      OrdersService.aliadoRespondeAjusteCantidad(
          transactionRequestId: transactionRequestId, aceptar: aceptar);

  static Future<void> importerCancelaPedidoEnGestion({
    required String transactionRequestId,
    required String motivo,
  }) =>
      OrdersService.importerCancelaPedidoEnGestion(
          transactionRequestId: transactionRequestId, motivo: motivo);

  static Future<void> aliadoMarcarPedidoEntregado(
          String transactionRequestId) =>
      OrdersService.aliadoMarcarPedidoEntregado(transactionRequestId);

  static Future<int> aliadoMarcarPedidosEntregadosImportadorEnGrupo({
    required String checkoutGroupId,
    required String importadorId,
  }) =>
      OrdersService.aliadoMarcarPedidosEntregadosImportadorEnGrupo(
          checkoutGroupId: checkoutGroupId, importadorId: importadorId);

  static Future<void> aliadoSubmitOrderExperienceImportadorGrupo({
    required String checkoutGroupId,
    required String importadorId,
    required int stars,
    required String comment,
    Map<String, dynamic> answers = const {},
  }) =>
      ReputationService.aliadoSubmitOrderExperienceImportadorGrupo(
          checkoutGroupId: checkoutGroupId,
          importadorId: importadorId,
          stars: stars,
          comment: comment,
          answers: answers);

  static Future<void> aliadoSetDocumentTypePreference({
    required String transactionRequestId,
    required String documentType,
  }) =>
      ReputationService.aliadoSetDocumentTypePreference(
          transactionRequestId: transactionRequestId,
          documentType: documentType);

  static Future<void> aliadoSubmitOrderExperience({
    required String transactionRequestId,
    required int stars,
    required String comment,
    Map<String, dynamic> answers = const {},
  }) =>
      ReputationService.aliadoSubmitOrderExperience(
          transactionRequestId: transactionRequestId,
          stars: stars,
          comment: comment,
          answers: answers);

  static Future<RatingQuestionnaireModel> fetchRatingQuestionnaire({
    required String audience,
  }) =>
      ReputationService.fetchRatingQuestionnaire(audience: audience);

  static Future<List<PromoCampaignModel>>
      fetchActivePromoCampaignsForAliado() =>
          CatalogService.fetchActivePromoCampaignsForAliado();

  static Future<List<PromoCampaignModel>>
      fetchActivePromoCampaignsForImportador() =>
          CatalogService.fetchActivePromoCampaignsForImportador();

  static Future<List<PromoCampaignModel>>
      fetchActivePromoCampaignsForImportadorAds() =>
          CatalogService.fetchActivePromoCampaignsForImportadorAds();

  static Future<List<PromoCampaignModel>> fetchPromoCampaignsAdmin() =>
      CatalogService.fetchPromoCampaignsAdmin();

  static Future<PromoCampaignModel> insertPromoCampaign({
    required PromoCampaignModel draft,
  }) =>
      CatalogService.insertPromoCampaign(draft: draft);

  static Future<PromoCampaignModel> updatePromoCampaign({
    required String id,
    required PromoCampaignModel draft,
  }) =>
      CatalogService.updatePromoCampaign(id: id, draft: draft);

  static Future<void> deletePromoCampaign({
    required String id,
    String? imageStoragePath,
  }) =>
      CatalogService.deletePromoCampaign(
          id: id, imageStoragePath: imageStoragePath);

  static Future<({String path, String publicUrl})> uploadPromoCampaignImage({
    required Uint8List bytes,
    required String fileExtension,
    String? campaignId,
  }) =>
      CatalogService.uploadPromoCampaignImage(
          bytes: bytes, fileExtension: fileExtension, campaignId: campaignId);

  static Future<List<ReputationWeeklySnapshotModel>>
      listMyReputationWeeklySnapshots({
    int limit = 12,
  }) =>
          ReputationService.listMyReputationWeeklySnapshots(limit: limit);

  static Future<List<AliadoReceivedRatingModel>> listAliadoReceivedRatings({
    int limit = 30,
    int offset = 0,
  }) =>
      ReputationService.listAliadoReceivedRatings(limit: limit, offset: offset);

  static Future<List<ImportadorReceivedRatingModel>>
      listImportadorReceivedRatings({
    int limit = 30,
    int offset = 0,
  }) =>
          ReputationService.listImportadorReceivedRatings(
              limit: limit, offset: offset);

  static Future<void> logUserLoginEvent({String source = 'app'}) =>
      AdminService.logUserLoginEvent(source: source);

  static Future<List<AdminUserActivityRowModel>>
      listAdminUserActivityMonitoring({
    String? role,
    String period = 'week',
  }) =>
          AdminService.listAdminUserActivityMonitoring(
              role: role, period: period);

  static Future<List<ProfileModel>> ownerListProfiles() =>
      AdminService.ownerListProfiles();

  static Future<void> ownerSetProfileRole({
    required String profileId,
    required String role,
  }) =>
      AdminService.ownerSetProfileRole(profileId: profileId, role: role);

  static Future<void> ownerSetAccountAccess({
    required String profileId,
    required String status,
    String? note,
  }) =>
      AdminService.ownerSetAccountAccess(
        profileId: profileId,
        status: status,
        note: note,
      );

  static Future<void> ownerDeactivateProfile({
    required String profileId,
    required String note,
  }) =>
      AdminService.ownerDeactivateProfile(profileId: profileId, note: note);

  static Future<void> applyReferralCode(String code) =>
      ReferralsService.applyReferralCode(code);

  static Future<List<ExternalReferrerModel>> listAdminExternalReferrers({
    int limit = 100,
    int offset = 0,
    bool activeOnly = false,
  }) =>
      ReferralsService.listAdminExternalReferrers(
          limit: limit, offset: offset, activeOnly: activeOnly);

  static Future<ExternalReferrerModel> adminCreateExternalReferrer({
    required String fullName,
    required String phone,
    required String email,
    String? notes,
  }) =>
      ReferralsService.adminCreateExternalReferrer(
          fullName: fullName, phone: phone, email: email, notes: notes);

  static Future<ExternalReferrerModel> adminUpdateExternalReferrer({
    required String id,
    String? fullName,
    String? phone,
    String? email,
    bool? active,
    String? notes,
  }) =>
      ReferralsService.adminUpdateExternalReferrer(
          id: id,
          fullName: fullName,
          phone: phone,
          email: email,
          active: active,
          notes: notes);

  static Future<List<AdminReferralStatRowModel>> listAdminReferralStats({
    int limit = 100,
    int offset = 0,
  }) =>
      ReferralsService.listAdminReferralStats(limit: limit, offset: offset);

  static Future<List<AdminReferredUserRowModel>> listAdminReferredUsers({
    required String referrerId,
    int limit = 100,
    int offset = 0,
  }) =>
      ReferralsService.listAdminReferredUsers(
          referrerId: referrerId, limit: limit, offset: offset);

  static Future<List<AdminOrderRatingRowModel>> listAdminOrderRatings({
    String? importadorId,
    String? aliadoId,
    int limit = 50,
    int offset = 0,
    bool? commentHidden,
  }) =>
      ReputationService.listAdminOrderRatings(
          importadorId: importadorId,
          aliadoId: aliadoId,
          limit: limit,
          offset: offset,
          commentHidden: commentHidden);

  static Future<void> adminSetOrderRatingCommentHidden({
    required String ratingId,
    required bool hidden,
    String? reason,
  }) =>
      ReputationService.adminSetOrderRatingCommentHidden(
          ratingId: ratingId, hidden: hidden, reason: reason);

  static Future<void> adminSubmitOrderRating({
    required String raterRole,
    required String transactionRequestId,
    required int stars,
    required String comment,
    Map<String, dynamic> answers = const {},
  }) =>
      ReputationService.adminSubmitOrderRating(
          raterRole: raterRole,
          transactionRequestId: transactionRequestId,
          stars: stars,
          comment: comment,
          answers: answers);

  static Future<Map<String, dynamic>?> fetchAliadoOrderRatingAnswers({
    required String transactionRequestId,
    String? checkoutGroupId,
    String? importadorId,
  }) =>
      ReputationService.fetchAliadoOrderRatingAnswers(
          transactionRequestId: transactionRequestId,
          checkoutGroupId: checkoutGroupId,
          importadorId: importadorId);

  static String formatOrderRatingAnswersForExportCell(
          Map<String, dynamic> raw) =>
      ReputationService.formatOrderRatingAnswersForExportCell(raw);

  static Future<
      Map<String, String>> fetchAliadoOrderRatingAnswerSummariesForExport(
    List<TransactionRequestModel> rows,
  ) =>
      ReputationService.fetchAliadoOrderRatingAnswerSummariesForExport(rows);

  static Future<void> importerSubmitOrderRating({
    required String transactionRequestId,
    required int stars,
    required String comment,
    Map<String, dynamic> answers = const {},
  }) =>
      ReputationService.importerSubmitOrderRating(
          transactionRequestId: transactionRequestId,
          stars: stars,
          comment: comment,
          answers: answers);

  static Future<void> importerSubmitOrderRatingGrupo({
    required String checkoutGroupId,
    required String aliadoId,
    required int stars,
    required String comment,
    Map<String, dynamic> answers = const {},
  }) =>
      ReputationService.importerSubmitOrderRatingGrupo(
          checkoutGroupId: checkoutGroupId,
          aliadoId: aliadoId,
          stars: stars,
          comment: comment,
          answers: answers);

  static Future<bool> importerHasRatedAliado({
    String? checkoutGroupId,
    String? transactionRequestId,
    required String aliadoId,
  }) =>
      ReputationService.importerHasRatedAliado(
          checkoutGroupId: checkoutGroupId,
          transactionRequestId: transactionRequestId,
          aliadoId: aliadoId);

  static Future<bool> orderRatingExistsForRater({
    required String raterRole,
    required String importadorId,
    required String aliadoId,
    String? checkoutGroupId,
    String? transactionRequestId,
  }) =>
      ReputationService.orderRatingExistsForRater(
          raterRole: raterRole,
          importadorId: importadorId,
          aliadoId: aliadoId,
          checkoutGroupId: checkoutGroupId,
          transactionRequestId: transactionRequestId);

  static Future<void> importerAdvanceTransactionRequest({
    required String id,
    required String newStatus,
    List<String>? batchIds,
  }) =>
      OrdersService.importerAdvanceTransactionRequest(
          id: id, newStatus: newStatus, batchIds: batchIds);

  static Future<List<PartModel>> fetchParts({
    int limit = 6,
    int offset = 0,
    CatalogFilters? filters,
  }) =>
      CatalogService.fetchParts(limit: limit, offset: offset, filters: filters);

  static Future<double> fetchDefaultCommissionRate() =>
      CommissionsService.fetchDefaultCommissionRate();

  static Future<void> adminSetDefaultCommissionRate(double rate) =>
      CommissionsService.adminSetDefaultCommissionRate(rate);

  static Future<void> adminSetImportadorCommissionRate({
    required String importadorId,
    double? rate,
  }) =>
      CommissionsService.adminSetImportadorCommissionRate(
          importadorId: importadorId, rate: rate);

  static Future<List<CommissionVolumeTier>> fetchCommissionVolumeTiers() =>
      CommissionsService.fetchCommissionVolumeTiers();

  static Future<ImporterCommissionVolumeContext?>
      fetchImporterCommissionVolumeContext({
    String? importadorId,
  }) =>
          CommissionsService.fetchImporterCommissionVolumeContext(
              importadorId: importadorId);

  static Future<Map<String, ImporterCommissionVolumeContext>>
      fetchImporterCommissionVolumeContexts(
    Iterable<String> importadorIds,
  ) =>
          CommissionsService.fetchImporterCommissionVolumeContexts(
              importadorIds);

  static Future<void> adminSetCommissionVolumeTiers(
    List<CommissionVolumeTier> tiers,
  ) =>
      CommissionsService.adminSetCommissionVolumeTiers(tiers);

  static Future<List<CommissionSettlementModel>> fetchCommissionSettlements({
    int limit = 80,
  }) =>
      CommissionsService.fetchCommissionSettlements(limit: limit);

  static Future<List<CommissionSettlementLineModel>>
      fetchCommissionSettlementLines(String settlementId) =>
          CommissionsService.fetchCommissionSettlementLines(settlementId);

  static Future<Map<String, dynamic>>
      adminGenerateCommissionSettlementsCurrentWeek() =>
          CommissionsService.adminGenerateCommissionSettlementsCurrentWeek();

  static Future<Map<String, dynamic>> adminGenerateCommissionSettlementsWeek({
    DateTime? weekStart,
  }) =>
      CommissionsService.adminGenerateCommissionSettlementsWeek(
          weekStart: weekStart);

  static Future<String> createSignedUrlForCommissionInvoicePdf(
    String storagePath,
  ) =>
      CommissionsService.createSignedUrlForCommissionInvoicePdf(storagePath);

  static Future<void> generateAndUploadCommissionSettlementInvoicePdf({
    required CommissionSettlementModel settlement,
  }) =>
      CommissionsService.generateAndUploadCommissionSettlementInvoicePdf(
          settlement: settlement);

  static Future<String> peekCommissionSettlementReference(
    CommissionSettlementDocumentType documentType,
  ) =>
      CommissionsService.peekCommissionSettlementReference(documentType);

  static Future<String> adminIssueCommissionSettlement({
    required String settlementId,
    required CommissionSettlementDocumentType documentType,
    String? invoiceReference,
  }) =>
      CommissionsService.adminIssueCommissionSettlement(
          settlementId: settlementId,
          documentType: documentType,
          invoiceReference: invoiceReference);

  static Future<void> importadorSubmitCommissionSettlementPago({
    required String settlementId,
    required Uint8List bytes,
    required String fileName,
  }) =>
      CommissionsService.importadorSubmitCommissionSettlementPago(
          settlementId: settlementId, bytes: bytes, fileName: fileName);

  static Future<void> adminApproveCommissionSettlementPago(
    String settlementId,
  ) =>
      CommissionsService.adminApproveCommissionSettlementPago(settlementId);

  static Future<void> adminRejectCommissionSettlementPago({
    required String settlementId,
    String? nota,
  }) =>
      CommissionsService.adminRejectCommissionSettlementPago(
          settlementId: settlementId, nota: nota);

  static Future<void> adminMarkCommissionSettlementPaid(String settlementId) =>
      CommissionsService.adminMarkCommissionSettlementPaid(settlementId);

  static Future<void> adminCancelCommissionSettlement(String settlementId) =>
      CommissionsService.adminCancelCommissionSettlement(settlementId);

  static Future<List<SupportTicketModel>> listMySupportTickets() =>
      SupportService.listMySupportTickets();

  static Future<List<SupportTicketModel>> listSupportTicketsForAdmin({
    bool openOnly = false,
  }) =>
      SupportService.listSupportTicketsForAdmin(openOnly: openOnly);

  static Future<SupportTicketModel?> fetchSupportTicketById(
    String ticketId,
  ) =>
      SupportService.fetchSupportTicketById(ticketId);

  static Future<int> countMyOpenSupportTickets() =>
      SupportService.countMyOpenSupportTickets();

  static Future<String> createSupportTicket({
    required String subject,
    required String category,
    required String body,
    String? relatedTransactionRequestId,
  }) =>
      SupportService.createSupportTicket(
          subject: subject,
          category: category,
          body: body,
          relatedTransactionRequestId: relatedTransactionRequestId);

  static Future<void> closeSupportTicket(String ticketId) =>
      SupportService.closeSupportTicket(ticketId);

  static Future<void> replySupportTicketAsOwner({
    required String ticketId,
    required String body,
  }) =>
      SupportService.replySupportTicketAsOwner(ticketId: ticketId, body: body);

  static Future<void> adminReplySupportTicket({
    required String ticketId,
    required String body,
  }) =>
      SupportService.adminReplySupportTicket(ticketId: ticketId, body: body);

  static Future<List<SupportTicketMessageModel>> fetchSupportTicketMessages(
    String ticketId,
  ) =>
      SupportService.fetchSupportTicketMessages(ticketId);

  static RealtimeChannel subscribeToSupportTicketMessages({
    required String ticketId,
    required void Function() onInsert,
  }) =>
      SupportService.subscribeToSupportTicketMessages(
          ticketId: ticketId, onInsert: onInsert);

  static Future<List<ImporterCarrierModel>> listMyImporterCarriers() =>
      LogisticsService.listMyImporterCarriers();

  static Future<List<ImporterCarrierModel>> listImporterCarriersForCheckout({
    required String importadorId,
    String? destEstado,
    String? destCiudad,
    double? destLatitude,
    double? destLongitude,
  }) =>
      LogisticsService.listImporterCarriersForCheckout(
          importadorId: importadorId,
          destEstado: destEstado,
          destCiudad: destCiudad,
          destLatitude: destLatitude,
          destLongitude: destLongitude);

  static Future<bool> importadorHasActiveCarriers(String importadorId) =>
      LogisticsService.importadorHasActiveCarriers(importadorId);

  static Future<List<ImporterCarrierModel>> listImporterCarriersForPedido(
    String requestId,
  ) =>
      LogisticsService.listImporterCarriersForPedido(requestId);

  static Future<void> aliadoSelectCarrierForPedido({
    required String requestId,
    required String carrierId,
    String? driverId,
    String? fletePagoModo,
  }) =>
      LogisticsService.aliadoSelectCarrierForPedido(
          requestId: requestId,
          carrierId: carrierId,
          driverId: driverId,
          fletePagoModo: fletePagoModo);

  static Future<void> aliadoSkipCarrierForPedido({
    required String requestId,
  }) =>
      LogisticsService.aliadoSkipCarrierForPedido(requestId: requestId);

  static Future<List<ImporterPickupLocationModel>>
      listMyImporterPickupLocations() =>
          LogisticsService.listMyImporterPickupLocations();

  static Future<String> upsertImporterPickupLocation({
    String? id,
    required String label,
    String? estado,
    String? ciudad,
    required String direccion,
    double? latitude,
    double? longitude,
    String? mapsUrl,
    String? contactName,
    String? contactPhone,
    bool isActive = true,
    bool isDefault = false,
    int sortOrder = 0,
  }) =>
      LogisticsService.upsertImporterPickupLocation(
          id: id,
          label: label,
          estado: estado,
          ciudad: ciudad,
          direccion: direccion,
          latitude: latitude,
          longitude: longitude,
          mapsUrl: mapsUrl,
          contactName: contactName,
          contactPhone: contactPhone,
          isActive: isActive,
          isDefault: isDefault,
          sortOrder: sortOrder);

  static Future<void> setImporterDefaultPickupPreferences({
    required String mode,
    String? pickupLocationId,
  }) =>
      LogisticsService.setImporterDefaultPickupPreferences(
          mode: mode, pickupLocationId: pickupLocationId);

  static Future<void> importerConfirmPickupLocation({
    required String requestId,
    required String mode,
    String? pickupLocationId,
  }) =>
      LogisticsService.importerConfirmPickupLocation(
          requestId: requestId, mode: mode, pickupLocationId: pickupLocationId);

  static Future<
      ({
        String? companyName,
        List<String> acceptedPagoMetodos,
        Map<String, String> pagoInstrucciones,
      })> fetchAliadoPedidoCarrierPagoInfo(
          String requestId) =>
      LogisticsService.fetchAliadoPedidoCarrierPagoInfo(requestId);

  static Future<void> importerSubmitFleteFactura({
    required String transactionRequestId,
    required Uint8List bytes,
    required String fileName,
  }) =>
      LogisticsService.importerSubmitFleteFactura(
          transactionRequestId: transactionRequestId,
          bytes: bytes,
          fileName: fileName);

  static Future<void> aliadoSubmitFleteComprobantePago({
    required String transactionRequestId,
    required String metodo,
    required Uint8List bytes,
    required String fileName,
  }) =>
      LogisticsService.aliadoSubmitFleteComprobantePago(
          transactionRequestId: transactionRequestId,
          metodo: metodo,
          bytes: bytes,
          fileName: fileName);

  static Future<void> importadorSetFletePagoRevisionEstado({
    required String transactionRequestId,
    required String nuevoEstado,
    String? rechazoNota,
  }) =>
      LogisticsService.importadorSetFletePagoRevisionEstado(
          transactionRequestId: transactionRequestId,
          nuevoEstado: nuevoEstado,
          rechazoNota: rechazoNota);

  static Future<String> createImporterCarrier({
    required String companyName,
    required String contactPhone,
    String? contactName,
    String? contactEmail,
    String? contactWhatsapp,
    List<String> coverageEstados = const [],
    List<String> coverageCiudades = const [],
    String? coverageNotes,
    String? baseEstado,
    String? baseCiudad,
    double? baseLatitude,
    double? baseLongitude,
    String? baseMapsUrl,
    List<String> acceptedPagoMetodos = const [],
    Map<String, String> pagoMetodoInstrucciones = const {},
    String fletePagoModo = CarrierFletePagoModo.incluidoFactura,
    double etaBaseHours = 24,
    double etaHoursPerKm = 0.15,
    double? maxCoverageKm,
    double? flatFeeUsd,
    double? pricePerKmUsd,
    String? notes,
    int sortOrder = 0,
  }) =>
      LogisticsService.createImporterCarrier(
          companyName: companyName,
          contactPhone: contactPhone,
          contactName: contactName,
          contactEmail: contactEmail,
          contactWhatsapp: contactWhatsapp,
          coverageEstados: coverageEstados,
          coverageCiudades: coverageCiudades,
          coverageNotes: coverageNotes,
          baseEstado: baseEstado,
          baseCiudad: baseCiudad,
          baseLatitude: baseLatitude,
          baseLongitude: baseLongitude,
          baseMapsUrl: baseMapsUrl,
          acceptedPagoMetodos: acceptedPagoMetodos,
          pagoMetodoInstrucciones: pagoMetodoInstrucciones,
          fletePagoModo: fletePagoModo,
          etaBaseHours: etaBaseHours,
          etaHoursPerKm: etaHoursPerKm,
          maxCoverageKm: maxCoverageKm,
          flatFeeUsd: flatFeeUsd,
          pricePerKmUsd: pricePerKmUsd,
          notes: notes,
          sortOrder: sortOrder);

  static Future<void> updateImporterCarrier({
    required String carrierId,
    required String companyName,
    required String contactPhone,
    String? contactName,
    String? contactEmail,
    String? contactWhatsapp,
    List<String> coverageEstados = const [],
    List<String> coverageCiudades = const [],
    String? coverageNotes,
    String? baseEstado,
    String? baseCiudad,
    double? baseLatitude,
    double? baseLongitude,
    String? baseMapsUrl,
    List<String> acceptedPagoMetodos = const [],
    Map<String, String> pagoMetodoInstrucciones = const {},
    String fletePagoModo = CarrierFletePagoModo.incluidoFactura,
    double etaBaseHours = 24,
    double etaHoursPerKm = 0.15,
    double? maxCoverageKm,
    double? flatFeeUsd,
    double? pricePerKmUsd,
    String? notes,
    bool isActive = true,
    int sortOrder = 0,
  }) =>
      LogisticsService.updateImporterCarrier(
          carrierId: carrierId,
          companyName: companyName,
          contactPhone: contactPhone,
          contactName: contactName,
          contactEmail: contactEmail,
          contactWhatsapp: contactWhatsapp,
          coverageEstados: coverageEstados,
          coverageCiudades: coverageCiudades,
          coverageNotes: coverageNotes,
          baseEstado: baseEstado,
          baseCiudad: baseCiudad,
          baseLatitude: baseLatitude,
          baseLongitude: baseLongitude,
          baseMapsUrl: baseMapsUrl,
          acceptedPagoMetodos: acceptedPagoMetodos,
          pagoMetodoInstrucciones: pagoMetodoInstrucciones,
          fletePagoModo: fletePagoModo,
          etaBaseHours: etaBaseHours,
          etaHoursPerKm: etaHoursPerKm,
          maxCoverageKm: maxCoverageKm,
          flatFeeUsd: flatFeeUsd,
          pricePerKmUsd: pricePerKmUsd,
          notes: notes,
          isActive: isActive,
          sortOrder: sortOrder);

  static Future<void> deleteImporterCarrier(String carrierId) =>
      LogisticsService.deleteImporterCarrier(carrierId);

  static Future<List<ImporterCarrierDriverModel>> listImporterCarrierDrivers(
    String carrierId,
  ) =>
      LogisticsService.listImporterCarrierDrivers(carrierId);

  static Future<String> createImporterCarrierDriver({
    required String carrierId,
    required String driverName,
    String? contactPhone,
    String? licenseId,
    String? notes,
    int sortOrder = 0,
  }) =>
      LogisticsService.createImporterCarrierDriver(
          carrierId: carrierId,
          driverName: driverName,
          contactPhone: contactPhone,
          licenseId: licenseId,
          notes: notes,
          sortOrder: sortOrder);

  static Future<void> updateImporterCarrierDriver({
    required String driverId,
    required String driverName,
    String? contactPhone,
    String? licenseId,
    String? notes,
    bool isActive = true,
    int sortOrder = 0,
  }) =>
      LogisticsService.updateImporterCarrierDriver(
          driverId: driverId,
          driverName: driverName,
          contactPhone: contactPhone,
          licenseId: licenseId,
          notes: notes,
          isActive: isActive,
          sortOrder: sortOrder);

  static Future<void> deleteImporterCarrierDriver(String driverId) =>
      LogisticsService.deleteImporterCarrierDriver(driverId);
}
