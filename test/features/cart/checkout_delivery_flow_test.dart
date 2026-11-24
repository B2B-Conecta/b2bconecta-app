import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/features/cart/checkout_delivery_data.dart';
import 'package:motolink_pro_app/features/cart/mobile_checkout_model.dart';
import 'package:motolink_pro_app/features/cart/mobile_checkout_screen.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_model.dart';
import 'package:motolink_pro_app/features/orders/shared/order_delivery_stepper.dart';
import 'package:motolink_pro_app/features/orders/aliado/aliado_confirmar_recepcion_section.dart';
import 'mobile_checkout_test.dart' as fixture;

const saved = SavedDeliveryAddress(
    id: 'saved-one',
    label: 'Almacén',
    state: 'Miranda',
    city: 'Caracas',
    address: 'Zona industrial',
    mapsUrl: 'https://maps.app.goo.gl/saved',
    isDefault: true);
const pickup = CheckoutPickupOption(
    id: 'pickup-one',
    supplierId: 'one',
    label: 'Sede Valencia',
    state: 'Carabobo',
    city: 'Valencia',
    address: 'Local 12',
    mapsUrl: 'https://maps.app.goo.gl/pickup',
    instructions: 'Lunes a viernes de 9 a 5');

Future<void> press(WidgetTester tester, String text) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  final target = find.text(text);
  if (target.evaluate().isEmpty) {
    await tester.scrollUntilVisible(target, 180,
        scrollable: find.byType(Scrollable).first);
  }
  await tester.ensureVisible(target.first);
  await tester.pumpAndSettle();
  await tester.tap(target.first);
  await tester.pumpAndSettle();
}

void main() {
  Future<void> open(WidgetTester tester,
      {double width = 390,
      double scale = 1,
      Future<List<SavedDeliveryAddress>> Function()? loadAddresses,
      Future<SavedDeliveryAddress> Function(SavedDeliveryAddress)? saveAddress,
      Future<void> Function(String)? deleteAddress,
      Future<List<CheckoutPickupOption>> Function(String)? loadPickups,
      Future<String> Function(MobileCheckoutSubmission)? submit,
      bool settle = true}) async {
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!),
        home: MobileCheckoutScreen(
            profile: fixture.profile,
            lines: fixture.lines(),
            initialPayUsd: false,
            rate: 10,
            credits: const {},
            loadCarriers: (id, {state, city, latitude, longitude}) async =>
                [fixture.carrier(id)],
            loadAddresses: loadAddresses,
            saveAddress: saveAddress,
            deleteAddress: deleteAddress,
            loadPickups: loadPickups,
            submit: submit ?? (_) async => 'order-12345678')));
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  testWidgets('saved default address is used in carrier query and submission',
      (tester) async {
    MobileCheckoutSubmission? submitted;
    await open(tester,
        loadAddresses: () async => [saved],
        submit: (s) async {
          submitted = s;
          return 'order-12345678';
        });
    expect(find.text('Almacén · Predeterminada'), findsOneWidget);
    await press(tester, 'Continuar con la entrega →');
    expect(find.textContaining('Zona industrial'), findsWidgets);
    await press(tester, 'Revisar pedido →');
    await press(tester, 'Confirmar pedido');
    expect(submitted?.savedAddressId, 'saved-one');
    expect(submitted?.destination.useProfile, isFalse);
  });

  for (final scale in [1.0, 1.6]) {
    testWidgets(
        'pickup combines with delivery and survives review back at scale $scale',
        (tester) async {
      MobileCheckoutSubmission? submitted;
      await open(tester,
          width: 320,
          scale: scale,
          loadPickups: (id) async => id == 'one' ? [pickup] : [],
          submit: (s) async {
            submitted = s;
            return 'order-12345678';
          });
      await press(tester, 'Continuar con la entrega →');
      await press(tester, 'Retiro en tienda · Sede Valencia');
      expect(find.text('6.00 USD estimados'), findsWidgets);
      await press(tester, 'Revisar pedido →');
      expect(find.text('666.00 REF'), findsWidgets);
      await press(tester, 'Retiro sin costo');
      await press(tester, 'Cambiar entrega');
      await press(tester, 'Revisar pedido →');
      await press(tester, 'Confirmar pedido');
      expect(submitted?.pickups, {'one': 'pickup-one'});
      expect(submitted?.carriers.keys, orderedEquals(['two']));
      expect(submitted?.deliveryBySupplier, {
        'one': {'mode': 'PICKUP', 'location_id': 'pickup-one'}
      });
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('failed pickup query blocks confirmation until retry',
      (tester) async {
    var failing = true;
    await open(tester, loadPickups: (id) async {
      if (failing) throw StateError('offline');
      return [];
    });
    await press(tester, 'Continuar con la entrega →');
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Revisar pedido →'))
            .onPressed,
        isNull);
    failing = false;
    await press(tester, 'Reintentar transporte');
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Revisar pedido →'))
            .onPressed,
        isNotNull);
  });
  testWidgets(
      'save address is optional and persistence failure stays at address step',
      (tester) async {
    SavedDeliveryAddress? captured;
    var failing = true;
    await open(tester, saveAddress: (a) async {
      captured = a;
      if (failing) throw StateError('offline');
      return SavedDeliveryAddress(
          id: 'new-saved',
          label: a.label,
          state: a.state,
          city: a.city,
          address: a.address,
          mapsUrl: a.mapsUrl,
          isDefault: a.isDefault);
    });
    await press(tester, 'Otra dirección');
    for (final entry in {
      'Estado': 'Miranda',
      'Ciudad': 'Caracas',
      'Dirección y referencia': 'Almacén 22',
      'Enlace de Google Maps': 'https://maps.app.goo.gl/new'
    }.entries) {
      final field = find.widgetWithText(TextFormField, entry.key);
      if (field.evaluate().isEmpty) {
        await tester.scrollUntilVisible(field, 150,
            scrollable: find.byType(Scrollable).first);
      }
      await tester.ensureVisible(field);
      await tester.enterText(field, entry.value);
    }
    await press(tester, 'Guardar en mis direcciones');
    final label = find.widgetWithText(TextFormField, 'Nombre de la dirección');
    await tester.ensureVisible(label);
    await tester.enterText(label, 'Almacén nuevo');
    await press(tester, 'Continuar con la entrega →');
    expect(
        find.textContaining('No pudimos guardar la dirección'), findsOneWidget);
    expect(captured?.label, 'Almacén nuevo');
    failing = false;
    await press(tester, 'Continuar con la entrega →');
    expect(find.text('Revisar pedido →'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('late default address does not override a manual choice',
      (tester) async {
    final pending = Completer<List<SavedDeliveryAddress>>();
    await open(tester, loadAddresses: () => pending.future, settle: false);
    await tester.tap(find.text('Otra dirección'));
    pending.complete([saved]);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, 'Dirección y referencia'),
        findsOneWidget);
  });
  test('pickup totals do not count removed transport quotes', () {
    final totals = MobileCheckoutTotals(
        lines: fixture.lines(),
        payUsd: false,
        credits: const {},
        carriers: {
          'one': fixture.carrier('one'),
          'two': fixture.carrier('two')
        },
        supplierCount: 2,
        pickupSuppliers: {'one', 'two'});
    expect(totals.quotedShippingUsd, 0);
    expect(totals.shippingPending, isFalse);
    final mixed = MobileCheckoutTotals(
        lines: fixture.lines(),
        payUsd: false,
        credits: const {},
        carriers: {'two': fixture.carrier('two')},
        supplierCount: 2,
        pickupSuppliers: {'one'});
    expect(mixed.quotedShippingUsd, 6);
    expect(mixed.estimatedTotal, 666);
  });
  testWidgets(
      'saved addresses can be edited and deleted without changing profile',
      (tester) async {
    SavedDeliveryAddress? updated;
    String? removed;
    await open(tester,
        loadAddresses: () async => const [saved],
        saveAddress: (value) async {
          updated = value;
          return value;
        },
        deleteAddress: (id) async {
          removed = id;
        });
    await press(tester, 'Editar');
    final label = find.widgetWithText(TextFormField, 'Nombre de la dirección');
    await tester.scrollUntilVisible(label, 180,
        scrollable: find.byType(Scrollable).first);
    await tester.enterText(label, 'Almacén actualizado');
    await press(tester, 'Continuar con la entrega →');
    expect(updated?.id, saved.id);
    expect(updated?.label, 'Almacén actualizado');
    await press(tester, 'Cambiar dirección');
    await press(tester, 'Eliminar');
    await tester.tap(find.widgetWithText(FilledButton, 'Eliminar'));
    await tester.pumpAndSettle();
    expect(removed, saved.id);
    expect(find.text('Almacén actualizado · Predeterminada'), findsNothing);
    expect(find.textContaining(fixture.profile.businessName!), findsWidgets);
    expect(tester.takeException(), isNull);
  });
  testWidgets('recovered order success never displays the current draft totals',
      (tester) async {
    await open(tester,
        submit: (_) async =>
            throw const MobileCheckoutRecovered('old-order-12345678'));
    await press(tester, 'Continuar con la entrega →');
    await press(tester, 'Revisar pedido →');
    await press(tester, 'Confirmar pedido');
    expect(find.text('Recuperamos tu pedido anterior'), findsOneWidget);
    expect(find.text('Ver pedido'), findsOneWidget);
    expect(find.text('Resumen'), findsNothing);
  });
  testWidgets('ready pickup can be received without a transit state',
      (tester) async {
    final line = TransactionRequestModel.fromJson({
      'id': 'pickup-order',
      'aliado_id': 'ally',
      'importador_id': 'supplier',
      'product_id': 'part',
      'status': 'pedido_listo',
      'cantidad': 5,
      'precio_total_usd': 100,
      'precio_unitario_aliado': 20,
      'precio_unitario_proveedor': 18,
      'customer_delivery_mode': 'PICKUP',
      'customer_delivery_snapshot': {
        'label': 'Sede',
        'direccion': 'Local original'
      },
      'carrier_decision': 'skipped'
    });
    expect(line.puedeConfirmarRecepcionAliado, isTrue);
    expect(line.importadorPuedeConfirmarRecoleccion, isFalse);
    final blocks = aliadoRecepcionBloquesDesdePedido(
        lines: [line],
        lineaPuedeConfirmar: (r) => r.puedeConfirmarRecepcionAliado,
        chunkPuedeConfirmar: (_) => true,
        busyKeyForChunk: (_) => null,
        entregaBusyId: null,
        onConfirmarLinea: (_) {},
        onConfirmarChunk: (_) {});
    expect(blocks.single.puedeConfirmar, isTrue);
    await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: OrderDeliveryStepper(lines: [line]))));
    expect(find.text('Listo para retirar'), findsOneWidget);
    expect(find.text('En camino'), findsNothing);
  });
}
