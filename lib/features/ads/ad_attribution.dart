/// Parámetros de anuncio (UTM + fbclid) capturados del enlace de landing.
class AdAttribution {
  const AdAttribution({
    this.utmSource,
    this.utmMedium,
    this.utmCampaign,
    this.utmContent,
    this.utmTerm,
    this.fbclid,
  });

  static const maxLen = 512;

  final String? utmSource;
  final String? utmMedium;
  final String? utmCampaign;
  final String? utmContent;
  final String? utmTerm;
  final String? fbclid;

  bool get isEmpty =>
      utmSource == null &&
      utmMedium == null &&
      utmCampaign == null &&
      utmContent == null &&
      utmTerm == null &&
      fbclid == null;

  Map<String, String> toProfileColumns() {
    return {
      if (utmSource != null) 'utm_source': utmSource!,
      if (utmMedium != null) 'utm_medium': utmMedium!,
      if (utmCampaign != null) 'utm_campaign': utmCampaign!,
      if (utmContent != null) 'utm_content': utmContent!,
      if (utmTerm != null) 'utm_term': utmTerm!,
      if (fbclid != null) 'fbclid': fbclid!,
    };
  }

  Map<String, String> toJson() => toProfileColumns();

  factory AdAttribution.fromJson(Map<String, dynamic> json) {
    return AdAttribution(
      utmSource: clean(json['utm_source']?.toString()),
      utmMedium: clean(json['utm_medium']?.toString()),
      utmCampaign: clean(json['utm_campaign']?.toString()),
      utmContent: clean(json['utm_content']?.toString()),
      utmTerm: clean(json['utm_term']?.toString()),
      fbclid: clean(json['fbclid']?.toString()),
    );
  }

  factory AdAttribution.fromUri(Uri uri) {
    final q = Map<String, String>.from(uri.queryParameters);
    final frag = uri.fragment.trim();
    if (frag.contains('utm_') || frag.contains('fbclid=')) {
      final fake = Uri.tryParse(
        'https://x/?${frag.contains('?') ? frag.split('?').last : frag}',
      );
      fake?.queryParameters.forEach((k, v) {
        q.putIfAbsent(k, () => v);
      });
    }
    return AdAttribution(
      utmSource: clean(q['utm_source']),
      utmMedium: clean(q['utm_medium']),
      utmCampaign: clean(q['utm_campaign']),
      utmContent: clean(q['utm_content']),
      utmTerm: clean(q['utm_term']),
      fbclid: clean(q['fbclid']),
    );
  }

  /// First-touch: si [existing] ya tiene datos, se conserva.
  static AdAttribution firstTouch(AdAttribution? existing, AdAttribution incoming) {
    if (existing != null && !existing.isEmpty) return existing;
    return incoming;
  }

  static String? clean(String? raw) {
    var t = raw?.trim() ?? '';
    if (t.isEmpty) return null;
    t = t.replaceAll(RegExp(r'[\u0000-\u001F\u007F]'), '');
    if (t.isEmpty) return null;
    if (t.length > maxLen) t = t.substring(0, maxLen);
    return t;
  }
}
