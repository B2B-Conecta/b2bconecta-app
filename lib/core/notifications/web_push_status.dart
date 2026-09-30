/// Estado de Web Push en el cliente (PWA / Safari iOS).
enum WebPushUiStatus {
  unsupported,
  iosNeedsInstall,
  permissionDefault,
  permissionDenied,
  subscribed,
  expired,
  error,
}

extension WebPushUiStatusX on WebPushUiStatus {
  bool get canActivate =>
      this == WebPushUiStatus.permissionDefault ||
      this == WebPushUiStatus.expired;

  bool get isActive => this == WebPushUiStatus.subscribed;
}
