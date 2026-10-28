import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/features/catalog/product_photo_gallery.dart';

// Tiny deterministic fixture: tests do not download supplier images.
final _bytes =
    base64Decode('R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7');

class _RetryImage extends MemoryImage {
  _RetryImage() : super(_bytes);
  final attempts = ValueNotifier<int>(0);

  @override
  ImageStreamCompleter loadImage(MemoryImage key, ImageDecoderCallback decode) {
    attempts.value++;
    if (attempts.value == 1) {
      return OneFrameImageStreamCompleter(
          Future<ImageInfo>.error(StateError('Temporary photo failure')));
    }
    return super.loadImage(key, decode);
  }
}

Future<void> _pumpGallery(WidgetTester tester,
    {List<String> urls = const ['one'],
    ImageProvider<Object>? provider,
    double scale = 1,
    bool dark = false}) async {
  final image = provider ?? MemoryImage(_bytes);
  await tester.pumpWidget(MaterialApp(
    theme: dark ? buildAppDarkTheme() : buildAppTheme(),
    builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!),
    home: Scaffold(
      body: Align(
        alignment: Alignment.topCenter,
        child: SizedBox.square(
          dimension: 300,
          child: ProductPhotoGallery(
              urls: urls,
              productName: 'Casco de prueba',
              imageProvider: (_) => image),
        ),
      ),
    ),
  ));
  await tester.runAsync(() async {
    if (provider is! _RetryImage) {
      await precacheImage(
          image, tester.element(find.byType(ProductPhotoGallery)));
    }
  });
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  });
  testWidgets('missing photos do not offer an empty viewer', (tester) async {
    await _pumpGallery(tester, urls: const []);
    expect(find.text('Foto no disponible'), findsOneWidget);
    expect(find.byTooltip('Ampliar foto'), findsNothing);
    expect(find.byTooltip('Foto siguiente'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('single photo opens, zooms, resets and closes with Escape',
      (tester) async {
    await _pumpGallery(tester);
    expect(find.byTooltip('Ampliar foto'), findsOneWidget);
    expect(find.byTooltip('Foto siguiente'), findsNothing);
    await tester.tap(find.byTooltip('Ampliar foto'));
    await tester.pumpAndSettle();
    expect(find.text('100%'), findsOneWidget);
    await tester.tap(find.byTooltip('Acercar foto'));
    await tester.pump();
    expect(find.text('150%'), findsOneWidget);
    expect(
        tester
            .widget<InteractiveViewer>(find.byType(InteractiveViewer))
            .transformationController!
            .value
            .getMaxScaleOnAxis(),
        closeTo(1.5, 0.01));
    await tester.tap(find.byTooltip('Alejar foto'));
    await tester.pump();
    expect(find.text('100%'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsNothing);
    expect(find.byTooltip('Ampliar foto'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'arrows, thumbnails and swipe navigate without changing image order',
      (tester) async {
    await _pumpGallery(tester, urls: const ['one', 'two', 'three']);
    expect(find.text('1 / 3'), findsOneWidget);
    expect(
        tester
            .widget<IconButton>(
                find.widgetWithIcon(IconButton, Icons.chevron_left_rounded))
            .onPressed,
        isNull);
    await tester.tap(find.byTooltip('Foto siguiente'));
    await tester.pumpAndSettle();
    expect(find.text('2 / 3'), findsOneWidget);
    await tester.tap(find.byTooltip('Ver foto 3'));
    await tester.pumpAndSettle();
    expect(find.text('3 / 3'), findsOneWidget);
    await tester.drag(find.byType(PageView), const Offset(280, 0));
    await tester.pumpAndSettle();
    expect(find.text('2 / 3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('viewer starts on the selected photo and returns its final photo',
      (tester) async {
    await _pumpGallery(tester, urls: const ['one', 'two', 'three']);
    await tester.tap(find.byTooltip('Ver foto 2'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Ampliar foto'));
    await tester.pumpAndSettle();
    expect(find.text('2 / 3'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(find.text('3 / 3'), findsOneWidget);
    await tester.tap(find.byTooltip('Cerrar fotos'));
    await tester.pumpAndSettle();
    expect(find.text('3 / 3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'double tap zooms, panning moves the enlarged image and zoom is bounded',
      (tester) async {
    await _pumpGallery(tester);
    await tester.tap(find.byTooltip('Ampliar foto'));
    await tester.pumpAndSettle();
    final viewer = find.byType(InteractiveViewer);
    await tester.tap(viewer);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(viewer);
    await tester.pumpAndSettle();
    final transform =
        tester.widget<InteractiveViewer>(viewer).transformationController!;
    expect(transform.value.getMaxScaleOnAxis(), closeTo(2.5, 0.01));
    final before = transform.value.getTranslation().x;
    await tester.drag(viewer, const Offset(50, 0));
    await tester.pumpAndSettle();
    expect(transform.value.getTranslation().x, greaterThan(before));
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byTooltip('Acercar foto'));
      await tester.pump();
    }
    expect(transform.value.getMaxScaleOnAxis(), closeTo(4, 0.01));
    expect(
        tester
            .widget<IconButton>(
                find.widgetWithIcon(IconButton, Icons.add_rounded))
            .onPressed,
        isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed photo offers retry instead of an empty zoom action',
      (tester) async {
    final image = _RetryImage();
    addTearDown(image.attempts.dispose);
    await _pumpGallery(tester, provider: image);
    expect(find.text('No se pudo cargar la foto'), findsOneWidget);
    expect(find.byTooltip('Ampliar foto'), findsNothing);
    await tester.tap(find.text('Reintentar'));
    await tester.pump();
    await tester.runAsync(() =>
        precacheImage(image, tester.element(find.byType(ProductPhotoGallery))));
    await tester.pumpAndSettle();
    expect(image.attempts.value, greaterThanOrEqualTo(2));
    expect(find.byTooltip('Ampliar foto'), findsOneWidget);
    expect(find.text('No se pudo cargar la foto'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final scenario in [
    (size: const Size(320, 640), scale: 1.0, dark: false),
    (size: const Size(390, 844), scale: 1.6, dark: true),
    (size: const Size(568, 320), scale: 1.0, dark: false),
    (size: const Size(1440, 900), scale: 1.0, dark: false),
  ]) {
    testWidgets('gallery and viewer fit at $scenario', (tester) async {
      tester.view.physicalSize = scenario.size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      AppColors.brightness = scenario.dark ? Brightness.dark : Brightness.light;
      addTearDown(() => AppColors.brightness = Brightness.light);
      await _pumpGallery(tester,
          urls: const ['one', 'two', 'three'],
          scale: scenario.scale,
          dark: scenario.dark);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Ampliar foto'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Cerrar fotos'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
