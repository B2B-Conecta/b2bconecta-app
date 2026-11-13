/// Constantes y helpers del flujo Minorista-Emprendedor.
abstract final class RetailerTier {
  static const standard = 'standard';
  static const entrepreneur = 'entrepreneur';
}

abstract final class EntrepreneurStatus {
  static const activeTrial = 'active_trial';

  /// Día 5–8 hábiles sin primera compra (cuenta regresiva de 3 días).
  static const pendingWarningPeriod = 'pending_warning_period';

  /// Legado (pre-mecánica 8 días); tratar como advertencia.
  static const pendingFirstPurchaseAlert = 'pending_first_purchase_alert';

  static const kycInProgress = 'kyc_in_progress';
  static const expiredLocked = 'expired_locked';
  static const reactivationRequested = 'reactivation_requested';
  static const verifiedStandard = 'verified_standard';

  static bool isFirstPurchaseWarning(String? status) {
    final s = status?.trim().toLowerCase();
    return s == pendingWarningPeriod || s == pendingFirstPurchaseAlert;
  }

  static bool isFirstPurchaseWindow(String? status) {
    final s = status?.trim().toLowerCase();
    return s == activeTrial || isFirstPurchaseWarning(s);
  }
}

/// Documentos diferidos a 8 semanas (expediente posterior al alta).
abstract final class EntrepreneurDeferredKycDocs {
  static const registroMercantil = 'registro_mercantil';
  static const referenciaBancaria1 = 'referencia_bancaria_1';
  static const referenciaBancaria2 = 'referencia_bancaria_2';

  /// Alias canónico de producto (= `referencia_comercial` en BD).
  static const registroComercialCartaCredito = 'registro_comercial_carta_credito';

  static const storageDocType = 'referencia_comercial';

  static const requiredDeferred = <String>[
    registroMercantil,
    referenciaBancaria1,
    referenciaBancaria2,
    registroComercialCartaCredito,
  ];

  static String toStorageDocType(String type) {
    final t = type.trim();
    if (t == registroComercialCartaCredito) return storageDocType;
    return t;
  }

  static String labelEs(String type) {
    final t = type.trim();
    return switch (t) {
      registroMercantil => 'Registro Mercantil',
      referenciaBancaria1 => 'Referencia Bancaria 1',
      referenciaBancaria2 => 'Referencia Bancaria 2',
      registroComercialCartaCredito || storageDocType =>
        'Registro Comercial / Carta de Crédito',
      _ => t,
    };
  }

  /// Estados en los que el bloque de docs diferidos permanece accesible.
  static bool documentsSectionVisible(String? status) {
    final s = status?.trim().toLowerCase();
    if (s == null || s.isEmpty) return true;
    return s == EntrepreneurStatus.activeTrial ||
        EntrepreneurStatus.isFirstPurchaseWarning(s) ||
        s == EntrepreneurStatus.kycInProgress ||
        s == EntrepreneurStatus.expiredLocked ||
        s == EntrepreneurStatus.reactivationRequested ||
        s == EntrepreneurStatus.verifiedStandard;
  }
}

/// Helpers de bloqueo marketplace.
abstract final class EntrepreneurMarketplaceLock {
  static bool isLockedStatus(String? status) {
    final s = status?.trim().toLowerCase();
    return s == EntrepreneurStatus.expiredLocked ||
        s == EntrepreneurStatus.reactivationRequested;
  }

  static bool locksMarketplace({
    required bool isEntrepreneurRetailer,
    required String? entrepreneurStatus,
  }) {
    return isEntrepreneurRetailer && isLockedStatus(entrepreneurStatus);
  }
}

/// Progreso de la ventana de primera compra (8 días hábiles).
abstract final class EntrepreneurFirstPurchaseProgress {
  static const totalBusinessDays = 8;
  static const warningAfterBusinessDays = 5;

  /// Bloqueo por no comprar (sin plazo KYC documental).
  static bool isFirstPurchaseLock({
    required String? entrepreneurStatus,
    required DateTime? kycCompletionDeadline,
  }) {
    final s = entrepreneurStatus?.trim().toLowerCase();
    if (s != EntrepreneurStatus.expiredLocked &&
        s != EntrepreneurStatus.reactivationRequested) {
      return false;
    }
    return kycCompletionDeadline == null;
  }

  static int countBusinessDaysElapsed(DateTime from, DateTime to) {
    var cursor = DateTime(from.year, from.month, from.day);
    final end = DateTime(to.year, to.month, to.day);
    if (end.isBefore(cursor)) return 0;
    var count = 0;
    while (!cursor.isAfter(end)) {
      if (cursor.weekday >= DateTime.monday &&
          cursor.weekday <= DateTime.friday) {
        count++;
      }
      cursor = cursor.add(const Duration(days: 1));
    }
    return count;
  }

  static int dayOfEight({
    int? rpcDay,
    DateTime? registeredAt,
    DateTime? createdAt,
    DateTime? now,
  }) {
    if (rpcDay != null && rpcDay > 0) {
      return rpcDay.clamp(1, totalBusinessDays);
    }
    final start = registeredAt ?? createdAt;
    if (start == null) return 1;
    final elapsed = countBusinessDaysElapsed(start, now ?? DateTime.now());
    if (elapsed <= 0) return 1;
    return elapsed.clamp(1, totalBusinessDays);
  }

  static String adminProgressLabel({
    required String? status,
    int? rpcDay,
    DateTime? registeredAt,
    DateTime? createdAt,
  }) {
    final day = dayOfEight(
      rpcDay: rpcDay,
      registeredAt: registeredAt,
      createdAt: createdAt,
    );
    if (EntrepreneurStatus.isFirstPurchaseWarning(status)) {
      return 'En cuenta regresiva de 3 días (día $day de $totalBusinessDays hábiles)';
    }
    if (status?.trim().toLowerCase() == EntrepreneurStatus.activeTrial) {
      return 'Día $day de $totalBusinessDays hábiles';
    }
    return 'Día $day de $totalBusinessDays hábiles';
  }
}
