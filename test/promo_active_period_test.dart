import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/features/catalog/aliado_promo_campaign_widgets.dart';

void main() {
  test('el periodo de una valla se lee en una frase', () {
    expect(
      promoActivePeriodLabel(
        DateTime(2026, 10, 8),
        DateTime(2026, 10, 31),
      ),
      'Del 8 al 31 oct',
    );
    expect(
      promoActivePeriodLabel(
        DateTime(2026, 10, 8),
        DateTime(2026, 11, 2),
      ),
      'Del 8 oct al 2 nov',
    );
    expect(
      promoActivePeriodLabel(
        DateTime(2026, 12, 20),
        DateTime(2027, 1, 5),
      ),
      'Del 20 dic 2026 al 5 ene 2027',
    );
    expect(
      promoActivePeriodLabel(
        DateTime(2026, 10, 8, 9),
        DateTime(2026, 10, 8, 18),
      ),
      'Solo el 8 oct',
    );
  });
}
