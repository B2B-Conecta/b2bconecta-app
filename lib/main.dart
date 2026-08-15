import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:motolink_pro_app/app/app_scaffold_messenger.dart';
import 'package:motolink_pro_app/core/auth/auth_gate.dart';
import 'package:motolink_pro_app/core/notifications/push_notification_service.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/app/theme/theme_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await PushNotificationService.instance.initialize();
  ThemeController.instance.attach();
  await ThemeController.instance.load();

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
    final themeController = ThemeController.instance;
    return ListenableBuilder(
      listenable: themeController,
      builder: (context, _) {
        AppColors.brightness = themeController.effectiveBrightness;
        final mode = themeController.mode;
        return MaterialApp(
          title: 'B2B Conecta',
          debugShowCheckedModeBanner: false,
          scaffoldMessengerKey: scaffoldMessengerKey,
          navigatorKey: rootNavigatorKey,
          theme: buildAppTheme(),
          darkTheme: buildAppDarkTheme(),
          // Solo claro/oscuro (nunca system).
          themeMode: mode,
          builder: (context, child) {
            AppColors.brightness = themeController.effectiveBrightness;
            // Key fuerza reconstrucción completa de la UI al cambiar tono.
            return KeyedSubtree(
              key: ValueKey<String>('theme-${mode.name}'),
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: const AuthGate(),
        );
      },
    );
  }
}
