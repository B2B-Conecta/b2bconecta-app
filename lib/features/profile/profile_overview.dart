import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/main_shell_tab.dart';
import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';
import 'package:motolink_pro_app/core/widgets/motolink_pro_logo.dart';
import 'package:motolink_pro_app/features/commissions/importer_commission_settlements_section.dart';
import 'package:motolink_pro_app/features/kyc/authorization_status_section.dart';
import 'account_settings_screen.dart';
import 'importer_commercial_settings.dart';
import 'profile_model.dart';

/// Portada de las cuentas habilitadas. El formulario conserva la edición y el registro.
class ProfileOverview extends StatelessWidget {
  const ProfileOverview({
    super.key,
    required this.profile,
    required this.onEdit,
    required this.onSignOut,
    this.accountActionsInShell = false,
    this.onChanged,
    this.documents,
    this.support,
  });

  final ProfileModel profile;
  final VoidCallback onEdit;
  final VoidCallback onSignOut;

  /// El shell de escritorio ya ofrece seguridad y cierre de sesión permanentes.
  final bool accountActionsInShell;
  final VoidCallback? onChanged;
  final Widget? documents;
  final Widget? support;

  static const _twoColMin = 900.0;

  void _open(BuildContext context, String title, Widget child) {
    Navigator.of(context).push<void>(MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: child,
            ),
          ),
        ),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final ready = profile.isReadyForMainApp &&
        profile.isComplete &&
        !profile.pedidosSuspendidosMorosidad &&
        (!profile.isAliado || profile.kycStatus == 'aprobado');

    final identity = Row(
      children: [
        _BusinessLogo(path: profile.logoStoragePath),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                profile.businessName ?? 'Mi negocio',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 19,
                  height: 1.25,
                  fontWeight: FontWeight.w700,
                  color: theme.textPrimary,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                profile.isImportador ? 'Importador' : 'Tienda minorista',
                style: TextStyle(color: theme.textSecondary),
              ),
              if (ready) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 5,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 16,
                      color: theme.successFg,
                    ),
                    Text(
                      'Cuenta habilitada',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );

    Widget businessFields({required bool twoByTwo}) {
      final location = _datum(
        context,
        'Ubicación / Ciudad',
        [profile.ciudad, profile.estado]
            .whereType<String>()
            .where((s) => s.trim().isNotEmpty)
            .join(' · '),
      );
      final rif = _datum(context, 'RIF', profile.rif);
      final phone = _datum(context, 'Teléfono / WhatsApp', profile.phone);
      final address = _datum(context, 'Dirección fiscal', profile.direccion);

      if (!twoByTwo) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [rif, phone, location, address],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: rif),
              const SizedBox(width: 12),
              Expanded(child: phone),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: location),
              const SizedBox(width: 12),
              Expanded(child: address),
            ],
          ),
        ],
      );
    }

    Widget businessCard({required bool twoByTwo}) {
      return _surface(
        context,
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (accountActionsInShell) ...[
              identity,
              const SizedBox(height: 12),
              Divider(height: 1, color: theme.borderSubtle),
              const SizedBox(height: 4),
            ],
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Mi negocio',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: theme.textPrimary,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Editar datos'),
                ),
              ],
            ),
            businessFields(twoByTwo: twoByTwo),
          ],
        ),
      );
    }

    final showShortcuts = !accountActionsInShell ||
        profile.isImportador ||
        profile.isAliado ||
        support != null;

    Widget shortcutsCard() {
      return _surface(
        context,
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!accountActionsInShell) ...[
              Text(
                'Tu cuenta',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: theme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              _entry(
                context,
                Icons.manage_accounts_outlined,
                'Cuenta y seguridad',
                'Contraseña y notificaciones',
                () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => const AccountSettingsScreen(),
                  ),
                ),
              ),
            ],
            if (profile.isImportador)
              _entry(
                context,
                Icons.storefront_outlined,
                'Configuración comercial',
                'Pedido mínimo, pagos y transportistas',
                () => _open(
                  context,
                  'Configuración comercial',
                  ImporterCommercialSettings(
                    profile: profile,
                    onChanged: onChanged,
                  ),
                ),
              ),
            if (profile.isAliado) ...[
              _entry(
                context,
                Icons.star_rounded,
                'Mi reputación',
                _reputationSummary,
                MainShellTabController.navigateToReputationTab,
                iconColor: theme.brand,
              ),
              if (accountActionsInShell && support != null) ...[
                Divider(height: 17, color: theme.borderSubtle),
                support!,
              ],
              if (accountActionsInShell)
                _entry(
                  context,
                  LucideGlyph.store,
                  'Ver catálogo de mayoristas',
                  'Explora productos y confirma tu primera compra',
                  MainShellTabController.navigateToAliadoCatalog,
                  lucide: true,
                ),
            ] else if (accountActionsInShell && support != null) ...[
              if (profile.isImportador)
                Divider(height: 17, color: theme.borderSubtle),
              support!,
            ],
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!accountActionsInShell) _surface(context, identity),
        if (!ready && documents == null) ...[
          const SizedBox(height: 12),
          AuthorizationStatusSection(profile: profile),
        ],
        if (!accountActionsInShell || (!ready && documents == null))
          const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            if (!showShortcuts) {
              return businessCard(
                twoByTwo: constraints.maxWidth >= 465,
              );
            }
            final twoCol = constraints.maxWidth >= _twoColMin;
            if (!twoCol) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  businessCard(twoByTwo: constraints.maxWidth >= 465),
                  const SizedBox(height: 12),
                  shortcutsCard(),
                ],
              );
            }
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: accountActionsInShell ? 5 : 3,
                    child: businessCard(twoByTwo: true),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: accountActionsInShell ? 3 : 2,
                    child: shortcutsCard(),
                  ),
                ],
              ),
            );
          },
        ),
        if (documents != null) ...[
          const SizedBox(height: 20),
          Text(
            'Verificación del negocio',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: theme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          documents!,
        ],
        if (profile.isImportador) ...[
          const SizedBox(height: 16),
          const ImporterCommissionSettlementsSection(grouped: true),
        ],
        if (!accountActionsInShell && support != null) ...[
          const SizedBox(height: 16),
          support!,
        ],
        if (!accountActionsInShell) ...[
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.center,
            child: TextButton.icon(
              onPressed: onSignOut,
              style: TextButton.styleFrom(foregroundColor: theme.textSecondary),
              icon: const Icon(Icons.logout, size: 20),
              label: const Text('Cerrar sesión'),
            ),
          ),
        ],
      ],
    );
  }

  String get _reputationSummary {
    final rolling = profile.ratingAsPayerAvgRolling100;
    final score = rolling ?? profile.ratingAsPayerAvg;
    final count = (rolling != null
            ? profile.ratingAsPayerCountRolling100
            : profile.ratingAsPayerCount) ??
        0;
    if (score == null || count == 0) {
      return 'Aún sin valoraciones · Ver mi reputación';
    }
    return '${score.toStringAsFixed(1).replaceAll('.', ',')} / 5 · $count ${count == 1 ? 'valoración' : 'valoraciones'}';
  }

  Widget _surface(BuildContext context, Widget child) {
    final theme = B2BThemeExtension.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.borderSubtle),
      ),
      child: child,
    );
  }

  Widget _datum(BuildContext context, String label, String? value) {
    final theme = B2BThemeExtension.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: theme.textSecondary),
          ),
          const SizedBox(height: 3),
          Text(
            value == null || value.trim().isEmpty ? 'Por completar' : value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: theme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _entry(
    BuildContext context,
    Object icon,
    String title,
    String subtitle,
    VoidCallback onTap, {
    Color? iconColor,
    bool lucide = false,
  }) {
    final theme = B2BThemeExtension.of(context);
    final color = iconColor ?? theme.brand;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: lucide
          ? LucideIcon(icon as LucideGlyph, size: 22, color: color)
          : Icon(icon as IconData, color: color),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: theme.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 12, color: theme.textSecondary),
      ),
      trailing: Icon(Icons.chevron_right, size: 20, color: theme.textMuted),
      onTap: onTap,
    );
  }
}

class _BusinessLogo extends StatefulWidget {
  const _BusinessLogo({this.path});
  final String? path;
  @override
  State<_BusinessLogo> createState() => _BusinessLogoState();
}

class _BusinessLogoState extends State<_BusinessLogo> {
  Future<String>? _url;
  void _load() {
    final path = widget.path?.trim();
    _url = path == null || path.isEmpty
        ? null
        : SupabaseService.createSignedUrlForProfileLogo(path);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _BusinessLogo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) _load();
  }

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 52,
          height: 52,
          child: FutureBuilder<String>(
            future: _url,
            builder: (context, snapshot) => snapshot.hasData
                ? Image.network(
                    snapshot.data!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const BusinessLogoPlaceholder(size: 52),
                  )
                : const BusinessLogoPlaceholder(size: 52),
          ),
        ),
      );
}
