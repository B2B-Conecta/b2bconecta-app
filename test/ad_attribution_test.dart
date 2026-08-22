import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/features/ads/ad_attribution.dart';

void main() {
  test('parses UTM and fbclid from query', () {
    final attr = AdAttribution.fromUri(
      Uri.parse(
        'https://www.b2bconecta.com.ve/registro'
        '?utm_source=meta&utm_medium=cpc&utm_campaign=lanzamiento'
        '&utm_content=carrusel&utm_term=repuestos&fbclid=IwAR123'
        '&registro=1',
      ),
    );
    expect(attr.isEmpty, isFalse);
    expect(attr.utmSource, 'meta');
    expect(attr.utmMedium, 'cpc');
    expect(attr.utmCampaign, 'lanzamiento');
    expect(attr.utmContent, 'carrusel');
    expect(attr.utmTerm, 'repuestos');
    expect(attr.fbclid, 'IwAR123');
    expect(attr.toProfileColumns()['utm_source'], 'meta');
  });

  test('parses UTM from hash fragment', () {
    final attr = AdAttribution.fromUri(
      Uri.parse('https://www.b2bconecta.com.ve/#/registro?utm_source=meta&fbclid=x'),
    );
    expect(attr.utmSource, 'meta');
    expect(attr.fbclid, 'x');
  });

  test('ignores empty and login-only URLs', () {
    expect(
      AdAttribution.fromUri(Uri.parse('http://localhost:3000/')).isEmpty,
      isTrue,
    );
    expect(
      AdAttribution.fromUri(
        Uri.parse('http://localhost:3000/registro?registro=1'),
      ).isEmpty,
      isTrue,
    );
  });

  test('firstTouch keeps the first non-empty snapshot', () {
    const first = AdAttribution(utmSource: 'meta', fbclid: 'a');
    const later = AdAttribution(utmSource: 'google', fbclid: 'b');
    final kept = AdAttribution.firstTouch(first, later);
    expect(kept.utmSource, 'meta');
    expect(kept.fbclid, 'a');
    expect(
      AdAttribution.firstTouch(null, later).utmSource,
      'google',
    );
  });

  test('clean trims and caps length', () {
    expect(AdAttribution.clean('  meta  '), 'meta');
    expect(AdAttribution.clean(''), isNull);
    expect(AdAttribution.clean('x' * 600)?.length, AdAttribution.maxLen);
  });
}
