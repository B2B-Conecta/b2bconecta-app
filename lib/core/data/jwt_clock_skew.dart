import 'package:supabase_flutter/supabase_flutter.dart';

/// PostgREST rejects JWTs whose `iat` is > ~30s ahead of the API clock
/// (`PGRST303` / "JWT issued at future"). Auth and REST can drift briefly
/// after sign-in; waiting and retrying the **same** token usually works.
/// Do not refresh the session here — a new `iat` can make the skew worse.
const kJwtIssuedAtFutureRetryDelays = <Duration>[
  Duration(milliseconds: 800),
  Duration(milliseconds: 1500),
  Duration(milliseconds: 2500),
];

bool isJwtIssuedAtFutureError(Object error) {
  if (error is PostgrestException) {
    final code = error.code?.trim().toUpperCase();
    if (code == 'PGRST303') return true;
    if (_looksLikeIssuedAtFuture(error.message)) return true;
    if (_looksLikeIssuedAtFuture(error.details?.toString())) return true;
  }
  return _looksLikeIssuedAtFuture(error.toString());
}

bool _looksLikeIssuedAtFuture(String? raw) {
  if (raw == null || raw.isEmpty) return false;
  final t = raw.toLowerCase();
  return t.contains('jwt issued at future') || t.contains('pgrst303');
}

/// Runs [action]; on clock-skew JWT rejection waits and retries.
Future<T> retryOnJwtIssuedAtFuture<T>(
  Future<T> Function() action, {
  List<Duration> delays = kJwtIssuedAtFutureRetryDelays,
  Future<void> Function(Duration delay)? wait,
}) async {
  Object? lastSkewError;
  try {
    return await action();
  } catch (e) {
    if (!isJwtIssuedAtFutureError(e)) rethrow;
    lastSkewError = e;
  }

  for (final delay in delays) {
    if (wait != null) {
      await wait(delay);
    } else {
      await Future<void>.delayed(delay);
    }
    try {
      return await action();
    } catch (e) {
      if (!isJwtIssuedAtFutureError(e)) rethrow;
      lastSkewError = e;
    }
  }

  throw lastSkewError!;
}
