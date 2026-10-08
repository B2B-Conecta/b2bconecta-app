import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/features/orders/aliado/aliado_expandable_order_card.dart';
import 'package:motolink_pro_app/features/orders/shared/order_card_direct_summary.dart';
import 'package:motolink_pro_app/features/orders/shared/qty_adjustment_status.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_model.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_status.dart';
import 'package:motolink_pro_app/features/profile/app_home_role.dart';
import 'package:motolink_pro_app/features/profile/profile_role_labels.dart';

TransactionRequestModel _line({
  required String id,
  String aliadoId = 'aliado-1',
  String ownerId = 'imp-1',
  String status = TransactionRequestStatus.pendiente,
  int cantidad = 2,
  double precioTotal = 20,
  String? productName,
  String? sku,
  List<String> imageUrls = const [],
  String? importerName,
  String? aliadoName,
  String? aliadoCiudad,
  String? ownerCiudad,
  String? qtyAdjustmentStatus,
  String? aliadoPhone,
  String? ownerPhone,
}) {
  return TransactionRequestModel(
    id: id,
    aliadoId: aliadoId,
    productId: 'p-$id',
    ownerId: ownerId,
    status: status,
    cantidad: cantidad,
    precioUnitarioProveedor: 8,
    precioUnitarioAliado: 10,
    precioTotal: precioTotal,
    precioBaseAliadoTotal: precioTotal,
    productName: productName,
    productSku: sku,
    productImageUrls: imageUrls,
    ownerBusinessName: importerName,
    aliadoBusinessName: aliadoName,
    aliadoCiudad: aliadoCiudad,
    ownerCiudad: ownerCiudad,
    qtyAdjustmentStatus: qtyAdjustmentStatus,
    aliadoPhone: aliadoPhone,
    ownerPhone: ownerPhone,
  );
}

void main() {
  test('aliado sees wholesalers only; importador sees retailer only', () {
    final lines = [
      _line(
        id: 'a',
        productName: 'Cadena',
        sku: 'CAD-1',
        cantidad: 3,
        importerName: 'Delta Mayorista',
        aliadoName: 'Taller Ruices',
        ownerPhone: '0414-0000000',
        aliadoPhone: '0412-1111111',
      ),
    ];

    final asAliado = orderCardRelatedParties(
      lines: lines,
      viewerRole: AppHomeRole.aliado,
    );
    expect(asAliado, hasLength(1));
    expect(asAliado.single.roleLabel, ProfileRoleLabels.labelEs('importador'));
    expect(asAliado.single.displayName, 'Delta Mayorista');

    final asImporter = orderCardRelatedParties(
      lines: lines,
      viewerRole: AppHomeRole.importador,
    );
    expect(asImporter, hasLength(1));
    expect(asImporter.single.roleLabel, ProfileRoleLabels.aliadoEs);
    expect(asImporter.single.displayName, 'Taller Ruices');
    expect(
      asImporter.map((p) => p.displayName),
      isNot(contains('Delta Mayorista')),
    );

    final asAdmin = orderCardRelatedParties(
      lines: lines,
      viewerRole: AppHomeRole.administrador,
    );
    expect(asAdmin.map((p) => p.displayName), [
      'Taller Ruices',
      'Delta Mayorista',
    ]);
  });

  test('does not invent an external vendor party', () {
    final parties = orderCardRelatedParties(
      lines: [_line(id: 'a', importerName: 'Delta', aliadoName: 'Taller')],
      viewerRole: AppHomeRole.administrador,
    );
    expect(parties.map((p) => p.roleLabel), [
      ProfileRoleLabels.aliadoEs,
      ProfileRoleLabels.labelEs('importador'),
    ]);
  });

  test('aliado multi-importer checkout lists each wholesaler once', () {
    final lines = [
      _line(
        id: 'a',
        ownerId: 'imp-a',
        importerName: 'Delta',
        productName: 'Cadena',
        cantidad: 1,
      ),
      _line(
        id: 'b',
        ownerId: 'imp-b',
        importerName: 'Cúcuta',
        productName: 'Aceite',
        cantidad: 4,
      ),
    ];
    final parties = orderCardRelatedParties(
      lines: lines,
      viewerRole: AppHomeRole.aliado,
    );
    expect(parties.map((p) => p.displayName), ['Delta', 'Cúcuta']);

    final products = orderCardProductPeeks(lines: lines);
    expect(products, hasLength(2));
    expect(products.map((p) => p.name), ['Cadena', 'Aceite']);
    expect(products.map((p) => p.quantity), [1, 4]);
  });

  test('historical rows without names or images stay renderable', () {
    final lines = [_line(id: 'legacy')];
    final parties = orderCardRelatedParties(
      lines: lines,
      viewerRole: AppHomeRole.aliado,
    );
    expect(parties.single.displayName, ProfileRoleLabels.labelEs('importador'));

    final products = orderCardProductPeeks(lines: lines);
    expect(products.single.name, 'Producto');
    expect(products.single.imageUrl, isNull);
    expect(products.single.quantity, 2);
  });

  test('parses image_urls from the products embed without extra requests', () {
    final m = TransactionRequestModel.fromJson({
      'id': 'tr-1',
      'aliado_id': 'al-1',
      'product_id': 'p-1',
      'importador_id': 'im-1',
      'status': 'pendiente',
      'cantidad': 4,
      'precio_total_usd': 40,
      'precio_unitario_aliado': 10,
      'precio_unitario_proveedor': 8,
      'precio_base_aliado_total': 40,
      'products': {
        'name': 'Filtro',
        'sku': 'FIL-1',
        'image_urls': ['https://cdn.example/filtro.jpg'],
      },
      'aliado': {'business_name': 'Taller Norte'},
      'importador': {'business_name': 'Mayorista Delta'},
    });
    expect(m.productName, 'Filtro');
    expect(m.productSku, 'FIL-1');
    expect(m.productImageUrls, ['https://cdn.example/filtro.jpg']);
    expect(m.aliadoBusinessName, 'Taller Norte');
    expect(m.ownerBusinessName, 'Mayorista Delta');

    final peeks = orderCardProductPeeks(lines: [m]);
    expect(peeks.single.imageUrl, 'https://cdn.example/filtro.jpg');
    expect(peeks.single.sku, 'FIL-1');
    expect(peeks.single.quantity, 4);
  });

  test('qty adjustment pending is the only line-level status shown', () {
    final pending = orderCardProductPeeks(
      lines: [
        _line(
          id: 'a',
          productName: 'Kit',
          qtyAdjustmentStatus: QtyAdjustmentStatus.pendienteAliado,
        ),
      ],
    );
    expect(pending.single.lineStatusLabel, 'Ajuste pendiente');

    final accepted = orderCardProductPeeks(
      lines: [
        _line(
          id: 'b',
          productName: 'Kit',
          qtyAdjustmentStatus: QtyAdjustmentStatus.aceptado,
        ),
      ],
    );
    expect(accepted.single.lineStatusLabel, isNull);
  });

  test('initials fallback for names without avatar', () {
    expect(orderCardPartyInitials('Taller Ruices'), 'TR');
    expect(orderCardPartyInitials('Delta'), 'DE');
    expect(orderCardPartyInitials('  '), '?');
  });

  testWidgets('summary shows users and products without an expand control',
      (tester) async {
    final lines = [
      _line(
        id: 'a',
        productName: 'Cadena DID',
        sku: 'DID-428',
        cantidad: 5,
        precioTotal: 52,
        importerName: 'Importadora Delta',
        aliadoName: 'Taller Los Ruices',
        aliadoPhone: '0412-5555555',
      ),
      _line(
        id: 'b',
        ownerId: 'imp-2',
        productName: 'Aceite 20W50',
        cantidad: 1,
        precioTotal: 8,
        importerName: 'Mayorista Cúcuta',
        aliadoName: 'Taller Los Ruices',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            child: OrderCardDirectSummary(
              lines: lines,
              viewerRole: AppHomeRole.aliado,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Importadora Delta'), findsOneWidget);
    expect(find.text('Mayorista Cúcuta'), findsOneWidget);
    expect(find.text('Cadena DID'), findsOneWidget);
    expect(find.text('Aceite 20W50'), findsOneWidget);
    expect(find.textContaining('×5'), findsOneWidget);
    expect(find.text('DID-428'), findsOneWidget);
    expect(find.text('0412-5555555'), findsNothing);
    expect(find.text(ProfileRoleLabels.aliadoEs), findsNothing);
    expect(find.text(ProfileRoleLabels.labelEs('importador')), findsNothing);
    expect(find.text('Expandir'), findsNothing);
    expect(find.byIcon(Icons.expand_more), findsNothing);
  });

  testWidgets('collapsed aliado card shows parties, products, total and chat',
      (tester) async {
    final request = _line(
      id: 'ord-1',
      productName: 'Pastillas freno',
      sku: 'PF-9',
      cantidad: 6,
      precioTotal: 90,
      importerName: 'Ruedas del Este',
      aliadoName: 'Moto Center',
      status: TransactionRequestStatus.enPreparacion,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AliadoExpandableOrderCard(
            request: request,
            expanded: false,
            onToggle: () {},
            statusLabel: 'En preparación',
          ),
        ),
      ),
    );

    expect(find.text('Ruedas del Este'), findsWidgets);
    expect(find.text('Pastillas freno'), findsWidgets);
    expect(find.textContaining('×6'), findsWidgets);
    expect(find.text('En preparación'), findsOneWidget);
    expect(find.text('Ver detalle y seguimiento'), findsOneWidget);
    expect(
      find.textContaining('Abra el detalle para ver el avance'),
      findsOneWidget,
    );
    expect(find.byTooltip('Chat del pedido'), findsOneWidget);
    expect(find.byIcon(Icons.expand_more), findsOneWidget);
    expect(find.byIcon(Icons.expand_less), findsNothing);
  });

  testWidgets('long names wrap inside a narrow mobile width', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OrderCardDirectSummary(
            lines: [
              _line(
                id: 'a',
                productName:
                    'Kit de transmisión extra largo para motocicleta de alto cilindraje',
                importerName:
                    'Distribuidora Internacional de Repuestos del Occidente C.A.',
                aliadoName:
                    'Taller Mecánico Especializado Los Ruices de Caracas',
                cantidad: 12,
              ),
            ],
            viewerRole: AppHomeRole.administrador,
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Distribuidora Internacional'), findsOneWidget);
    expect(find.textContaining('Kit de transmisión'), findsOneWidget);
  });
}
