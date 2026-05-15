import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth/auth_gate.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  final url = dotenv.env['NEXT_PUBLIC_SUPABASE_URL']?.trim();
  final anonKey = (dotenv.env['NEXT_PUBLIC_SUPABASE_PUBLISHABLE_DEFAULT_KEY'] ??
          dotenv.env['NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY'])
      ?.trim();

  if (url == null || url.isEmpty || anonKey == null || anonKey.isEmpty) {
    throw StateError(
      'Missing Supabase configuration. Set NEXT_PUBLIC_SUPABASE_URL and '
      'NEXT_PUBLIC_SUPABASE_PUBLISHABLE_DEFAULT_KEY (or '
      'NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY) in .env',
    );
  }

  await Supabase.initialize(
    url: url,
    anonKey: anonKey,
    // PKCE + deep links: necesario para que el enlace del correo (recuperación) abra sesión en la app.
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
      detectSessionInUri: true,
    ),
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MotoLink',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const AuthGate(),
    );
  }
}
