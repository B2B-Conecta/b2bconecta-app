
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:motolink_pro_app/core/data/supabase_access.dart';
import 'package:motolink_pro_app/features/support/support_ticket_message_model.dart';
import 'package:motolink_pro_app/features/support/support_ticket_model.dart';
import 'package:motolink_pro_app/features/support/support_ticket_status.dart';

class SupportService {
  SupportService._();

  static const _supportTicketsSelect =
      'id, created_by, author_role, subject, category, status, '
      'related_transaction_request_id, closed_by, closed_at, created_at, updated_at';

  static const _supportTicketsAdminSelect =
      '$_supportTicketsSelect, creator:profiles!support_tickets_created_by_fkey(business_name)';

  static const _supportTicketMessagesSelect =
      'id, ticket_id, author_id, author_role, body, created_at';

  static Future<List<SupportTicketModel>> listMySupportTickets() async {
    final uid = SupabaseAccess.currentUserId;
    if (uid == null) return [];

    final response = await SupabaseAccess.client
        .from('support_tickets')
        .select(_supportTicketsSelect)
        .eq('created_by', uid)
        .order('created_at', ascending: false);

    return _mapSupportTickets(response);
  }

  static Future<List<SupportTicketModel>> listSupportTicketsForAdmin({
    bool openOnly = false,
  }) async {
    var query = SupabaseAccess.client
        .from('support_tickets')
        .select(_supportTicketsAdminSelect);

    if (openOnly) {
      query = query.neq('status', SupportTicketStatus.cerrado);
    }

    final response = await query.order('created_at', ascending: false);
    return _mapSupportTickets(response);
  }

  static Future<SupportTicketModel?> fetchSupportTicketById(
    String ticketId,
  ) async {
    final id = ticketId.trim();
    if (id.isEmpty) return null;

    final response = await SupabaseAccess.client
        .from('support_tickets')
        .select(_supportTicketsAdminSelect)
        .eq('id', id)
        .maybeSingle();

    if (response == null) return null;
    return SupportTicketModel.fromJson(Map<String, dynamic>.from(response));
  }

  static List<SupportTicketModel> _mapSupportTickets(dynamic response) {
    final list = response as List<dynamic>;
    return list
        .map(
          (row) => SupportTicketModel.fromJson(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .where((t) => t.id.isNotEmpty)
        .toList();
  }

  static Future<int> countMyOpenSupportTickets() async {
    final uid = SupabaseAccess.currentUserId;
    if (uid == null) return 0;

    final response = await SupabaseAccess.client
        .from('support_tickets')
        .select('id')
        .eq('created_by', uid)
        .neq('status', SupportTicketStatus.cerrado);

    return (response as List<dynamic>).length;
  }

  static Future<String> createSupportTicket({
    required String subject,
    required String category,
    required String body,
    String? relatedTransactionRequestId,
  }) async {
    final params = <String, dynamic>{
      'p_subject': subject.trim(),
      'p_category': category.trim(),
      'p_body': body.trim(),
    };
    final related = relatedTransactionRequestId?.trim();
    if (related != null && related.isNotEmpty) {
      params['p_related_transaction_request_id'] = related;
    }

    final res = await SupabaseAccess.client
        .rpc('create_support_ticket', params: params);
    return res?.toString() ?? '';
  }

  static Future<void> closeSupportTicket(String ticketId) async {
    await SupabaseAccess.client.rpc(
      'close_support_ticket',
      params: <String, dynamic>{'p_ticket_id': ticketId.trim()},
    );
  }

  static Future<void> replySupportTicketAsOwner({
    required String ticketId,
    required String body,
  }) async {
    await SupabaseAccess.client.rpc(
      'reply_support_ticket_as_owner',
      params: <String, dynamic>{
        'p_ticket_id': ticketId.trim(),
        'p_body': body.trim(),
      },
    );
  }

  static Future<void> adminReplySupportTicket({
    required String ticketId,
    required String body,
  }) async {
    await SupabaseAccess.client.rpc(
      'admin_reply_support_ticket',
      params: <String, dynamic>{
        'p_ticket_id': ticketId.trim(),
        'p_body': body.trim(),
      },
    );
  }

  static Future<List<SupportTicketMessageModel>> fetchSupportTicketMessages(
    String ticketId,
  ) async {
    final id = ticketId.trim();
    if (id.isEmpty) return [];

    final response = await SupabaseAccess.client
        .from('support_ticket_messages')
        .select(_supportTicketMessagesSelect)
        .eq('ticket_id', id)
        .order('created_at', ascending: true);

    final list = response as List<dynamic>;
    return list
        .map(
          (row) => SupportTicketMessageModel.fromJson(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList();
  }

  static RealtimeChannel subscribeToSupportTicketMessages({
    required String ticketId,
    required void Function() onInsert,
  }) {
    final id = ticketId.trim();
    return SupabaseAccess.client
        .channel('support_ticket_messages:$id')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'support_ticket_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'ticket_id',
            value: id,
          ),
          callback: (_) => onInsert(),
        )
        .subscribe();
  }

  // ---------------------------------------------------------------------------
  // Logística: transportistas del importador
  // ---------------------------------------------------------------------------
}
