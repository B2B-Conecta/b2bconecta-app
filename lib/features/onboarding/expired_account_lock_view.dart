import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/main_shell_tab.dart';
import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'package:motolink_pro_app/core/layout/app_breakpoints.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';
import 'package:motolink_pro_app/features/onboarding/entrepreneur_retailer.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';

/// Vista de cuenta caducada (Fase 3): bloqueo marketplace + CTA de reactivación.
class ExpiredAccountLockView extends StatefulWidget {
  const ExpiredAccountLockView({
    super.key,
    required this.profile,
    this.onProfileChanged,
    this.embedInShell = true,
  });

  final ProfileModel profile;
  final VoidCallback? onProfileChanged;
  final bool embedInShell;

  @override
  State<ExpiredAccountLockView> createState() => _ExpiredAccountLockViewState();
}

class _ExpiredAccountLockViewState extends State<ExpiredAccountLockView> {
  bool _busy = false;
  bool _justSubmitted = false;

  bool get _requested =>
      widget.profile.entrepreneurStatus?.trim().toLowerCase() ==
          EntrepreneurStatus.reactivationRequested ||
      _justSubmitted;

  bool get _firstPurchaseLock =>
      widget.profile.isEntrepreneurFirstPurchaseLock;

  Future<void> _requestReactivation() async {
    if (_busy || _requested) return;
    setState(() => _busy = true);
    try {
      await SupabaseService.requestEntrepreneurReactivation();
      if (!mounted) return;
      setState(() {
        _justSubmitted = true;
        _busy = false;
      });
      widget.onProfileChanged?.call();
      await _showSuccessDialog();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      final theme = B2BThemeExtension.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo enviar la solicitud: $e',
            style: TextStyle(color: theme.surfaceCard),
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _showSuccessDialog() async {
    final theme = B2BThemeExtension.of(context);
    final mobile =
        MediaQuery.sizeOf(context).width < AppBreakpoints.mobileMenu;
    final body = Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '¡Solicitud enviada con éxito!',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: theme.textPrimary,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Cerrar',
                onPressed: () => Navigator.of(context).maybePop(),
                icon: LucideIcon(
                  LucideGlyph.close,
                  size: 20,
                  color: theme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Un asesor comercial de B2B Conecta se comunicará contigo vía '
            'WhatsApp o correo electrónico en las próximas horas para '
            'verificar tu caso, evaluar una prórroga o habilitar tu cuenta.',
            style: TextStyle(
              fontSize: 13.5,
              height: 1.45,
              color: theme.textSecondary,
            ),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: () {
              Navigator.of(context).maybePop();
              MainShellTabController.navigateToProfileKycDocumentation();
            },
            style: FilledButton.styleFrom(
              backgroundColor: theme.brand,
              foregroundColor: theme.surfaceCard,
              minimumSize: const Size.fromHeight(46),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Ir a mis documentos',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (mobile) {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: theme.dialogSurface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (ctx) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(ctx).bottom,
          ),
          child: body,
        ),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: theme.dialogSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: body,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final scheme = Theme.of(context).colorScheme;
    final alert = scheme.error;
    final mobile =
        MediaQuery.sizeOf(context).width < AppBreakpoints.mobileMenu;

    final card = DecoratedBox(
      decoration: BoxDecoration(
        color: theme.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: alert.withOpacity(0.35)),
        boxShadow: [
          BoxShadow(
            color: theme.textPrimary.withOpacity(0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          mobile ? 18 : 28,
          mobile ? 22 : 28,
          mobile ? 18 : 28,
          mobile ? 20 : 26,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: alert.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: alert.withOpacity(0.28)),
                ),
                child: LucideIcon(
                  LucideGlyph.shieldAlert,
                  size: 30,
                  color: alert,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Tu periodo de cortesía ha caducado',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: theme.textPrimary,
                letterSpacing: -0.2,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _firstPurchaseLock
                  ? 'Se agotaron los 8 días hábiles sin registrar tu primera '
                      'compra. El acceso al marketplace quedó pausado '
                      'temporalmente. Contacta con administración para revisar '
                      'tu caso.'
                  : 'Han transcurrido las 8 semanas del periodo inicial para '
                      'emprendedores sin completar la documentación comercial '
                      'requerida. Tu acceso a las compras en el marketplace ha '
                      'sido pausado temporalmente para proteger el cumplimiento '
                      'normativo.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: theme.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            DecoratedBox(
              decoration: BoxDecoration(
                color: theme.surfaceSubtle,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: theme.borderSubtle),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _requested
                          ? 'Solicitud en revisión'
                          : (_firstPurchaseLock
                              ? 'Contactar con administración'
                              : 'Reactivar con un asesor'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: theme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _requested
                          ? (_firstPurchaseLock
                              ? 'Ya registramos tu solicitud. Un asesor de '
                                  'B2B Conecta se comunicará contigo pronto.'
                              : 'Ya registramos tu solicitud. Un asesor se '
                                  'comunicará contigo pronto. Mientras tanto '
                                  'puedes seguir cargando documentos en Perfil → KYC.')
                          : (_firstPurchaseLock
                              ? 'Generaremos un ticket de soporte y avisaremos '
                                  'al panel administrativo para evaluar tu caso.'
                              : 'Un asesor comercial evaluará una prórroga o la '
                                  'habilitación de tu cuenta.'),
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.4,
                        color: theme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (!_requested)
                      FilledButton.icon(
                        onPressed: _busy ? null : _requestReactivation,
                        style: FilledButton.styleFrom(
                          backgroundColor: theme.brand,
                          foregroundColor: theme.surfaceCard,
                          disabledBackgroundColor:
                              theme.brand.withOpacity(0.45),
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: _busy
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: theme.surfaceCard,
                                ),
                              )
                            : LucideIcon(
                                LucideGlyph.headset,
                                size: 18,
                                color: theme.surfaceCard,
                              ),
                        label: Text(
                          _busy
                              ? 'Enviando…'
                              : (_firstPurchaseLock
                                  ? 'Contactar con administración'
                                  : 'Contactar con un asesor para reactivar cuenta'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      )
                    else if (!_firstPurchaseLock)
                      OutlinedButton.icon(
                        onPressed: () => MainShellTabController
                            .navigateToProfileKycDocumentation(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: theme.brand,
                          side: BorderSide(color: theme.brand.withOpacity(0.45)),
                          minimumSize: const Size.fromHeight(46),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: LucideIcon(
                          LucideGlyph.clipboardCheck,
                          size: 18,
                          color: theme.brand,
                        ),
                        label: const Text(
                          'Continuar con mis documentos',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (!_firstPurchaseLock) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: () =>
                    MainShellTabController.navigateToProfileKycDocumentation(),
                child: Text(
                  'Ir a Perfil → Datos y KYC',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: theme.brand,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );

    final content = Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: mobile ? double.infinity : 640),
        child: card,
      ),
    );

    if (!widget.embedInShell) {
      return Scaffold(
        backgroundColor: theme.background,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              mobile ? 16 : 24,
              24,
              mobile ? 16 : 24,
              24,
            ),
            child: content,
          ),
        ),
      );
    }

    return ColoredBox(
      color: theme.background,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            mobile ? 16 : 24,
            mobile ? 16 : 24,
            mobile ? 16 : 24,
            28,
          ),
          child: content,
        ),
      ),
    );
  }
}
