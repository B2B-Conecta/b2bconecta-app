import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';
import 'package:motolink_pro_app/features/admin/unified_action_dialog.dart';

/// Bienvenida del primer ingreso Minorista-Emprendedor.
abstract final class EntrepreneurWelcomeDialog {
  static Future<void> showIfNeeded({
    required BuildContext context,
    required bool needsWelcome,
    VoidCallback? onSeen,
  }) async {
    if (!needsWelcome) return;
    await show(context: context, onSeen: onSeen);
  }

  static Future<void> show({
    required BuildContext context,
    VoidCallback? onSeen,
  }) {
    return UnifiedActionDialog.show<void>(
      context: context,
      builder: (ctx) => _EntrepreneurWelcomeBody(onSeen: onSeen),
    );
  }
}

class _EntrepreneurWelcomeBody extends StatefulWidget {
  const _EntrepreneurWelcomeBody({this.onSeen});

  final VoidCallback? onSeen;

  @override
  State<_EntrepreneurWelcomeBody> createState() =>
      _EntrepreneurWelcomeBodyState();
}

class _EntrepreneurWelcomeBodyState extends State<_EntrepreneurWelcomeBody> {
  bool _busy = false;

  Future<void> _confirm() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await SupabaseService.markEntrepreneurWelcomeSeen();
      widget.onSeen?.call();
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No se pudo guardar. Intenta de nuevo.',
              style: TextStyle(
                color: B2BThemeExtension.of(context).surfaceCard,
              ),
            ),
            backgroundColor: B2BThemeExtension.of(context).textPrimary,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return UnifiedActionDialog(
      title: '¡Bienvenido a B2B Conecta, Emprendedor!',
      glyph: LucideGlyph.sparkles,
      tone: UnifiedActionTone.info,
      maxWidth: 480,
      busy: _busy,
      cancelLabel: 'Cerrar',
      primaryLabel: 'Entendido, explorar catálogo',
      onPrimary: _busy ? null : _confirm,
      body: const _WelcomeCards(),
    );
  }
}

class _WelcomeCards extends StatelessWidget {
  const _WelcomeCards();

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Tu cuenta ya está activa. Revisa estos plazos para mantener '
          'el acceso sin límites.',
          style: TextStyle(
            fontSize: 14,
            height: 1.4,
            color: theme.textSecondary,
          ),
        ),
        const SizedBox(height: 16),
        const _InfoCard(
          glyph: LucideGlyph.sparkles,
          title: 'Primeros 8 días hábiles',
          body:
              'Tienes un periodo inicial de 8 días hábiles para explorar el '
              'catálogo y realizar tu primera compra. Al quinto día hábil '
              'sin compra recibirás una advertencia con 3 días restantes.',
        ),
        const SizedBox(height: 10),
        const _InfoCard(
          glyph: LucideGlyph.fileText,
          title: 'Plazo de 8 semanas',
          body:
              'Una vez hagas tu primer pedido, tendrás 8 semanas para cargar '
              'tus documentos comerciales restantes (Registro Mercantil, '
              'Referencias Bancarias y Carta de Crédito/Registro Comercial) '
              'y mantener tu cuenta activa sin límites.',
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.glyph,
    required this.title,
    required this.body,
  });

  final LucideGlyph glyph;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.surfaceSubtle,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: theme.brandContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: LucideIcon(glyph, size: 20, color: theme.brand),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: theme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    body,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: theme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
