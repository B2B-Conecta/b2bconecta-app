import 'transaction_request_model.dart';
import 'transaction_request_status.dart';

/// Fecha de cierre (entregado / rechazado) o etiqueta «Pedido activo» para importador.
abstract final class ImporterOrderDate {
  ImporterOrderDate._();

  static bool isAbierto(TransactionRequestModel r) {
    return r.status != TransactionRequestStatus.entregado &&
        r.status != TransactionRequestStatus.rechazado;
  }

  static DateTime? fechaCierre(TransactionRequestModel r) {
    if (r.status == TransactionRequestStatus.entregado) {
      return r.atEntregado ?? r.updatedAt ?? r.createdAt;
    }
    if (r.status == TransactionRequestStatus.rechazado) {
      return r.atRechazado ?? r.updatedAt ?? r.createdAt;
    }
    return null;
  }

  /// Día usado en filtros: cierre si cerrado; `created_at` si activo.
  static DateTime? fechaParaFiltro(TransactionRequestModel r) {
    return fechaCierre(r) ?? r.createdAt;
  }

  static String etiquetaFecha(TransactionRequestModel r) {
    if (isAbierto(r)) return 'Pedido activo';
    final d = fechaCierre(r);
    if (d == null) return '—';
    return formatFechaPedido(d);
  }

  static String etiquetaGrupo(List<TransactionRequestModel> lines) {
    if (lines.isEmpty) return '—';
    if (lines.any(isAbierto)) return 'Pedido activo';
    DateTime? best;
    for (final r in lines) {
      final d = fechaCierre(r);
      if (d == null) continue;
      if (best == null || d.isAfter(best)) best = d;
    }
    if (best == null) return '—';
    return formatFechaPedido(best);
  }

  static DateTime? fechaGrupoParaFiltro(List<TransactionRequestModel> lines) {
    if (lines.isEmpty) return null;
    if (lines.any(isAbierto)) {
      DateTime? newest;
      for (final r in lines) {
        final d = r.createdAt;
        if (d == null) continue;
        if (newest == null || d.isAfter(newest)) newest = d;
      }
      return newest;
    }
    DateTime? best;
    for (final r in lines) {
      final d = fechaCierre(r);
      if (d == null) continue;
      if (best == null || d.isAfter(best)) best = d;
    }
    return best;
  }

  static String formatFechaPedido(DateTime d) {
    final local = d.toLocal();
    final dd = local.day.toString().padLeft(2, '0');
    final mm = local.month.toString().padLeft(2, '0');
    return '$dd/$mm/${local.year}';
  }

  static DateTime dateOnly(DateTime d) {
    final local = d.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  static bool matchesDateRange(
    TransactionRequestModel r, {
    DateTime? dateFrom,
    DateTime? dateTo,
  }) {
    if (dateFrom == null && dateTo == null) return true;
    final ref = fechaParaFiltro(r);
    if (ref == null) return false;
    final day = dateOnly(ref);
    if (dateFrom != null && day.isBefore(dateOnly(dateFrom))) return false;
    if (dateTo != null && day.isAfter(dateOnly(dateTo))) return false;
    return true;
  }

  static bool grupoMatchesDateRange(
    List<TransactionRequestModel> lines, {
    DateTime? dateFrom,
    DateTime? dateTo,
  }) {
    if (dateFrom == null && dateTo == null) return true;
    return lines.any(
      (r) => matchesDateRange(r, dateFrom: dateFrom, dateTo: dateTo),
    );
  }

  static int compareByFechaReciente(
    TransactionRequestModel a,
    TransactionRequestModel b,
  ) {
    final da = fechaParaFiltro(a);
    final db = fechaParaFiltro(b);
    if (da == null && db == null) return 0;
    if (da == null) return 1;
    if (db == null) return -1;
    final cmp = db.compareTo(da);
    if (cmp != 0) return cmp;
    return b.id.compareTo(a.id);
  }
}
