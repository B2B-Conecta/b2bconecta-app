import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Engancha el [State] al [Theme] de MaterialApp.
///
/// Las pestañas viven en [IndexedStack] con la misma instancia de widget; sin
/// depender de [Theme], no se redibujan al cambiar claro/oscuro y
/// [AppColors] queda “congelado” (p. ej. buscador oscuro en modo claro).
mixin SyncAppColorsToTheme<T extends StatefulWidget> on State<T> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    AppColors.brightness = Theme.of(context).brightness;
  }
}
