import '../models/app_home_role.dart';
import '../widgets/main_shell_tab.dart';

/// Navegación al tocar una notificación (in-app o push del sistema).
void navigateFromNotificationPayload({
  required AppHomeRole homeRole,
  required String type,
  String? relatedId,
  String? title,
}) {
  MainShellTabController.setPendingNotificationRelatedId(relatedId);
  MainShellTabController.setPendingNotificationType(type);
  final t0 = type.trim();

  if (t0 == 'kyc') {
    switch (homeRole) {
      case AppHomeRole.administrador:
        MainShellTabController.setPendingKycProfileId(relatedId);
        MainShellTabController.navigateToAdminKycForNotification();
        return;
      case AppHomeRole.aliado:
      case AppHomeRole.importador:
        MainShellTabController.navigateToProfileKycDocumentation();
        return;
    }
  }
  if (t0 == 'credito' && homeRole == AppHomeRole.administrador) {
    MainShellTabController.navigateToAdminActivosForNotification();
    return;
  }
  if (t0 == 'supervision' && homeRole == AppHomeRole.administrador) {
    MainShellTabController.navigateToAdminActivosForNotification();
    return;
  }
  if (t0 == 'mensaje') {
    switch (homeRole) {
      case AppHomeRole.aliado:
      case AppHomeRole.importador:
        MainShellTabController.navigateToPedidosForNotification();
        return;
      case AppHomeRole.administrador:
        MainShellTabController.navigateToAdminActivosForNotification();
        return;
    }
  }
  if (t0 == 'comision') {
    MainShellTabController.setPendingCommissionSettlementId(relatedId);
    switch (homeRole) {
      case AppHomeRole.administrador:
        MainShellTabController.navigateToAdminComisionesForNotification();
        return;
      case AppHomeRole.importador:
        MainShellTabController.navigateToImporterCommissionSettlementsForNotification();
        return;
      case AppHomeRole.aliado:
        return;
    }
  }
  if (t0 == 'promocion') {
    switch (homeRole) {
      case AppHomeRole.importador:
        MainShellTabController.navigateToImporterInventoryForNotification();
        return;
      case AppHomeRole.administrador:
      case AppHomeRole.aliado:
        return;
    }
  }
  if (t0 == 'morosidad') {
    switch (homeRole) {
      case AppHomeRole.aliado:
        MainShellTabController.navigateToPedidosForNotification();
        return;
      case AppHomeRole.importador:
        MainShellTabController.setPendingImporterPedidosPreferCerradosFilter();
        MainShellTabController.navigateToPedidosForNotification();
        return;
      case AppHomeRole.administrador:
        MainShellTabController.navigateToAdminCerradosForNotification();
        return;
    }
  }
  if (t0 == 'envio') {
    switch (homeRole) {
      case AppHomeRole.aliado:
        MainShellTabController.navigateToPedidosForNotification();
        return;
      case AppHomeRole.importador:
        MainShellTabController.setImporterPedidosPreferNuevosFilter(true);
        MainShellTabController.navigateToPedidosForNotification();
        return;
      case AppHomeRole.administrador:
        MainShellTabController.navigateToAdminActivosForNotification();
        return;
    }
  }
  if (t0 == 'pedido') {
    switch (homeRole) {
      case AppHomeRole.aliado:
      case AppHomeRole.importador:
        MainShellTabController.navigateToPedidosForNotification();
        return;
      case AppHomeRole.administrador:
        MainShellTabController.navigateToAdminActivosForNotification();
        return;
    }
  }
  if (t0 == 'pago') {
    switch (homeRole) {
      case AppHomeRole.aliado:
        MainShellTabController.navigateToPedidosForNotification();
        return;
      case AppHomeRole.importador:
        MainShellTabController.setImporterPedidosPreferEnProcesoFilter();
        MainShellTabController.navigateToPedidosForNotification();
        return;
      case AppHomeRole.administrador:
        MainShellTabController.navigateToAdminActivosForNotification();
        return;
    }
  }

  final legacyOrderAsActive = homeRole == AppHomeRole.administrador &&
      t0 == 'envio' &&
      (title?.trim() == 'Nueva solicitud por validar');
  if (homeRole == AppHomeRole.administrador &&
      (t0 == 'validacion' || legacyOrderAsActive)) {
    MainShellTabController.navigateToAdminActivosForNotification();
    return;
  }

  switch (homeRole) {
    case AppHomeRole.administrador:
      MainShellTabController.navigateToAdminActivosForNotification();
      return;
    case AppHomeRole.aliado:
      MainShellTabController.navigateToPedidosForNotification();
      return;
    case AppHomeRole.importador:
      MainShellTabController.navigateToPedidosForNotification();
      return;
  }
}
