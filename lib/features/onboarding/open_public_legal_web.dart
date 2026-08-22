import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/app_scaffold_messenger.dart';
import 'package:motolink_pro_app/app/config/public_legal_route.dart';
import 'package:motolink_pro_app/features/onboarding/public_legal_document_screen.dart';

/// Abre el documento en el Navigator (sin recargar). En web, `location.assign`
/// a `/?legal=privacy` deja la página en blanco con `flutter run`.
Future<void> openPublicLegal(
  BuildContext context,
  PublicLegalKind kind,
) async {
  final route = MaterialPageRoute<void>(
    settings: RouteSettings(name: '/?${PublicLegalRoute.queryFor(kind)}'),
    builder: (_) => PublicLegalDocumentScreen(kind: kind),
  );
  final root = rootNavigatorKey.currentState;
  if (root != null) {
    await root.push(route);
    return;
  }
  if (context.mounted) {
    await Navigator.of(context, rootNavigator: true).push(route);
  }
}
