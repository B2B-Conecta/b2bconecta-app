import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/core/layout/infinite_scroll.dart';

ScrollMetrics _metrics({
  required double extentAfter,
  AxisDirection axisDirection = AxisDirection.down,
}) {
  const viewport = 400.0;
  const max = 1000.0;
  return FixedScrollMetrics(
    minScrollExtent: 0,
    maxScrollExtent: max,
    pixels: max - extentAfter,
    viewportDimension: viewport,
    axisDirection: axisDirection,
    devicePixelRatio: 1,
  );
}

void main() {
  testWidgets('pide más cuando el scroll está cerca del final', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(),
      ),
    );
    final context = tester.element(find.byType(SizedBox));
    final n = ScrollUpdateNotification(
      metrics: _metrics(extentAfter: 40),
      context: context,
    );
    expect(infiniteScrollShouldLoadMore(n), isTrue);
  });

  testWidgets('no pide más si todavía queda mucho listado', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(),
      ),
    );
    final context = tester.element(find.byType(SizedBox));
    final n = ScrollUpdateNotification(
      metrics: _metrics(extentAfter: 900),
      context: context,
    );
    expect(infiniteScrollShouldLoadMore(n), isFalse);
  });

  testWidgets('ignora scroll horizontal', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(),
      ),
    );
    final context = tester.element(find.byType(SizedBox));
    final n = ScrollUpdateNotification(
      metrics: _metrics(
        extentAfter: 10,
        axisDirection: AxisDirection.right,
      ),
      context: context,
    );
    expect(infiniteScrollShouldLoadMore(n), isFalse);
  });
}
