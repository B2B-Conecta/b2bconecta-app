import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/features/catalog/promo_campaign_model.dart';

PromoCampaignModel _campaign({
  required bool isActive,
  required DateTime startsAt,
  required DateTime endsAt,
}) {
  return PromoCampaignModel(
    id: 'c1',
    internalTitle: 'Test',
    campaignType: PromoCampaignModel.typeBanner,
    imageStoragePath: 'p.jpg',
    imagePublicUrl: 'https://example.com/p.jpg',
    actionType: PromoCampaignModel.actionNone,
    startsAt: startsAt,
    endsAt: endsAt,
    priority: 10,
    isActive: isActive,
  );
}

void main() {
  final now = DateTime(2026, 11, 5);

  test('sello Activa / Desactivada según is_active', () {
    final active = _campaign(
      isActive: true,
      startsAt: DateTime(2026, 10, 1),
      endsAt: DateTime(2026, 12, 1),
    );
    final inactive = _campaign(
      isActive: false,
      startsAt: DateTime(2026, 10, 1),
      endsAt: DateTime(2026, 12, 1),
    );
    expect(active.adminActiveSealLabel, 'Activa');
    expect(inactive.adminActiveSealLabel, 'Desactivada');
    expect(inactive.adminScheduleSealLabel, isNull);
  });

  test('calendario: programada / vigente / vencida', () {
    expect(
      _campaign(
        isActive: true,
        startsAt: DateTime(2026, 12, 1),
        endsAt: DateTime(2026, 12, 15),
      ).scheduleStatus(now: now),
      'programada',
    );
    expect(
      _campaign(
        isActive: true,
        startsAt: DateTime(2026, 10, 19),
        endsAt: DateTime(2026, 11, 18),
      ).scheduleStatus(now: now),
      'vigente',
    );
    expect(
      _campaign(
        isActive: true,
        startsAt: DateTime(2026, 10, 19),
        endsAt: DateTime(2026, 10, 23),
      ).scheduleStatus(now: now),
      'vencida',
    );
  });

  test('sello de calendario refleja el estado del día', () {
    final farFuture = _campaign(
      isActive: true,
      startsAt: DateTime.now().add(const Duration(days: 30)),
      endsAt: DateTime.now().add(const Duration(days: 40)),
    );
    expect(farFuture.adminScheduleSealLabel, 'Programada');

    final live = _campaign(
      isActive: true,
      startsAt: DateTime.now().subtract(const Duration(days: 2)),
      endsAt: DateTime.now().add(const Duration(days: 2)),
    );
    expect(live.adminScheduleSealLabel, 'En vitrina');

    final expired = _campaign(
      isActive: true,
      startsAt: DateTime.now().subtract(const Duration(days: 20)),
      endsAt: DateTime.now().subtract(const Duration(days: 10)),
    );
    expect(expired.adminScheduleSealLabel, 'Vencida');
  });
}
