/// Eventos estándar de Meta Pixel (paso 4).
abstract final class MetaPixelEvents {
  static const completeRegistration = 'CompleteRegistration';
  static const submitApplication = 'SubmitApplication';

  static String dedupeKey(String event, String? identity) {
    final id = (identity ?? '').trim().toLowerCase();
    return 'b2b_pixel_$event:${id.isEmpty ? '_' : id}';
  }
}
