import 'package:flutter/material.dart';

import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';
import 'package:motolink_pro_app/core/widgets/theme_mode_bubble.dart';
import 'package:motolink_pro_app/features/admin/admin_settings_tab.dart';
import 'package:motolink_pro_app/features/admin/admin_users_chrome.dart';
import 'package:motolink_pro_app/features/admin/commissions_settings_tab.dart';
import 'package:motolink_pro_app/features/admin/notifications_settings_tab.dart';
import 'package:motolink_pro_app/features/admin/profile_settings_tab.dart';
import 'package:motolink_pro_app/features/admin/security_settings_tab.dart';

/// Hub de cuenta y preferencias admin: Perfil · Notificaciones · Seguridad · Comisiones.
class AdminSettingsHub extends StatefulWidget {
  const AdminSettingsHub({
    super.key,
    this.initialTab = AdminSettingsTab.perfil,
    this.onProfileSaved,
    this.embedded = false,
  });

  final AdminSettingsTab initialTab;
  final VoidCallback? onProfileSaved;

  /// Sin Scaffold/AppBar propios: vive dentro del AppShell.
  final bool embedded;

  @override
  State<AdminSettingsHub> createState() => _AdminSettingsHubState();
}

class _AdminSettingsHubState extends State<AdminSettingsHub> {
  late AdminSettingsTab _tab;
  final Set<AdminSettingsTab> _visited = {};

  static const _tabs = <(AdminSettingsTab, LucideGlyph)>[
    (AdminSettingsTab.perfil, LucideGlyph.user),
    (AdminSettingsTab.notificaciones, LucideGlyph.bell),
    (AdminSettingsTab.seguridad, LucideGlyph.shieldCheck),
    (AdminSettingsTab.comisiones, LucideGlyph.badgeDollarSign),
  ];

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
    _visited.add(_tab);
  }

  @override
  void didUpdateWidget(covariant AdminSettingsHub oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab) {
      _select(widget.initialTab);
    }
  }

  void _select(AdminSettingsTab tab) {
    setState(() {
      _tab = tab;
      _visited.add(tab);
    });
  }

  Widget _bodyFor(AdminSettingsTab tab) {
    switch (tab) {
      case AdminSettingsTab.perfil:
        return ProfileSettingsTab(onSaved: widget.onProfileSaved);
      case AdminSettingsTab.notificaciones:
        return const NotificationPreferencesTab();
      case AdminSettingsTab.seguridad:
        return const SecuritySettingsTab();
      case AdminSettingsTab.comisiones:
        return const B2BCommissionsBillingTab();
    }
  }

  Widget _stack() {
    return IndexedStack(
      index: _tab.index,
      sizing: StackFit.expand,
      children: [
        for (final entry in _tabs)
          _visited.contains(entry.$1)
              ? KeyedSubtree(
                  key: ValueKey(entry.$1),
                  child: _bodyFor(entry.$1),
                )
              : const SizedBox.shrink(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final strip = _SettingsTabStrip(
      tabs: _tabs,
      selected: _tab,
      onSelected: _select,
    );

    if (widget.embedded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: BoxDecoration(
              color: AdminUsersChrome.cardColor,
              border: Border(
                bottom: BorderSide(color: AdminUsersChrome.border),
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: strip,
          ),
          Expanded(child: _stack()),
        ],
      );
    }

    return Scaffold(
      backgroundColor: AdminUsersChrome.zebra,
      appBar: AppBar(
        backgroundColor: AdminUsersChrome.cardColor,
        foregroundColor: AdminUsersChrome.titleColor,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Ajustes del sistema',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: AdminUsersChrome.titleColor,
          ),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: ThemeModeBubble(compact: true),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: strip,
        ),
      ),
      body: SafeArea(child: _stack()),
    );
  }
}

class _SettingsTabStrip extends StatelessWidget {
  const _SettingsTabStrip({
    required this.tabs,
    required this.selected,
    required this.onSelected,
  });

  final List<(AdminSettingsTab, LucideGlyph)> tabs;
  final AdminSettingsTab selected;
  final ValueChanged<AdminSettingsTab> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AdminUsersChrome.cardColor,
        border: Border(
          bottom: BorderSide(color: AdminUsersChrome.border),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            for (final entry in tabs)
              _TabChip(
                label: entry.$1.label,
                glyph: entry.$2,
                selected: selected == entry.$1,
                onTap: () => onSelected(entry.$1),
              ),
          ],
        ),
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.label,
    required this.glyph,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final LucideGlyph glyph;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AdminUsersChrome.brand : AdminUsersChrome.muted;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? AdminUsersChrome.brand : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              LucideIcon(glyph, size: 16, color: color),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
