import 'package:motolink_pro_app/features/inventory/inventory_service.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';

/// Pasos de arranque del importador, con las reglas que ya usa el perfil.
class ImporterOnboardingStep {
  const ImporterOnboardingStep({
    required this.title,
    required this.done,
    required this.detail,
  });

  final String title;
  final bool done;
  final String detail;
}

class ImporterOnboardingChecklist {
  const ImporterOnboardingChecklist(this.steps);

  final List<ImporterOnboardingStep> steps;

  int get doneCount => steps.where((s) => s.done).length;

  int get total => steps.length;

  bool get isComplete => total > 0 && doneCount == total;

  double get progress => total == 0 ? 0 : doneCount / total;

  factory ImporterOnboardingChecklist.evaluate({
    required ProfileModel? profile,
    required InventoryMetrics? metrics,
  }) {
    final p = profile;
    final published = metrics == null
        ? 0
        : (metrics.totalProducts - metrics.paused).clamp(0, metrics.totalProducts);
    return ImporterOnboardingChecklist([
      ImporterOnboardingStep(
        title: 'Completar perfil y RIF',
        done: p?.isComplete == true,
        detail: 'Nombre del negocio, RIF y domicilio fiscal.',
      ),
      ImporterOnboardingStep(
        title: 'Configurar cuentas de pago',
        done: _hasPaymentSetup(p),
        detail: 'Medios y datos que la tienda usa para pagarle.',
      ),
      ImporterOnboardingStep(
        title: 'Definir pedido mínimo de compra',
        done: p?.hasMinOrderAmount == true,
        detail: 'Piso del pedido en el perfil del negocio.',
      ),
      ImporterOnboardingStep(
        title: 'Cargar el primer producto',
        done: (metrics?.totalProducts ?? 0) > 0,
        detail: 'Al menos un producto en el inventario.',
      ),
      ImporterOnboardingStep(
        title: 'Publicar el catálogo',
        done: published > 0,
        detail: 'Un producto publicado se ve en las tiendas. Uno pausado, no.',
      ),
    ]);
  }
}

/// Null en `accepted_pago_metodos` es el default de plataforma, no una cuenta cargada.
bool _hasPaymentSetup(ProfileModel? profile) {
  if (profile == null) return false;
  final saved = profile.acceptedPagoMetodos;
  if (saved != null && saved.any((m) => m.trim().isNotEmpty)) return true;
  return profile.pagoMetodoInstrucciones.values.any((v) => v.trim().isNotEmpty);
}
