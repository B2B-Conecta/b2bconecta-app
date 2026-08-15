// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:flutter/widgets.dart';

import 'package:motolink_pro_app/app/config/public_legal_route.dart';

Future<void> openPublicLegal(
  BuildContext context,
  PublicLegalKind kind,
) async {
  final origin = html.window.location.origin;
  html.window.location.assign('$origin/?${PublicLegalRoute.queryFor(kind)}');
}
