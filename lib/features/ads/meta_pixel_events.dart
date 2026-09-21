/// Eventos estándar de Meta (Pixel web + App Events Android).
abstract final class MetaPixelEvents {
  static const completeRegistration = 'CompleteRegistration';
  static const submitApplication = 'SubmitApplication';
  static const registrationStarted = 'RegistrationStarted';
  static const purchase = 'Purchase';

  static String dedupeKey(String event, String? identity) {
    final id = (identity ?? '').trim().toLowerCase();
    return 'b2b_pixel_$event:${id.isEmpty ? '_' : id}';
  }

  /// Mismo `event_id` en app y servidor para no duplicar (Conversions API).
  static String eventId(String event, String? identity) {
    final id = (identity ?? '').trim().toLowerCase();
    final safe = id.isEmpty ? '_' : id.replaceAll(RegExp(r'[^a-z0-9._-]'), '_');
    return 'b2b_${event.toLowerCase()}_$safe';
  }
}
