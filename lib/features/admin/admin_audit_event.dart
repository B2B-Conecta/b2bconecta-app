import 'package:flutter/foundation.dart';

/// Evento de auditoría del hub Usuarios → Actividad.
enum AdminAuditAction {
  login,
  accountCreated,
  accountUpdated,
  kycSubmitted,
  kycApproved,
  softDelete,
  hardDelete,
  accessBlocked,
  accessActivated,
  orderCreated,
  orderUpdated,
  other,
}

extension AdminAuditActionLabel on AdminAuditAction {
  String get labelEs => switch (this) {
        AdminAuditAction.login => 'Inicio de sesión',
        AdminAuditAction.accountCreated => 'Alta de cuenta',
        AdminAuditAction.accountUpdated => 'Edición de expediente',
        AdminAuditAction.kycSubmitted => 'Envío de documentos',
        AdminAuditAction.kycApproved => 'Aprobación KYC',
        AdminAuditAction.softDelete => 'Baja (soft delete)',
        AdminAuditAction.hardDelete => 'Purga (hard delete)',
        AdminAuditAction.accessBlocked => 'Bloqueo de acceso',
        AdminAuditAction.accessActivated => 'Activación de acceso',
        AdminAuditAction.orderCreated => 'Pedido creado',
        AdminAuditAction.orderUpdated => 'Pedido actualizado',
        AdminAuditAction.other => 'Acción',
      };
}

@immutable
class AdminAuditEvent {
  const AdminAuditEvent({
    required this.id,
    required this.at,
    required this.action,
    required this.actorName,
    required this.targetName,
    this.ipAddress,
    this.source,
    this.detail,
  });

  final String id;
  final DateTime at;
  final AdminAuditAction action;

  /// Usuario responsable de la acción.
  final String actorName;

  /// Cuenta / recurso afectado.
  final String targetName;

  /// IP si está disponible; si no, se muestra [source].
  final String? ipAddress;
  final String? source;
  final String? detail;

  String get ipOrSource {
    final ip = ipAddress?.trim();
    if (ip != null && ip.isNotEmpty) return ip;
    final s = source?.trim();
    if (s != null && s.isNotEmpty) return s;
    return '—';
  }

  static List<AdminAuditEvent> sampleRows({DateTime? now}) {
    final t = now ?? DateTime(2026, 11, 12, 9, 30);
    return [
      AdminAuditEvent(
        id: 'aud-1',
        at: t.subtract(const Duration(minutes: 4)),
        action: AdminAuditAction.login,
        actorName: 'Carlos Figueira',
        targetName: 'B2B Conecta Ops',
        ipAddress: '190.93.12.44',
        source: 'web',
        detail: 'Panel administrativo',
      ),
      AdminAuditEvent(
        id: 'aud-2',
        at: t.subtract(const Duration(minutes: 18)),
        action: AdminAuditAction.kycSubmitted,
        actorName: 'Taller El Rayo Caracas',
        targetName: 'Taller El Rayo Caracas',
        ipAddress: '186.167.88.21',
        source: 'mobile',
        detail: 'RIF · Registro mercantil · Cédula',
      ),
      AdminAuditEvent(
        id: 'aud-3',
        at: t.subtract(const Duration(hours: 1)),
        action: AdminAuditAction.kycApproved,
        actorName: 'Admin B2B',
        targetName: 'Mayorista Andes Lubricantes',
        ipAddress: '190.93.12.44',
        source: 'web',
        detail: 'Documentación fiscal verificada',
      ),
      AdminAuditEvent(
        id: 'aud-4',
        at: t.subtract(const Duration(hours: 3)),
        action: AdminAuditAction.accountUpdated,
        actorName: 'Admin B2B',
        targetName: 'Importadora Valencia Parts',
        ipAddress: '190.93.12.44',
        source: 'web',
        detail: 'Actualización de RIF y contacto legal',
      ),
      AdminAuditEvent(
        id: 'aud-5',
        at: t.subtract(const Duration(hours: 6)),
        action: AdminAuditAction.softDelete,
        actorName: 'Super Admin',
        targetName: 'Taller Norte Demo',
        ipAddress: '190.93.12.44',
        source: 'web',
        detail: 'Motivo: cuenta de prueba fuera de operación',
      ),
      AdminAuditEvent(
        id: 'aud-6',
        at: t.subtract(const Duration(days: 1)),
        action: AdminAuditAction.orderCreated,
        actorName: 'Taller Moto Ruices',
        targetName: 'Pedido #A1B2C3D4',
        ipAddress: '201.249.55.10',
        source: 'web',
      ),
      AdminAuditEvent(
        id: 'aud-7',
        at: t.subtract(const Duration(days: 1, hours: 2)),
        action: AdminAuditAction.accessActivated,
        actorName: 'Admin B2B',
        targetName: 'Taller Moto Ruices',
        ipAddress: '190.93.12.44',
        source: 'web',
      ),
      AdminAuditEvent(
        id: 'aud-8',
        at: t.subtract(const Duration(days: 2)),
        action: AdminAuditAction.accountCreated,
        actorName: 'Super Admin',
        targetName: 'Repuestos del Centro C.A.',
        ipAddress: '190.93.12.44',
        source: 'web',
        detail: 'Invitación proveedor (importador)',
      ),
    ];
  }
}
