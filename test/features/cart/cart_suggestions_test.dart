import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/features/cart/cart_screen.dart';
import 'package:motolink_pro_app/features/cart/cart_service.dart';
import 'package:motolink_pro_app/features/cart/cart_suggestions.dart';
import 'package:motolink_pro_app/features/catalog/part_model.dart';
import 'package:motolink_pro_app/features/kyc/account_access_status.dart';
import 'package:motolink_pro_app/features/logistics/envio_politica.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';

PartModel _part({
  required String id,
  required String nombre,
  required String ownerId,
  String? category,
  String? sku,
  double precio = 10,
  int stock = 40,
  int? paidOrders,
  double? rating,
  bool verified = false,
  String envio = EnvioPolitica.noDefinido,
  double minOrderAmount = 0,
  String businessName = 'Proveedor',
}) {
  return PartModel(
    id: id,
    nombre: nombre,
    ownerId: ownerId,
    ownerBusinessName: businessName,
    category: category,
    sku: sku,
    precio: precio,
    stock: stock,
    minOrderQty: 1,
    ownerCatalogPaidOrders30d: paidOrders,
    ownerRatingAvg: rating,
    ownerRatingCount: rating == null ? null : 12,
    ownerCatalogVerifiedAt:
        verified ? DateTime.utc(2026, 1, 1) : null,
    ownerEnvioTipo: envio,
    ownerMinOrderAmountRef: minOrderAmount,
  );
}

void main() {
  test('cauchos sugieren lubricantes y válvulas, líderes primero', () {
    final cart = [
      _part(
        id: 'tire',
        nombre: 'Caucho 110/90',
        ownerId: 'local',
        category: 'Cauchos',
        sku: 'CAU-110',
        businessName: 'Local',
      ),
    ];
    final weakOil = _part(
      id: 'oil-weak',
      nombre: 'Aceite básico',
      ownerId: 'slow',
      category: 'Lubricantes',
      sku: 'ACE-1',
      paidOrders: 0,
      businessName: 'Taller lento',
    );
    final leaderValve = _part(
      id: 'valve-leader',
      nombre: 'Válvula metálica',
      ownerId: 'top',
      category: 'Válvulas',
      sku: 'VAL-1',
      paidOrders: 20,
      rating: 4.8,
      verified: true,
      envio: EnvioPolitica.aparte,
      minOrderAmount: 40,
      businessName: 'Mayorista líder',
    );
    final sameTire = _part(
      id: 'tire',
      nombre: 'Caucho 110/90',
      ownerId: 'local',
      category: 'Cauchos',
      sku: 'CAU-110',
    );
    final unrelated = _part(
      id: 'helmet',
      nombre: 'Casco',
      ownerId: 'other',
      category: 'Cascos',
      paidOrders: 1,
    );
    final leaderOnly = _part(
      id: 'spark',
      nombre: 'Bujía iridium',
      ownerId: 'top',
      category: 'Bujías',
      paidOrders: 15,
      rating: 4.6,
      businessName: 'Mayorista líder',
    );

    final ranked = rankCartSuggestions(
      cartParts: cart,
      candidates: [unrelated, weakOil, sameTire, leaderOnly, leaderValve],
    );

    expect(ranked.map((row) => row.part.id).toList(), [
      'valve-leader',
      'oil-weak',
      'spark',
    ]);
    expect(ranked.first.kind, CartSuggestionKind.complement);
    expect(ranked.first.leadingSupplier, isTrue);
    expect(ranked.first.differentSupplier, isTrue);
    expect(ranked.first.logisticsNote, contains('Flete adicional'));
    expect(ranked.first.logisticsNote, contains('Mín. propio'));
    expect(ranked[1].differentSupplier, isTrue);
    expect(ranked[1].logisticsNote, isNot(contains('adicional')));
    expect(
      ranked.last.kind,
      CartSuggestionKind.leadingSupplier,
    );
  });

  test('el mismo proveedor muestra badge de pedido unificado', () {
    final cart = [
      _part(
        id: 'engine',
        nombre: 'Kit de motor',
        ownerId: 'same',
        category: 'Motores',
      ),
    ];
    final filter = _part(
      id: 'filter',
      nombre: 'Filtro de aceite',
      ownerId: 'same',
      category: 'Filtros',
      businessName: 'Mismo mayorista',
      envio: EnvioPolitica.incluido,
    );
    final ranked = rankCartSuggestions(cartParts: cart, candidates: [filter]);
    expect(ranked, hasLength(1));
    expect(ranked.single.differentSupplier, isFalse);
    expect(ranked.single.logisticsNote, 'Mismo proveedor · Flete incluido');
    expect(ranked.single.kind, CartSuggestionKind.complement);
  });

  test('la consulta sale de los SKUs y categorías del carrito', () {
    final query = CartSuggestionQuery.fromParts([
      _part(
        id: 'tire',
        nombre: 'Llanta trasera',
        ownerId: 'a',
        category: 'Llantas',
        sku: 'LL-20',
      ),
    ]);
    expect(query.productIds, ['tire']);
    expect(query.skus, ['LL-20']);
    expect(query.categoryFragments, contains('lubricante'));
    expect(query.categoryFragments, contains('valvula'));
  });

  testWidgets('añadir una sugerencia actualiza el subtotal sin salir del carrito',
      (tester) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final cart = CartService.instance..clear();
    addTearDown(cart.clear);
    cart.addOrIncrement(
      _part(
        id: 'tire',
        nombre: 'Caucho 110/90',
        ownerId: 'local',
        category: 'Cauchos',
        sku: 'CAU-110',
        precio: 10,
        businessName: 'Local',
      ),
      delta: 5,
      precioUnitarioAliadoRef: 10,
    );

    final suggestion = _part(
      id: 'valve',
      nombre: 'Válvula metálica',
      ownerId: 'top',
      category: 'Válvulas',
      sku: 'VAL-1',
      precio: 20,
      paidOrders: 12,
      rating: 4.8,
      verified: true,
      envio: EnvioPolitica.aparte,
      businessName: 'Mayorista líder',
    );

    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: CartScreen(
        profile: const ProfileModel(
          id: 'ally',
          role: 'aliado',
          accountAccessStatus: AccountAccessStatus.active,
        ),
        liveTasaBcv: 10,
        loadSuggestionCandidates: (_) async => [suggestion],
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Sugeridos'), findsOneWidget);
    expect(find.text('Válvula metálica'), findsOneWidget);
    expect(find.text('Mayorista líder'), findsOneWidget);
    expect(find.text('Añadir al pedido'), findsOneWidget);
    expect(find.text('Pedido aparte'), findsOneWidget);
    expect(find.text('Detalle'), findsOneWidget);
    await tester.ensureVisible(find.text('Detalle'));
    await tester.tap(find.text('Detalle'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Flete adicional'), findsOneWidget);
    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();
    expect(find.text('Bs 500,00'), findsWidgets);
    expect(find.text('Continuar con la entrega'), findsOneWidget);

    await tester.ensureVisible(find.text('Añadir al pedido'));
    await tester.tap(find.text('Añadir al pedido'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Añadido'), findsOneWidget);
    expect(find.text('Continuar con la entrega'), findsOneWidget);
    expect(cart.lines.map((line) => line.part.id), contains('valve'));
    expect(find.text('Bs 700,00'), findsWidgets);

    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Añadido'), findsNothing);
    expect(find.text('Válvula metálica'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('en escritorio las sugerencias usan carrusel con fichas grandes',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final cart = CartService.instance..clear();
    addTearDown(cart.clear);
    cart.addOrIncrement(
      _part(
        id: 'tire',
        nombre: 'Caucho 110/90',
        ownerId: 'local',
        category: 'Cauchos',
        precio: 10,
      ),
      delta: 1,
      precioUnitarioAliadoRef: 10,
    );

    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: CartScreen(
        profile: const ProfileModel(
          id: 'ally',
          role: 'aliado',
          accountAccessStatus: AccountAccessStatus.active,
        ),
        liveTasaBcv: 10,
        suggestionAutoPlay: false,
        loadSuggestionCandidates: (_) async => [
          for (var i = 0; i < 5; i++)
            _part(
              id: 'oil-$i',
              nombre: 'Aceite 20W50 $i',
              ownerId: 'top',
              category: 'Lubricantes',
              precio: 8,
              paidOrders: 10,
              businessName: 'Mayorista líder',
            ),
        ],
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Siguiente'), findsOneWidget);
    expect(find.text('Aceite 20W50 0'), findsAtLeastNWidgets(1));
    expect(tester.takeException(), isNull);
  });
}
