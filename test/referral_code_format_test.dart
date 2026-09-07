import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/features/referrals/referral_code_format.dart';
import 'package:motolink_pro_app/features/referrals/referral_invite_config.dart';

void main() {
  test('previewCode usa el primer nombre y sufijo .B2B', () {
    expect(ReferralCodeFormat.previewCode('Pedro Pérez'), 'PEDRO.B2B');
    expect(ReferralCodeFormat.previewCode('José'), 'JOSE.B2B');
    expect(ReferralCodeFormat.previewCode('Ñoño'), 'NONO.B2B');
    expect(ReferralCodeFormat.previewCode('A'), 'VENDEDOR.B2B');
  });

  test('normalizeCode conserva el punto de NOMBRE.B2B', () {
    expect(ReferralInviteConfig.normalizeCode('pedro.b2b'), 'PEDRO.B2B');
    expect(ReferralInviteConfig.normalizeCode(' PEDRO . B2B '), 'PEDRO.B2B');
    expect(ReferralInviteConfig.normalizeCode('B2BK7M2P9'), 'B2BK7M2P9');
  });
}
