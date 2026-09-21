void syncMetaPixel({required bool marketingAllowed}) {}

void trackRegistrationStarted({String? identity}) {}

void trackSubmitApplication({String? userId}) {}

void trackCompleteRegistration({String? email, String? userId}) {}

void trackPurchase({
  required String orderId,
  required double valueUsd,
}) {}
