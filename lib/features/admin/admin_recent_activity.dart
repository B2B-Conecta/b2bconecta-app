import 'dart:async';

import 'package:flutter/material.dart';

import 'package:motolink_pro_app/core/data/supabase_access.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';
import 'package:motolink_pro_app/features/kyc/account_access_status.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_status.dart';

/// Tipo de evento en el feed de actividad reciente del dashboard.
enum RecentActivityKind {
  orderCreated,
  orderUpdated,
  accountRegistered,
  accountPendingReview,
}

/// Ítem del feed «Actividad reciente».
@immutable
class RecentActivityItem {
  const RecentActivityItem({
    required this.id,
    required this.kind,
    required this.actorName,
    required this.description,
    required this.at,
    this.logoStoragePath,
    this.actorRole,
  });

  final String id;
  final RecentActivityKind kind;
  final String actorName;
  final String description;
  final DateTime at;
  final String? logoStoragePath;
  final String? actorRole;

  LucideGlyph get kindGlyph => switch (kind) {
        RecentActivityKind.orderCreated => LucideGlyph.package,
        RecentActivityKind.orderUpdated => LucideGlyph.refreshCw,
        RecentActivityKind.accountRegistered => LucideGlyph.userRound,
        RecentActivityKind.accountPendingReview => LucideGlyph.shieldCheck,
      };

  Color get kindAccent => switch (kind) {
        RecentActivityKind.orderCreated => const Color(0xFF2563EB),
        RecentActivityKind.orderUpdated => const Color(0xFF7C3AED),
        RecentActivityKind.accountRegistered => const Color(0xFF16A34A),
        RecentActivityKind.accountPendingReview => const Color(0xFFD97706),
      };

  String get initials {
    final parts = actorName
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final s = parts.first;
      return s.substring(0, s.length < 2 ? s.length : 2).toUpperCase();
    }
    return ('${parts.first[0]}${parts[1][0]}').toUpperCase();
  }
}

/// Snapshot de las últimas acciones del panel.
@immutable
class AdminRecentActivitySnapshot {
  const AdminRecentActivitySnapshot({
    required this.items,
    this.isFallback = false,
  });

  final List<RecentActivityItem> items;
  final bool isFallback;

  bool get isEmpty => items.isEmpty;

  static const empty = AdminRecentActivitySnapshot(items: []);

  static AdminRecentActivitySnapshot structuredFallback({DateTime? now}) {
    final t = now ?? DateTime.now();
    return AdminRecentActivitySnapshot(
      isFallback: true,
      items: [
        RecentActivityItem(
          id: 'fb-1',
          kind: RecentActivityKind.orderCreated,
          actorName: 'Taller Moto Ruices',
          description: 'creó un nuevo pedido (#A1B2C3D4)',
          at: t.subtract(const Duration(minutes: 2)),
        ),
        RecentActivityItem(
          id: 'fb-2',
          kind: RecentActivityKind.orderUpdated,
          actorName: 'Importadora Valencia',
          description: 'actualizó el inventario de frenos',
          at: t.subtract(const Duration(minutes: 15)),
        ),
        RecentActivityItem(
          id: 'fb-3',
          kind: RecentActivityKind.accountRegistered,
          actorName: 'Taller El Rayo',
          description: 'registró una nueva cuenta de taller',
          at: t.subtract(const Duration(hours: 1)),
        ),
        RecentActivityItem(
          id: 'fb-4',
          kind: RecentActivityKind.orderUpdated,
          actorName: 'Repuestos del Centro',
          description: 'marcó el pedido (#9F8E7D6C) como entregado',
          at: t.subtract(const Duration(hours: 2)),
        ),
        RecentActivityItem(
          id: 'fb-5',
          kind: RecentActivityKind.accountPendingReview,
          actorName: 'Mayorista Andes Parts',
          description: 'envió documentos para verificación',
          at: t.subtract(const Duration(hours: 3)),
        ),
        RecentActivityItem(
          id: 'fb-6',
          kind: RecentActivityKind.orderCreated,
          actorName: 'Motos La Guaira',
          description: 'creó un nuevo pedido (#11223344)',
          at: t.subtract(const Duration(hours: 5)),
        ),
        RecentActivityItem(
          id: 'fb-7',
          kind: RecentActivityKind.orderUpdated,
          actorName: 'Importadora Caribe',
          description: 'puso el pedido (#55667788) en tránsito',
          at: t.subtract(const Duration(hours: 8)),
        ),
        RecentActivityItem(
          id: 'fb-8',
          kind: RecentActivityKind.accountRegistered,
          actorName: 'Taller Norte 2000',
          description: 'registró una nueva cuenta de taller',
          at: t.subtract(const Duration(days: 1)),
        ),
      ],
    );
  }
}

/// Carga y fusiona pedidos + altas de cuenta para el feed del dashboard.
class AdminRecentActivity extends ChangeNotifier {
  AdminRecentActivity({AdminRecentActivitySnapshot? seed})
      : _snapshot = seed ?? AdminRecentActivitySnapshot.empty;

  AdminRecentActivitySnapshot _snapshot;
  bool _loading = false;
  bool _started = false;
  bool _disposed = false;
  Timer? _poll;

  AdminRecentActivitySnapshot get snapshot => _snapshot;
  bool get loading => _loading;

  @visibleForTesting
  void applySnapshot(
    AdminRecentActivitySnapshot snapshot, {
    bool loading = false,
  }) {
    _snapshot = snapshot;
    _loading = loading;
    notifyListeners();
  }

  Future<void> start() async {
    if (_started || _disposed) return;
    _started = true;
    await refresh();
    if (_disposed) return;
    _poll = Timer.periodic(const Duration(seconds: 45), (_) {
      unawaited(refresh());
    });
  }

  Future<void> refresh({
    int orderLimit = 16,
    int profileLimit = 12,
    int take = 8,
  }) async {
    if (_loading || _disposed) return;
    _loading = true;
    notifyListeners();
    try {
      final results = await Future.wait([
        _fetchRecentOrders(limit: orderLimit),
        _fetchRecentProfiles(limit: profileLimit),
      ]);
      if (_disposed) return;
      final merged = <RecentActivityItem>[
        ...results[0],
        ...results[1],
      ]..sort((a, b) => b.at.compareTo(a.at));
      final top = merged.take(take.clamp(1, 500)).toList();
      if (top.isEmpty) {
        _snapshot = AdminRecentActivitySnapshot.structuredFallback();
      } else {
        _snapshot = AdminRecentActivitySnapshot(items: top);
      }
    } catch (_) {
      if (_disposed) return;
      if (_snapshot.isEmpty || _snapshot.isFallback) {
        _snapshot = AdminRecentActivitySnapshot.structuredFallback();
      }
    } finally {
      if (!_disposed) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  static Future<List<RecentActivityItem>> _fetchRecentOrders({
    int limit = 16,
  }) async {
    const select = '''
id, status, created_at, updated_at, checkout_group_id,
aliado:profiles!transaction_requests_aliado_id_fkey ( business_name, logo_storage_path, role ),
importador:profiles!transaction_requests_importador_id_fkey ( business_name, logo_storage_path, role )
''';
    final raw = await SupabaseAccess.client
        .from('transaction_requests')
        .select(select)
        .order('updated_at', ascending: false)
        .limit(limit.clamp(1, 200));
    final list = raw as List<dynamic>;
    final items = <RecentActivityItem>[];
    for (final row in list) {
      final map = Map<String, dynamic>.from(row as Map);
      final id = map['id']?.toString() ?? '';
      if (id.isEmpty) continue;
      final status = map['status']?.toString() ?? '';
      final created = DateTime.tryParse(map['created_at']?.toString() ?? '');
      final updated = DateTime.tryParse(map['updated_at']?.toString() ?? '');
      final at = updated ?? created;
      if (at == null) continue;

      final aliado = map['aliado'] is Map
          ? Map<String, dynamic>.from(map['aliado'] as Map)
          : null;
      final importador = map['importador'] is Map
          ? Map<String, dynamic>.from(map['importador'] as Map)
          : null;

      final isNew = created != null &&
          updated != null &&
          updated.difference(created).inMinutes.abs() < 2 &&
          status == TransactionRequestStatus.pendiente;
      // Entrega final la confirma el taller minorista (aliado), no el importador.
      final isDelivered = status == TransactionRequestStatus.entregado;
      final actorIsAliado = isNew || isDelivered;

      final aliadoName = aliado?['business_name']?.toString().trim() ?? '';
      final importerName =
          importador?['business_name']?.toString().trim() ?? '';
      final actor = actorIsAliado
          ? (aliadoName.isNotEmpty ? aliadoName : 'Taller')
          : (importerName.isNotEmpty
              ? importerName
              : (aliadoName.isNotEmpty ? aliadoName : 'Usuario'));

      final aliadoLogo = aliado?['logo_storage_path']?.toString();
      final importerLogo = importador?['logo_storage_path']?.toString();
      final logo =
          actorIsAliado ? aliadoLogo : (importerLogo ?? aliadoLogo);

      final ref = _orderRef(map['checkout_group_id']?.toString() ?? id);
      final kind = isNew
          ? RecentActivityKind.orderCreated
          : RecentActivityKind.orderUpdated;
      final description = isNew
          ? 'creó un nuevo pedido ($ref)'
          : _orderUpdateDescription(status, ref);

      items.add(
        RecentActivityItem(
          id: 'order-$id',
          kind: kind,
          actorName: actor,
          description: description,
          at: at.toLocal(),
          logoStoragePath: logo,
          actorRole: actorIsAliado
              ? 'aliado'
              : importador?['role']?.toString(),
        ),
      );
    }
    return items;
  }

  static Future<List<RecentActivityItem>> _fetchRecentProfiles({
    int limit = 12,
  }) async {
    final raw = await SupabaseAccess.client
        .from('profiles')
        .select(
          'id, business_name, role, account_access_status, created_at, logo_storage_path',
        )
        .inFilter('role', const ['aliado', 'importador'])
        .order('created_at', ascending: false)
        .limit(limit.clamp(1, 100));
    final list = raw as List<dynamic>;
    final items = <RecentActivityItem>[];
    for (final row in list) {
      final map = Map<String, dynamic>.from(row as Map);
      final id = map['id']?.toString() ?? '';
      if (id.isEmpty) continue;
      final created = DateTime.tryParse(map['created_at']?.toString() ?? '');
      if (created == null) continue;
      final role = map['role']?.toString() ?? '';
      final status = map['account_access_status']?.toString();
      final name = map['business_name']?.toString().trim().isNotEmpty == true
          ? map['business_name'].toString().trim()
          : (role == 'importador' ? 'Proveedor' : 'Taller');
      final isPending = status == AccountAccessStatus.pendingReview;
      final isImportador = role == 'importador';
      items.add(
        RecentActivityItem(
          id: 'profile-$id',
          kind: isPending
              ? RecentActivityKind.accountPendingReview
              : RecentActivityKind.accountRegistered,
          actorName: name,
          description: isPending
              ? 'envió documentos para verificación'
              : (isImportador
                  ? 'registró una nueva cuenta de proveedor'
                  : 'registró una nueva cuenta de taller'),
          at: created.toLocal(),
          logoStoragePath: map['logo_storage_path']?.toString(),
          actorRole: role,
        ),
      );
    }
    return items;
  }

  static String _orderRef(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return '#----';
    final slice = value.substring(0, value.length < 8 ? value.length : 8);
    return '#${slice.toUpperCase()}';
  }

  static String _orderUpdateDescription(String status, String ref) {
    switch (status) {
      case TransactionRequestStatus.entregado:
        return 'marcó el pedido ($ref) como entregado';
      case TransactionRequestStatus.enTransito:
      case TransactionRequestStatus.enviado:
        return 'puso el pedido ($ref) en tránsito';
      case TransactionRequestStatus.enPreparacion:
        return 'pasó el pedido ($ref) a preparación';
      case TransactionRequestStatus.pedidoListo:
        return 'marcó el pedido ($ref) como listo';
      case TransactionRequestStatus.rechazado:
        return 'rechazó el pedido ($ref)';
      case TransactionRequestStatus.aprobadoAdmin:
        return 'confirmó el pedido ($ref)';
      default:
        return 'actualizó el pedido ($ref)';
    }
  }

  /// Marca de tiempo relativa en español.
  static String formatRelativeEs(DateTime at, [DateTime? now]) {
    final n = now ?? DateTime.now();
    final d = n.difference(at);
    if (d.isNegative || d.inSeconds < 45) return 'hace un momento';
    if (d.inMinutes < 60) {
      final m = d.inMinutes == 0 ? 1 : d.inMinutes;
      return 'hace $m min';
    }
    if (d.inHours < 24) {
      final h = d.inHours;
      return h == 1 ? 'hace 1 h' : 'hace $h h';
    }
    if (d.inDays == 1) return 'hace 1 día';
    if (d.inDays < 7) return 'hace ${d.inDays} días';
    return '${at.day.toString().padLeft(2, '0')}/${at.month.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _disposed = true;
    _poll?.cancel();
    super.dispose();
  }
}
