import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/features/catalog/aliado_promo_campaign_widgets.dart';
import 'package:motolink_pro_app/features/catalog/promo_campaign_model.dart';

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

  test('la tienda ve cuánto le queda a la valla', () {
    final now = DateTime(2026, 10, 13);
    expect(
      promoPeriodCountdownLabel(
        DateTime(2026, 10, 8),
        DateTime(2026, 10, 13, 23),
        now: now,
      ),
      'Termina hoy',
    );
    expect(
      promoPeriodCountdownLabel(
        DateTime(2026, 10, 8),
        DateTime(2026, 10, 14),
        now: now,
      ),
      'Termina mañana',
    );
    expect(
      promoPeriodCountdownLabel(
        DateTime(2026, 10, 8),
        DateTime(2026, 10, 16),
        now: now,
      ),
      'Quedan 3 días',
    );
    expect(
      promoPeriodOnPhotoLabel(
        DateTime(2026, 10, 8),
        DateTime(2026, 10, 31),
        now: now,
      ),
      'Hasta el 31 oct',
    );
  });

  test('la valla del aliado conserva el periodo real', () {
    final campaign = PromoCampaignModel.fromAliadoRpcJson({
      'id': 'c1',
      'display_title': 'Oferta',
      'campaign_type': 'banner',
      'image_public_url': 'https://example.com/a.jpg',
      'starts_at': '2026-10-08T04:00:00Z',
      'ends_at': '2026-10-31T03:59:59Z',
      'action_type': 'none',
    });
    expect(
      campaign.startsAt,
      DateTime.parse('2026-10-08T04:00:00Z').toLocal(),
    );
    expect(
      campaign.endsAt,
      DateTime.parse('2026-10-31T03:59:59Z').toLocal(),
    );
  });
}
