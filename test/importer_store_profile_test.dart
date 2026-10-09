import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/features/catalog/catalog_filters.dart';
import 'package:motolink_pro_app/features/catalog/importer_catalog_logo.dart';
import 'package:motolink_pro_app/features/catalog/importer_store_profile.dart';
import 'package:motolink_pro_app/features/catalog/importer_store_profile_screen.dart';
import 'package:motolink_pro_app/features/catalog/part_model.dart';
import 'package:motolink_pro_app/features/catalog/store_supplier_chat.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';

const _importerA = '11111111-1111-1111-1111-111111111111';
const _importerB = '22222222-2222-2222-2222-222222222222';
const _missingId = '00000000-0000-0000-0000-000000000000';

const _viewer = ProfileModel(
  id: 'aliado-1',
  role: 'aliado',
  businessName: 'Repuestos del Este',
);

ImporterStoreProfile _profile({
  String id = _importerA,
  String name = 'Mayorista Andino',
}) {
  return ImporterStoreProfile(
    id: id,
    businessName: name,
    estado: 'Miranda',
    ciudad: 'Caracas',
    rif: 'J-123',
    phone: '04141234567',
    minOrderAmountRef: 100,
    ratingAvg: 4.5,
    ratingCount: 12,
  );
}

PartModel _part({
  required String id,
  required String ownerId,
  required String nombre,
  String? category,
  bool isActive = true,
}) {
  return PartModel(
    id: id,
    ownerId: ownerId,
    nombre: nombre,
    precio: 10,
    stock: 20,
    category: category,
    isActive: isActive,
  );
}

ImporterStoreCatalogSource _source({
  Future<ImporterStoreProfile?> Function(String id)? fetchProfile,
  Future<List<String>> Function(String id)? fetchCategories,
  Future<List<PartModel>> Function({
    required int limit,
    required int offset,
    required CatalogFilters filters,
  })? fetchParts,
  Future<PartModel?> Function({
    required String importerId,
    required String productId,
  })? fetchVisibleProduct,
}) {
  return ImporterStoreCatalogSource(
    fetchProfile: fetchProfile ??
        (id) async => id == _importerA ? _profile() : null,
    fetchCategories: fetchCategories ?? ((_) async => const ['Frenos', 'Motor']),
    fetchParts: fetchParts ??
        ({
          required int limit,
          required int offset,
          required CatalogFilters filters,
        }) async =>
            const [],
    fetchVisibleProduct: fetchVisibleProduct,
  );
}

Future<void> _pumpStore(
  WidgetTester tester, {
  required ImporterStoreCatalogSource source,
  String importerId = _importerA,
  ProfileModel viewer = _viewer,
  Future<void> Function(BuildContext context)? onOpenSupplierChat,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: ImporterStoreProfileScreen(
        importerId: importerId,
        viewer: viewer,
        catalogSource: source,
        onOpenSupplierChat: onOpenSupplierChat,
      ),
    ),
  );
}

void main() {
  test('fromJson lee la ficha del mayorista seleccionado', () {
    final profile = ImporterStoreProfile.fromJson({
      'id': _importerA,
      'business_name': 'Mayorista Andino',
      'rif': 'J-123',
      'phone': '04141234567',
      'estado': 'Miranda',
      'ciudad': 'Caracas',
      'direccion': 'Av. Principal',
      'rating_avg_received_rolling100': 4.8,
      'rating_count_received_rolling100': 20,
      'min_order_amount_ref': 50,
      'min_order_currency': 'usd',
      'pago_solo_divisas': true,
      'accepted_pago_metodos': ['zelle_divisas', 'usdt'],
    });

    expect(profile.id, _importerA);
    expect(profile.displayName, 'Mayorista Andino');
    expect(profile.locationLine, 'Miranda · Caracas');
    expect(profile.ratingAvg, 4.8);
    expect(profile.hasMinOrder, isTrue);
    expect(profile.pagoSoloDivisas, isTrue);
    expect(profile.pagoMetodoLabelsEs, isNotEmpty);
  });

  test('la consulta de vitrina exige mayorista, activos y categoría propia', () {
    final filters = CatalogFilters.importerStore(
      importerId: _importerA,
      category: 'Motor',
    );
    expect(filters.ownerId, _importerA);
    expect(filters.onlyActiveProducts, isTrue);
    expect(filters.effectiveOwnerIds, [_importerA]);
    expect(filters.category, 'Motor');
    expect(filters.hasAnyFilter, isTrue);
  });

  test('solo retiene productos activos y visibles de ese mayorista', () {
    final kept = retainImporterStoreCatalogParts(
      importerId: _importerA,
      parts: [
        _part(id: 'a1', ownerId: _importerA, nombre: 'Disco A', category: 'Frenos'),
        _part(id: 'b1', ownerId: _importerB, nombre: 'Disco B', category: 'Frenos'),
        _part(
          id: 'a-off',
          ownerId: _importerA,
          nombre: 'Pausado',
          isActive: false,
        ),
      ],
    );
    expect(kept.map((p) => p.id), ['a1']);
  });

  test('las categorías no mezclan productos de otro mayorista', () {
    final kept = retainImporterStoreCatalogParts(
      importerId: _importerA,
      category: 'Motor',
      parts: [
        _part(id: 'a-m', ownerId: _importerA, nombre: 'Bujía', category: 'Motor'),
        _part(id: 'a-f', ownerId: _importerA, nombre: 'Pastilla', category: 'Frenos'),
        _part(id: 'b-m', ownerId: _importerB, nombre: 'Aceite B', category: 'Motor'),
      ],
    );
    expect(kept.map((p) => p.id), ['a-m']);
  });

  test('manipular el ID del producto de otro mayorista no abre la ficha', () {
    expect(
      catalogPartBelongsToImporterStore(
        importerId: _importerA,
        ownerId: _importerB,
        isActive: true,
      ),
      isFalse,
    );
    expect(
      catalogPartBelongsToImporterStore(
        importerId: _importerA,
        ownerId: _importerA,
        isActive: false,
      ),
      isFalse,
    );
    expect(
      catalogPartBelongsToImporterStore(
        importerId: _importerA,
        ownerId: _importerA,
        isActive: true,
      ),
      isTrue,
    );
  });

  testWidgets('estado de carga mientras llega el perfil', (tester) async {
    final gate = Completer<ImporterStoreProfile?>();
    await _pumpStore(
      tester,
      source: _source(fetchProfile: (_) => gate.future),
    );
    await tester.pump();
    expect(find.byKey(const Key('importer-store-loading')), findsOneWidget);
    gate.complete(_profile());
    await tester.pumpAndSettle();
  });

  testWidgets('un ID inexistente muestra el estado 404', (tester) async {
    await _pumpStore(
      tester,
      importerId: _missingId,
      source: _source(fetchProfile: (_) async => null),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('importer-store-not-found')), findsOneWidget);
    expect(find.text('No encontramos este mayorista.'), findsOneWidget);
  });

  testWidgets('un error de red muestra reintento', (tester) async {
    await _pumpStore(
      tester,
      source: _source(fetchProfile: (_) async => throw Exception('timeout')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('importer-store-error')), findsOneWidget);
    expect(find.text('No se pudo cargar el perfil.'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
  });

  testWidgets('catálogo vacío del mayorista válido', (tester) async {
    await _pumpStore(tester, source: _source());
    await tester.pumpAndSettle();
    expect(find.text('Mayorista Andino'), findsWidgets);
    expect(find.byType(ImporterCatalogLogo), findsNothing);
    expect(find.byKey(const Key('importer-store-empty')), findsOneWidget);
    expect(
      find.text('Este mayorista aún no tiene productos en vitrina.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'el minorista abre el perfil y solo ve productos de ese mayorista',
    (tester) async {
      await _pumpStore(
        tester,
        source: _source(
          fetchParts: ({
            required int limit,
            required int offset,
            required CatalogFilters filters,
          }) async {
            expect(filters.ownerId, _importerA);
            expect(filters.onlyActiveProducts, isTrue);
            return [
              _part(
                id: 'a1',
                ownerId: _importerA,
                nombre: 'Pastilla Andino',
                category: 'Frenos',
              ),
              _part(
                id: 'b1',
                ownerId: _importerB,
                nombre: 'Pastilla Ajeno',
                category: 'Frenos',
              ),
              _part(
                id: 'a-off',
                ownerId: _importerA,
                nombre: 'Oculto',
                isActive: false,
              ),
            ];
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Mayorista Andino'), findsWidgets);
      expect(find.text('Pastilla Andino'), findsOneWidget);
      expect(find.text('Pastilla Ajeno'), findsNothing);
      expect(find.text('Oculto'), findsNothing);
    },
  );

  testWidgets('filtrar por categoría conserva el mayorista', (tester) async {
    final calls = <CatalogFilters>[];
    await _pumpStore(
      tester,
      source: _source(
        fetchParts: ({
          required int limit,
          required int offset,
          required CatalogFilters filters,
        }) async {
          calls.add(filters);
          if (filters.category == 'Motor') {
            return [
              _part(
                id: 'a-m',
                ownerId: _importerA,
                nombre: 'Bujía Andino',
                category: 'Motor',
              ),
            ];
          }
          return [
            _part(
              id: 'a-f',
              ownerId: _importerA,
              nombre: 'Pastilla Andino',
              category: 'Frenos',
            ),
          ];
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Pastilla Andino'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Motor'));
    await tester.pumpAndSettle();

    expect(calls.last.ownerId, _importerA);
    expect(calls.last.category, 'Motor');
    expect(find.text('Bujía Andino'), findsOneWidget);
    expect(find.text('Pastilla Andino'), findsNothing);
  });

  testWidgets('paginación pide la siguiente página con el mismo mayorista',
      (tester) async {
    final offsets = <int>[];
    final limits = <int>[];
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpStore(
      tester,
      source: _source(
        fetchParts: ({
          required int limit,
          required int offset,
          required CatalogFilters filters,
        }) async {
          expect(filters.ownerId, _importerA);
          offsets.add(offset);
          limits.add(limit);
          if (offset > 0) return const [];
          return List<PartModel>.generate(
            limit,
            (i) => _part(
              id: 'a-$i',
              ownerId: _importerA,
              nombre: 'Repuesto $i',
              category: 'Motor',
            ),
          );
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(offsets, [0]);
    expect(limits, [10]);
    expect(find.text('Repuesto 0'), findsOneWidget);
    expect(find.text('Repuesto 9'), findsOneWidget);

    await tester.tap(find.byTooltip('Siguiente'));
    await tester.pumpAndSettle();
    expect(offsets, [0, 10]);
    expect(limits, [10, 10]);
  });

  testWidgets(
    'un producto de otro mayorista no se abre desde la vitrina',
    (tester) async {
      var visibleLookups = 0;
      await _pumpStore(
        tester,
        source: _source(
          fetchParts: ({
            required int limit,
            required int offset,
            required CatalogFilters filters,
          }) async =>
              [
            _part(
              id: 'leak',
              ownerId: _importerB,
              nombre: 'Producto filtrado',
            ),
          ],
          fetchVisibleProduct: ({
            required String importerId,
            required String productId,
          }) async {
            visibleLookups++;
            expect(importerId, _importerA);
            return null;
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Producto filtrado'), findsNothing);
      expect(visibleLookups, 0);
    },
  );

  test('el mensaje de la vitrina solo lo ve la tienda ajena', () {
    expect(
      showStoreSupplierChatButton(
        viewerRole: 'aliado',
        viewerId: 'aliado-1',
        importerId: _importerA,
      ),
      isTrue,
    );
    expect(
      showStoreSupplierChatButton(
        viewerRole: 'importador',
        viewerId: _importerA,
        importerId: _importerA,
      ),
      isFalse,
    );
    expect(
      showStoreSupplierChatButton(
        viewerRole: 'aliado',
        viewerId: _importerA,
        importerId: _importerA,
      ),
      isFalse,
    );
  });

  testWidgets('abrir el mensaje no recarga la vitrina', (tester) async {
    var profileLoads = 0;
    var opened = 0;
    await _pumpStore(
      tester,
      source: _source(
        fetchProfile: (id) async {
          profileLoads++;
          return _profile(id: id);
        },
      ),
      onOpenSupplierChat: (_) async {
        opened++;
      },
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('store-supplier-chat')), findsOneWidget);
    expect(profileLoads, 1);

    await tester.tap(find.byKey(const Key('store-supplier-chat')));
    await tester.pumpAndSettle();

    expect(opened, 1);
    expect(profileLoads, 1);
    expect(find.text('Mayorista Andino'), findsWidgets);
    expect(find.text('Frenos'), findsOneWidget);
  });

  testWidgets('el proveedor no ve el botón en su vitrina', (tester) async {
    await _pumpStore(
      tester,
      viewer: const ProfileModel(
        id: _importerA,
        role: 'importador',
        businessName: 'Mayorista Andino',
      ),
      source: _source(),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('store-supplier-chat')), findsNothing);
  });
}
