

import 'package:motolink_pro_app/core/data/supabase_access.dart';
import 'package:motolink_pro_app/features/reputation/admin_order_rating_row_model.dart';
import 'package:motolink_pro_app/features/reputation/aliado_received_rating_model.dart';
import 'package:motolink_pro_app/features/reputation/importador_received_rating_model.dart';
import 'package:motolink_pro_app/features/reputation/reputation_weekly_snapshot_model.dart';
import 'package:motolink_pro_app/features/reputation/rating_questionnaire_model.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_model.dart';

class ReputationService {
  ReputationService._();

  static Future<void> aliadoSubmitOrderExperienceImportadorGrupo({
    required String checkoutGroupId,
    required String importadorId,
    required int stars,
    required String comment,
    Map<String, dynamic> answers = const {},
  }) async {
    await SupabaseAccess.client.rpc(
      'aliado_submit_order_experience_importador_grupo',
      params: <String, dynamic>{
        'p_checkout_group_id': checkoutGroupId,
        'p_importador_id': importadorId,
        'p_stars': stars,
        'p_comment': comment.trim(),
        'p_answers': answers,
      },
    );
  }

  /// A6: nota de entrega vs factura fiscal (una sola vez; vía RPC).
  static Future<void> aliadoSetDocumentTypePreference({
    required String transactionRequestId,
    required String documentType,
  }) async {
    await SupabaseAccess.client.rpc(
      'aliado_set_document_type_preference',
      params: <String, dynamic>{
        'p_request_id': transactionRequestId,
        'p_type': documentType,
      },
    );
  }

  /// A6: calificación y comentario breve tras entrega (una sola vez).
  static Future<void> aliadoSubmitOrderExperience({
    required String transactionRequestId,
    required int stars,
    required String comment,
    Map<String, dynamic> answers = const {},
  }) async {
    await SupabaseAccess.client.rpc(
      'aliado_submit_order_experience',
      params: <String, dynamic>{
        'p_request_id': transactionRequestId,
        'p_stars': stars,
        'p_comment': comment.trim(),
        'p_answers': answers,
      },
    );
  }

  /// C4: cuestionario Bucket List (audiencia: aliado_rates_importer | importer_rates_aliado).
  static Future<RatingQuestionnaireModel> fetchRatingQuestionnaire({
    required String audience,
  }) async {
    final res = await SupabaseAccess.client.rpc(
      'get_rating_questionnaire',
      params: <String, dynamic>{'p_audience': audience},
    );
    if (res is Map) {
      return RatingQuestionnaireModel.fromJson(Map<String, dynamic>.from(res));
    }
    return const RatingQuestionnaireModel(version: 'bucket_v1', questions: []);
  }

  static Future<List<ReputationWeeklySnapshotModel>>
      listMyReputationWeeklySnapshots({
    int limit = 12,
  }) async {
    final res = await SupabaseAccess.client.rpc(
      'list_my_reputation_weekly_snapshots',
      params: <String, dynamic>{'p_limit': limit},
    );
    if (res is! List) return const [];
    return res
        .map((e) => ReputationWeeklySnapshotModel.fromJson(
              Map<String, dynamic>.from(e as Map),
            ))
        .toList();
  }

  /// C4: valoraciones recibidas por el aliado (importador anónimo en etiqueta).
  static Future<List<AliadoReceivedRatingModel>> listAliadoReceivedRatings({
    int limit = 30,
    int offset = 0,
  }) async {
    final res = await SupabaseAccess.client.rpc(
      'list_aliado_received_ratings',
      params: <String, dynamic>{
        'p_limit': limit,
        'p_offset': offset,
      },
    );
    if (res is! List) return const [];
    return res
        .map((e) => AliadoReceivedRatingModel.fromJson(
              Map<String, dynamic>.from(e as Map),
            ))
        .toList();
  }

  /// C4: valoraciones recibidas por el importador (aliado anónimo en etiqueta).
  static Future<List<ImportadorReceivedRatingModel>>
      listImportadorReceivedRatings({
    int limit = 30,
    int offset = 0,
  }) async {
    final res = await SupabaseAccess.client.rpc(
      'list_importador_received_ratings',
      params: <String, dynamic>{
        'p_limit': limit,
        'p_offset': offset,
      },
    );
    if (res is! List) return const [];
    return res
        .map((e) => ImportadorReceivedRatingModel.fromJson(
              Map<String, dynamic>.from(e as Map),
            ))
        .toList();
  }

  static Future<List<AdminOrderRatingRowModel>> listAdminOrderRatings({
    String? importadorId,
    String? aliadoId,
    int limit = 50,
    int offset = 0,
    bool? commentHidden,
  }) async {
    final res = await SupabaseAccess.client.rpc(
      'list_admin_order_ratings',
      params: <String, dynamic>{
        'p_importador_id': SupabaseAccess.nullableUuid(importadorId),
        'p_aliado_id': SupabaseAccess.nullableUuid(aliadoId),
        'p_limit': limit,
        'p_offset': offset,
        'p_comment_hidden': commentHidden,
      },
    );
    if (res is! List) return const [];
    return res
        .map((e) => AdminOrderRatingRowModel.fromJson(
              Map<String, dynamic>.from(e as Map),
            ))
        .toList();
  }

  /// Moderación v1: ocultar o restaurar el comentario de texto de una valoración.
  static Future<void> adminSetOrderRatingCommentHidden({
    required String ratingId,
    required bool hidden,
    String? reason,
  }) async {
    final id = ratingId.trim();
    if (id.isEmpty) {
      throw ArgumentError('Valoración requerida');
    }
    await SupabaseAccess.client.rpc(
      'admin_set_order_rating_comment_hidden',
      params: <String, dynamic>{
        'p_rating_id': id,
        'p_hidden': hidden,
        'p_reason': reason?.trim().isEmpty == true ? null : reason?.trim(),
      },
    );
  }

  /// Admin registra valoración en nombre del usuario (solo si aún no calificó).
  static Future<void> adminSubmitOrderRating({
    required String raterRole,
    required String transactionRequestId,
    required int stars,
    required String comment,
    Map<String, dynamic> answers = const {},
  }) async {
    final role = raterRole.trim().toLowerCase();
    final id = transactionRequestId.trim();
    if (role != 'aliado' && role != 'importador') {
      throw ArgumentError('Rol de valoración inválido');
    }
    if (id.isEmpty) {
      throw ArgumentError('Pedido requerido');
    }
    await SupabaseAccess.client.rpc(
      'admin_submit_order_rating',
      params: <String, dynamic>{
        'p_rater_role': role,
        'p_request_id': id,
        'p_stars': stars,
        'p_comment': comment.trim(),
        'p_answers': answers,
      },
    );
  }

  /// C4: respuestas Bucket del aliado (RLS) para mostrar en «valoración registrada».
  static Future<Map<String, dynamic>?> fetchAliadoOrderRatingAnswers({
    required String transactionRequestId,
    String? checkoutGroupId,
    String? importadorId,
  }) async {
    final tr = transactionRequestId.trim();
    if (tr.isEmpty) return null;

    dynamic q = SupabaseAccess.client
        .from('order_ratings')
        .select('answers')
        .eq('rater_role', 'aliado')
        .eq('transaction_request_id', tr);
    final row1 = await q.maybeSingle();
    final a1 = _answersFromRow(row1);
    if (a1 != null) return a1;

    final cg = checkoutGroupId?.trim();
    final imp = importadorId?.trim();
    if (cg != null && cg.isNotEmpty && imp != null && imp.isNotEmpty) {
      final row2 = await SupabaseAccess.client
          .from('order_ratings')
          .select('answers')
          .eq('rater_role', 'aliado')
          .eq('checkout_group_id', cg)
          .eq('importador_id', imp)
          .maybeSingle();
      return _answersFromRow(row2);
    }
    return null;
  }

  static Map<String, dynamic>? _answersFromRow(dynamic row) {
    if (row is! Map) return null;
    final m = Map<String, dynamic>.from(row);
    final raw = m['answers'];
    if (raw is! Map || raw.isEmpty) return null;
    return Map<String, dynamic>.from(raw);
  }

  /// Texto compacto de `answers` para Excel (clave ordenadas `k:v; …`).
  static String formatOrderRatingAnswersForExportCell(
      Map<String, dynamic> raw) {
    if (raw.isEmpty) return '';
    final keys = raw.keys.map((e) => e.toString()).toList()..sort();
    final parts = <String>[];
    for (final k in keys) {
      parts.add('$k:${raw[k]}');
    }
    return parts.join('; ');
  }

  /// C4: mapa `transaction_request.id` → resumen de respuestas Bucket (export encomiendas).
  static Future<Map<String, String>>
      fetchAliadoOrderRatingAnswerSummariesForExport(
    List<TransactionRequestModel> rows,
  ) async {
    final out = <String, String>{};
    if (rows.isEmpty) return out;

    const chunk = 120;
    final rated =
        rows.where((r) => r.aliadoExperienceSubmittedAt != null).toList();
    if (rated.isEmpty) return out;

    for (var i = 0; i < rated.length; i += chunk) {
      final slice = rated.sublist(
        i,
        i + chunk > rated.length ? rated.length : i + chunk,
      );
      final ids = slice.map((r) => r.id).where((e) => e.isNotEmpty).toList();
      if (ids.isEmpty) continue;

      final res = await SupabaseAccess.client
          .from('order_ratings')
          .select(
            'transaction_request_id, checkout_group_id, importador_id, aliado_id, answers',
          )
          .eq('rater_role', 'aliado')
          .inFilter('transaction_request_id', ids);

      for (final e in res as List<dynamic>) {
        if (e is! Map) continue;
        final m = Map<String, dynamic>.from(e);
        final tid = m['transaction_request_id']?.toString();
        if (tid == null || tid.isEmpty) continue;
        final cell = formatOrderRatingAnswersForExportCell(
          m['answers'] is Map
              ? Map<String, dynamic>.from(m['answers'] as Map)
              : const {},
        );
        if (cell.isNotEmpty) out[tid] = cell;
      }
    }

    final stillMissing = rated
        .where(
          (r) =>
              r.checkoutGroupId != null &&
              r.checkoutGroupId!.trim().isNotEmpty &&
              !out.containsKey(r.id),
        )
        .toList();
    if (stillMissing.isEmpty) return out;

    final cgs =
        stillMissing.map((r) => r.checkoutGroupId!.trim()).toSet().toList();

    for (var i = 0; i < cgs.length; i += chunk) {
      final cgSlice = cgs.sublist(
        i,
        i + chunk > cgs.length ? cgs.length : i + chunk,
      );
      final res2 = await SupabaseAccess.client
          .from('order_ratings')
          .select(
            'transaction_request_id, checkout_group_id, importador_id, aliado_id, answers',
          )
          .eq('rater_role', 'aliado')
          .inFilter('checkout_group_id', cgSlice);

      for (final e in res2 as List<dynamic>) {
        if (e is! Map) continue;
        final m = Map<String, dynamic>.from(e);
        final cg = (m['checkout_group_id']?.toString() ?? '').trim();
        final imp = (m['importador_id']?.toString() ?? '').trim();
        final al = (m['aliado_id']?.toString() ?? '').trim();
        if (cg.isEmpty || imp.isEmpty || al.isEmpty) {
          continue;
        }
        final cell = formatOrderRatingAnswersForExportCell(
          m['answers'] is Map
              ? Map<String, dynamic>.from(m['answers'] as Map)
              : const {},
        );
        if (cell.isEmpty) continue;
        for (final r in stillMissing) {
          if (out.containsKey(r.id)) continue;
          final rcg = r.checkoutGroupId?.trim();
          if (rcg != cg) continue;
          if (r.ownerId.trim() != imp) continue;
          if (r.aliadoId.trim() != al) continue;
          out[r.id] = cell;
        }
      }
    }

    return out;
  }

  static Future<void> importerSubmitOrderRating({
    required String transactionRequestId,
    required int stars,
    required String comment,
    Map<String, dynamic> answers = const {},
  }) async {
    await SupabaseAccess.client.rpc(
      'importer_submit_order_rating',
      params: <String, dynamic>{
        'p_request_id': transactionRequestId,
        'p_stars': stars,
        'p_comment': comment.trim(),
        'p_answers': answers,
      },
    );
  }

  static Future<void> importerSubmitOrderRatingGrupo({
    required String checkoutGroupId,
    required String aliadoId,
    required int stars,
    required String comment,
    Map<String, dynamic> answers = const {},
  }) async {
    await SupabaseAccess.client.rpc(
      'importer_submit_order_rating_importador_grupo',
      params: <String, dynamic>{
        'p_checkout_group_id': checkoutGroupId,
        'p_aliado_id': aliadoId,
        'p_stars': stars,
        'p_comment': comment.trim(),
        'p_answers': answers,
      },
    );
  }

  /// True si el importador ya envió valoración mutua para este par en el carrito/línea.
  static Future<bool> importerHasRatedAliado({
    String? checkoutGroupId,
    String? transactionRequestId,
    required String aliadoId,
  }) async {
    final uid = SupabaseAccess.currentUserId;
    if (uid == null) return false;
    return orderRatingExistsForRater(
      raterRole: 'importador',
      importadorId: uid,
      aliadoId: aliadoId,
      checkoutGroupId: checkoutGroupId,
      transactionRequestId: transactionRequestId,
    );
  }

  /// Comprueba si ya hay valoración de [raterRole] para el par en carrito/línea.
  static Future<bool> orderRatingExistsForRater({
    required String raterRole,
    required String importadorId,
    required String aliadoId,
    String? checkoutGroupId,
    String? transactionRequestId,
  }) async {
    final role = raterRole.trim().toLowerCase();
    final imp = importadorId.trim();
    final ali = aliadoId.trim();
    if (imp.isEmpty || ali.isEmpty) return false;
    final cg = checkoutGroupId?.trim();
    dynamic q = SupabaseAccess.client
        .from('order_ratings')
        .select('id')
        .eq('rater_role', role)
        .eq('importador_id', imp)
        .eq('aliado_id', ali);
    if (cg != null && cg.isNotEmpty) {
      q = q.eq('checkout_group_id', cg);
    } else if (transactionRequestId != null &&
        transactionRequestId.trim().isNotEmpty) {
      q = q.eq('transaction_request_id', transactionRequestId.trim());
    } else {
      return false;
    }
    final row = await q.maybeSingle();
    return row != null;
  }

  /// Avanza el estado del pedido (importador): pendiente → preparación → listo para despacho.
}
