import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:motolink_pro_app/app/app_scaffold_messenger.dart';
import 'package:motolink_pro_app/app/config/public_auth_route.dart';
import 'package:motolink_pro_app/core/auth/auth_gate.dart';
import 'package:motolink_pro_app/core/notifications/push_notification_service.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/app/theme/theme_controller.dart';
import 'package:motolink_pro_app/features/ads/ad_attribution_storage.dart';
import 'package:motolink_pro_app/features/ads/marketing_consent_host.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Antes de cualquier await: en web, /registro o ?registro=1.
  final launchUri = Uri.base;
  unawaited(AdAttributionStorage.captureFromUri(launchUri));
  if (kIsWeb) {
    usePathUrlStrategy();
  }
  _enableAndroidPhotoPicker();
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
  runApp(MyApp(launchUri: launchUri));
}

/// Play policy: gallery picks must use the system Photo Picker (no READ_MEDIA_*).
void _enableAndroidPhotoPicker() {
  final impl = ImagePickerPlatform.instance;
  if (impl is ImagePickerAndroid) {
    impl.useAndroidPhotoPicker = true;
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.launchUri});

  final Uri? launchUri;

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
              child: MarketingConsentHost(
                child: child ?? const SizedBox.shrink(),
              ),
            );
          },
          // La URL del navegador sigue el *nombre* de la ruta del Navigator.
          // Si el stack arranca en "/", Flutter deja localhost:3000/ aunque
          // el formulario sea de registro.
          onGenerateInitialRoutes: (initialRoute) {
            final pathOnly = initialRoute.split('?').first;
            final register = PublicAuthRoute.shouldOpenRegister(
              launchUri: launchUri,
              routeName: pathOnly,
            );
            final name = register ? PublicAuthRoute.path : '/';
            return [
              MaterialPageRoute<void>(
                settings: RouteSettings(name: name),
                builder: (_) => AuthGate(
                  launchUri: launchUri,
                  startInRegister: register,
                ),
              ),
            ];
          },
          routes: {
            '/': (_) => AuthGate(launchUri: launchUri),
            PublicAuthRoute.path: (_) => AuthGate(
                  launchUri: launchUri,
                  startInRegister: true,
                ),
            '${PublicAuthRoute.path}/': (_) => AuthGate(
                  launchUri: launchUri,
                  startInRegister: true,
                ),
          },
          onGenerateRoute: (settings) {
            final register = PublicAuthRoute.shouldOpenRegister(
              launchUri: launchUri,
              routeName: settings.name,
            );
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => AuthGate(
                launchUri: launchUri,
                startInRegister: register,
              ),
            );
          },
          onUnknownRoute: (settings) {
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => AuthGate(launchUri: launchUri),
            );
          },
        );
      },
    );
  }
}
