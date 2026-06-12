/// Notificación de KYC que indica acceso habilitado para un aliado.
bool isAliadoAccessApprovedNotification({
  required String type,
  required String title,
}) {
  final t = type.trim().toLowerCase();
  final tit = title.trim().toLowerCase();
  if (t != 'kyc') return false;
  return tit.contains('validado') ||
      tit.contains('habilitado') ||
      tit.contains('aprobado');
}
