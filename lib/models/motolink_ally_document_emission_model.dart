import 'document_type_preference.dart';

/// Fila de `motolink_ally_document_emissions` (factura / nota MotoLink al aliado).
class MotolinkAllyDocumentEmissionModel {
  const MotolinkAllyDocumentEmissionModel({
    required this.id,
    required this.correlativo,
    required this.documentType,
    this.storagePath,
    this.fileName,
    this.finalizedAt,
    this.fragmentIndex = 1,
    this.fragmentTotal = 1,
  });

  final String id;
  final int correlativo;
  final String documentType;
  final String? storagePath;
  final String? fileName;
  final DateTime? finalizedAt;
  final int fragmentIndex;
  final int fragmentTotal;

  bool get hasStorage =>
      storagePath != null && storagePath!.trim().isNotEmpty;

  bool get isFinalized =>
      finalizedAt != null && hasStorage;

  /// Código breve del tipo (NE / FF) para etiquetas de botón.
  String get shortDocumentTypeCode {
    final t = documentType.trim();
    if (t == DocumentTypePreference.notaEntrega) return 'NE';
    if (t == DocumentTypePreference.facturaFiscal) return 'FF';
    if (t.isEmpty) return 'DOC';
    return t.length <= 6 ? t.toUpperCase() : t.substring(0, 6).toUpperCase();
  }

  /// Texto para botones de descarga (p. ej. «MotoLink FF-000042 · 2/3»).
  String get downloadButtonLabel {
    final corr = correlativo.toString().padLeft(6, '0');
    final base = 'MotoLink $shortDocumentTypeCode-$corr';
    if (fragmentTotal > 1) {
      return '$base · $fragmentIndex/$fragmentTotal';
    }
    final fn = fileName?.trim();
    if (fn != null && fn.isNotEmpty) return fn;
    return base;
  }

  static MotolinkAllyDocumentEmissionModel? tryFromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final id = json['id']?.toString();
    if (id == null || id.isEmpty) return null;
    return MotolinkAllyDocumentEmissionModel(
      id: id,
      correlativo: _asInt(json['correlativo']),
      documentType: json['document_type']?.toString() ?? '',
      storagePath: _nullableText(json['storage_path']),
      fileName: _nullableText(json['file_name']),
      finalizedAt: _parseDate(json['finalized_at']),
      fragmentIndex: _asInt(json['fragment_index'], fallback: 1),
      fragmentTotal: _asInt(json['fragment_total'], fallback: 1),
    );
  }

  static List<MotolinkAllyDocumentEmissionModel> listFromJson(dynamic v) {
    if (v is! List) return const [];
    final out = <MotolinkAllyDocumentEmissionModel>[];
    for (final e in v) {
      if (e is! Map) continue;
      final m = tryFromJson(Map<String, dynamic>.from(e));
      if (m != null) out.add(m);
    }
    out.sort((a, b) {
      final c = a.fragmentIndex.compareTo(b.fragmentIndex);
      if (c != 0) return c;
      return a.correlativo.compareTo(b.correlativo);
    });
    return out;
  }

  static String? _nullableText(dynamic v) {
    final s = v?.toString().trim();
    if (s == null || s.isEmpty) return null;
    return s;
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    return DateTime.tryParse(v.toString());
  }

  static int _asInt(dynamic v, {int fallback = 0}) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? fallback;
  }
}
