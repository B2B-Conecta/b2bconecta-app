import '../../core/data/supabase_access.dart';

Future<DateTime?> openMyInductionWindow() async {
  final value = await SupabaseAccess.client.rpc('open_my_induction_window');
  return value is String ? DateTime.tryParse(value) : null;
}

bool isInductionWindowOpen(DateTime? endsAt) =>
    endsAt != null && DateTime.now().isBefore(endsAt);
