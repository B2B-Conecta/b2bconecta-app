import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/widgets/motolink_pro_logo.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'package:motolink_pro_app/features/commissions/importer_commission_settlements_section.dart';
import 'package:motolink_pro_app/features/kyc/authorization_status_section.dart';
import 'account_settings_screen.dart';
import 'profile_model.dart';
import 'importer_commercial_settings.dart';

/// Portada de las cuentas habilitadas. El formulario conserva la edición y el registro.
class ProfileOverview extends StatelessWidget {
  const ProfileOverview(
      {super.key,
      required this.profile,
      required this.onEdit,
      required this.onSignOut,
      this.accountActionsInShell = false,
      this.onChanged,
      this.documents,
      this.support});

  final ProfileModel profile;
  final VoidCallback onEdit;
  final VoidCallback onSignOut;

  /// El shell de escritorio ya ofrece seguridad y cierre de sesión permanentes.
  final bool accountActionsInShell;
  final VoidCallback? onChanged;
  final Widget? documents;
  final Widget? support;

  void _open(BuildContext context, String title, Widget child) {
    Navigator.of(context).push<void>(MaterialPageRoute(
        builder: (_) => Scaffold(
              appBar: AppBar(title: Text(title)),
              body: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                      child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 760),
                          child: child))),
            )));
  }

  @override
  Widget build(BuildContext context) {
    final ready = profile.isReadyForMainApp &&
        profile.isComplete &&
        !profile.pedidosSuspendidosMorosidad &&
        (!profile.isAliado || profile.kycStatus == 'aprobado');
    final identity = Row(children: [
      _BusinessLogo(path: profile.logoStoragePath),
      const SizedBox(width: 14),
      Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(profile.businessName ?? 'Mi negocio',
            style: const TextStyle(
                fontSize: 19, height: 1.25, fontWeight: FontWeight.w700)),
        const SizedBox(height: 5),
        Text(profile.isImportador ? 'Importador' : 'Tienda minorista',
            style: TextStyle(color: AppColors.textSecondary)),
        if (ready) ...[
          const SizedBox(height: 8),
          Wrap(
              spacing: 5,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Icon(Icons.check_circle_outline,
                    size: 16, color: AppColors.successGreen),
                const Text('Cuenta habilitada', style: TextStyle(fontSize: 12)),
              ]),
        ],
      ])),
    ]);
    final business = _surface(
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (accountActionsInShell) ...[
        identity,
        const SizedBox(height: 12),
        Divider(height: 1, color: AppColors.borderSubtle),
        const SizedBox(height: 4),
      ],
      Row(children: [
        const Expanded(
            child: Text('Mi negocio',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
        TextButton.icon(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Editar datos')),
      ]),
      LayoutBuilder(builder: (context, constraints) {
        final location = _datum(
            'Ubicación',
            [profile.ciudad, profile.estado]
                .whereType<String>()
                .where((s) => s.trim().isNotEmpty)
                .join(' · '));
        final enlargedText = MediaQuery.textScalerOf(context).scale(14) > 20;
        if (accountActionsInShell &&
            constraints.maxWidth >= 465 &&
            !enlargedText) {
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: _datum('RIF', profile.rif)),
            const SizedBox(width: 12),
            Expanded(child: _datum('Teléfono', profile.phone)),
            const SizedBox(width: 12),
            Expanded(flex: 2, child: location),
          ]);
        }
        if (constraints.maxWidth < 270 || enlargedText) {
          return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _datum('RIF', profile.rif),
                _datum('Teléfono', profile.phone),
                location,
              ]);
        }
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: _datum('RIF', profile.rif)),
                const SizedBox(width: 12),
                Expanded(child: _datum('Teléfono', profile.phone)),
              ]),
              location,
            ]);
      }),
      _datum('Dirección fiscal', profile.direccion),
    ]));
    final showShortcuts =
        !accountActionsInShell || profile.isImportador || support != null;
    final shortcuts = _surface(
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (!accountActionsInShell) ...[
        const Text('Tu cuenta',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        _entry(
            Icons.manage_accounts_outlined,
            'Cuenta y seguridad',
            'Contraseña y notificaciones',
            () => Navigator.of(context).push<void>(MaterialPageRoute(
                builder: (_) => const AccountSettingsScreen()))),
      ],
      if (profile.isImportador)
        _entry(
            Icons.storefront_outlined,
            'Configuración comercial',
            'Pedido mínimo, pagos y transportistas',
            () => _open(
                context,
                'Configuración comercial',
                ImporterCommercialSettings(
                    profile: profile, onChanged: onChanged))),
      if (accountActionsInShell && support != null) ...[
        if (profile.isImportador)
          Divider(height: 17, color: AppColors.borderSubtle),
        support!,
      ],
    ]));

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (!accountActionsInShell) _surface(identity),
      if (!ready) ...[
        const SizedBox(height: 12),
        AuthorizationStatusSection(profile: profile),
      ],
      if (!accountActionsInShell || !ready) const SizedBox(height: 16),
      LayoutBuilder(builder: (context, constraints) {
        if (!showShortcuts) return business;
        if (constraints.maxWidth < (accountActionsInShell ? 740 : 800)) {
          return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [business, const SizedBox(height: 12), shortcuts]);
        }
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: accountActionsInShell ? 4 : 3, child: business),
          const SizedBox(width: 16),
          Expanded(flex: 2, child: shortcuts),
        ]);
      }),
      if (documents != null) ...[
        const SizedBox(height: 20),
        const Text('Verificación del negocio',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        documents!,
      ],
      if (profile.isImportador) ...[
        const SizedBox(height: 16),
        // Se mantiene montado para los accesos desde Inicio y notificaciones.
        const ImporterCommissionSettlementsSection(grouped: true),
      ],
      if (!accountActionsInShell && support != null) ...[
        const SizedBox(height: 16),
        support!
      ],
      if (!accountActionsInShell) ...[
        const SizedBox(height: 16),
        Align(
            alignment: Alignment.center,
            child: TextButton.icon(
                onPressed: onSignOut,
                style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary),
                icon: const Icon(Icons.logout, size: 20),
                label: const Text('Cerrar sesión'))),
      ],
    ]);
  }

  Widget _surface(Widget child) => Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderSubtle)),
      child: child);

  Widget _datum(String label, String? value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(height: 3),
        Text(value == null || value.trim().isEmpty ? 'Por completar' : value,
            style: const TextStyle(fontSize: 14, height: 1.4)),
      ]));

  Widget _entry(
          IconData icon, String title, String subtitle, VoidCallback onTap) =>
      ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(icon, color: AppColors.brand),
          title: Text(title,
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
          trailing: const Icon(Icons.chevron_right, size: 20),
          onTap: onTap);
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
                  ? Image.network(snapshot.data!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const BusinessLogoPlaceholder(size: 52))
                  : const BusinessLogoPlaceholder(size: 52))));
}
