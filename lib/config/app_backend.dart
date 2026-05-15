import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Base de datos greenfield MotoConecta (tablas reducidas, sin `sub_orders` ni `payment_schedule`).
///
/// Activa en `.env`: `MOTO_CONECTA=true` (o `NEXT_PUBLIC_MOTO_CONECTA=true`).
bool get kAppUsesMotoConectaBackend {
  for (final key in const ['MOTO_CONECTA', 'NEXT_PUBLIC_MOTO_CONECTA']) {
    final v = dotenv.env[key]?.trim().toLowerCase();
    if (v == 'true' || v == '1' || v == 'yes') return true;
  }
  return false;
}
