import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:motolink_pro_app/app/main_shell_tab.dart';
import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';
import 'package:motolink_pro_app/features/admin/admin_users_hub_section.dart';
import 'package:motolink_pro_app/features/admin/owner_account_search.dart';
import 'package:motolink_pro_app/features/catalog/catalog_filters.dart';
import 'package:motolink_pro_app/features/catalog/part_model.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_filter_utils.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_model.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';

enum AdminGlobalSearchKind { navigation, user, order, product }

class AdminGlobalSearchHit {
  const AdminGlobalSearchHit({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.glyph,
    required this.onOpen,
  });

  final AdminGlobalSearchKind kind;
  final String title;
  final String subtitle;
  final LucideGlyph glyph;
  final VoidCallback onOpen;
}

/// Paleta de comandos admin (⌘K / Ctrl+K): usuarios, pedidos, productos y destinos.
Future<void> showAdminGlobalSearchModal(
  BuildContext context, {
  String initialQuery = '',
}) {
  final theme = B2BThemeExtension.of(context);
  return showDialog<void>(
    context: context,
    barrierColor: theme.textPrimary.withOpacity(0.45),
    builder: (ctx) => _AdminGlobalSearchDialog(initialQuery: initialQuery),
  );
}

class _AdminGlobalSearchDialog extends StatefulWidget {
  const _AdminGlobalSearchDialog({required this.initialQuery});

  final String initialQuery;

  @override
  State<_AdminGlobalSearchDialog> createState() =>
      _AdminGlobalSearchDialogState();
}

class _AdminGlobalSearchDialogState extends State<_AdminGlobalSearchDialog> {
  late final TextEditingController _ctrl;
  late final FocusNode _focus;
  Timer? _debounce;
  var _loading = false;
  String _query = '';
  List<AdminGlobalSearchHit> _hits = const [];

  List<(String, String, LucideGlyph, VoidCallback)> get _nav => [
        (
          'Inicio',
          'Panel principal',
          LucideGlyph.layoutDashboard,
          () => MainShellTabController.goTo(0),
        ),
        (
          'Pedidos',
          'Bandeja de encomiendas activas',
          LucideGlyph.package,
          MainShellTabController.navigateToAdminActivosForNotification,
        ),
        (
          'Reportes',
          'Encomiendas, promos y analíticas',
          LucideGlyph.barChart3,
          MainShellTabController.navigateToAdminReportes,
        ),
        (
          'Usuarios · Cuentas',
          'Expedientes y KYC',
          LucideGlyph.users,
          () => MainShellTabController.navigateToAdminUsers(),
        ),
        (
          'Usuarios · Actividad',
          'Presencia e ingresos',
          LucideGlyph.activity,
          MainShellTabController.navigateToAdminPresence,
        ),
        (
          'Usuarios · Sellos y Vitrina',
          'Verificado y Destacado',
          LucideGlyph.shieldCheck,
          () => MainShellTabController.navigateToAdminUsers(
                section: AdminUsersHubSection.sellosYVitrina,
              ),
        ),
        (
          'Comisiones',
          'Liquidaciones',
          LucideGlyph.badgeDollarSign,
          MainShellTabController.navigateToAdminComisionesForNotification,
        ),
        (
          'Soporte',
          'Tickets',
          LucideGlyph.headset,
          () => MainShellTabController.goTo(
                MainShellTabController.adminSupportTabIndex,
              ),
        ),
      ];

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialQuery);
    _focus = FocusNode();
    _query = widget.initialQuery.trim();
    _hits = _navHits(_query);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
      if (_query.isNotEmpty) _runSearch(_query);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  List<AdminGlobalSearchHit> _navHits(String q) {
    final lower = q.toLowerCase();
    return [
      for (final n in _nav)
        if (lower.isEmpty ||
            n.$1.toLowerCase().contains(lower) ||
            n.$2.toLowerCase().contains(lower))
          AdminGlobalSearchHit(
            kind: AdminGlobalSearchKind.navigation,
            title: n.$1,
            subtitle: n.$2,
            glyph: n.$3,
            onOpen: () {
              Navigator.of(context).pop();
              n.$4();
            },
          ),
    ];
  }

  void _onQueryChanged(String raw) {
    final q = raw.trim();
    setState(() {
      _query = q;
      _hits = _navHits(q);
    });
    _debounce?.cancel();
    if (q.length < 2) {
      setState(() => _loading = false);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 280), () => _runSearch(q));
  }

  Future<void> _runSearch(String q) async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        SupabaseService.ownerListProfiles(),
        SupabaseService.fetchUnifiedTransactionRequestsForAdmin(),
        SupabaseService.fetchParts(
          limit: 24,
          filters: CatalogFilters(searchQuery: q),
        ),
      ]);
      if (!mounted || _ctrl.text.trim() != q) return;

      final profiles = results[0] as List<ProfileModel>;
      final orders = results[1] as List<TransactionRequestModel>;
      final parts = results[2] as List<PartModel>;

      final userHits = <AdminGlobalSearchHit>[];
      for (final p in profiles) {
        if (!ownerAccountMatchesQuery(p, q)) continue;
        final name = (p.businessName?.trim().isNotEmpty == true)
            ? p.businessName!.trim()
            : (p.email?.trim() ?? p.id);
        userHits.add(
          AdminGlobalSearchHit(
            kind: AdminGlobalSearchKind.user,
            title: name,
            subtitle: [
              if ((p.email ?? '').trim().isNotEmpty) p.email!.trim(),
              if ((p.role ?? '').trim().isNotEmpty) p.role!.trim(),
            ].join(' · '),
            glyph: LucideGlyph.user,
            onOpen: () {
              Navigator.of(context).pop();
              MainShellTabController.navigateToAdminUsers(
                section: AdminUsersHubSection.cuentas,
                userId: p.id,
              );
            },
          ),
        );
        if (userHits.length >= 8) break;
      }

      final orderHits = <AdminGlobalSearchHit>[];
      for (final r in orders) {
        if (!TransactionRequestFilterUtils.matchesSearch(r, q)) continue;
        orderHits.add(
          AdminGlobalSearchHit(
            kind: AdminGlobalSearchKind.order,
            title: r.productName?.trim().isNotEmpty == true
                ? r.productName!.trim()
                : 'Pedido',
            subtitle: [
              if ((r.aliadoBusinessName ?? '').trim().isNotEmpty)
                r.aliadoBusinessName!.trim(),
              if ((r.ownerBusinessName ?? '').trim().isNotEmpty)
                r.ownerBusinessName!.trim(),
              r.statusLabelEs(),
            ].join(' · '),
            glyph: LucideGlyph.package,
            onOpen: () {
              Navigator.of(context).pop();
              MainShellTabController.navigateToAdminActivosForNotification();
            },
          ),
        );
        if (orderHits.length >= 8) break;
      }

      final productHits = <AdminGlobalSearchHit>[];
      for (final part in parts) {
        productHits.add(
          AdminGlobalSearchHit(
            kind: AdminGlobalSearchKind.product,
            title: part.nombre.trim().isNotEmpty ? part.nombre.trim() : 'Producto',
            subtitle: [
              if ((part.sku ?? '').trim().isNotEmpty) 'SKU ${part.sku}',
              if ((part.ownerBusinessName ?? '').trim().isNotEmpty)
                part.ownerBusinessName!.trim(),
            ].join(' · '),
            glyph: LucideGlyph.tag,
            onOpen: () {
              Navigator.of(context).pop();
              MainShellTabController.navigateToAdminUsers(
                section: AdminUsersHubSection.sellosYVitrina,
              );
            },
          ),
        );
        if (productHits.length >= 8) break;
      }

      setState(() {
        _hits = [..._navHits(q), ...userHits, ...orderHits, ...productHits];
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hits = _navHits(q);
        _loading = false;
      });
    }
  }

  String _sectionLabel(AdminGlobalSearchKind kind) => switch (kind) {
        AdminGlobalSearchKind.navigation => 'Navegación',
        AdminGlobalSearchKind.user => 'Usuarios',
        AdminGlobalSearchKind.order => 'Pedidos',
        AdminGlobalSearchKind.product => 'Productos',
      };

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final isMac = Theme.of(context).platform == TargetPlatform.macOS ||
        Theme.of(context).platform == TargetPlatform.iOS;
    AdminGlobalSearchKind? lastKind;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () {
          Navigator.of(context).maybePop();
        },
      },
      child: Dialog(
        backgroundColor: theme.dialogSurface,
        elevation: 12,
        shadowColor: theme.textPrimary.withOpacity(0.28),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: theme.borderStrong),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
                child: Row(
                  children: [
                    LucideIcon(
                      LucideGlyph.search,
                      size: 18,
                      color: theme.textSecondary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _ctrl,
                        focusNode: _focus,
                        autofocus: true,
                        textInputAction: TextInputAction.search,
                        onChanged: _onQueryChanged,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: theme.textPrimary,
                        ),
                        decoration: InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          hintText: 'Buscar usuarios, pedidos, productos…',
                          hintStyle: TextStyle(color: theme.textMuted),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: theme.surfaceSubtle,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isMac ? '⌘K' : 'Ctrl+K',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: theme.textSecondary,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Cerrar',
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: LucideIcon(
                        LucideGlyph.close,
                        size: 18,
                        color: theme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: theme.border),
              if (_loading)
                LinearProgressIndicator(
                  minHeight: 2,
                  color: theme.brand,
                  backgroundColor: theme.brandContainer,
                ),
              Expanded(
                child: _hits.isEmpty
                    ? Center(
                        child: Text(
                          _query.length < 2
                              ? 'Escribe para buscar o elige un destino.'
                              : 'Sin resultados para «$_query».',
                          style: TextStyle(color: theme.textSecondary),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
                        itemCount: _hits.length,
                        itemBuilder: (context, i) {
                          final hit = _hits[i];
                          final showHeader = hit.kind != lastKind;
                          lastKind = hit.kind;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (showHeader)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    10,
                                    8,
                                    10,
                                    4,
                                  ),
                                  child: Text(
                                    _sectionLabel(hit.kind),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: theme.textMuted,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: hit.onOpen,
                                  borderRadius: BorderRadius.circular(10),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 10,
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 36,
                                          height: 36,
                                          decoration: BoxDecoration(
                                            color: theme.brandContainer,
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          alignment: Alignment.center,
                                          child: LucideIcon(
                                            hit.glyph,
                                            size: 18,
                                            color: theme.brand,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                hit.title,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 13.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: theme.textPrimary,
                                                ),
                                              ),
                                              if (hit.subtitle.isNotEmpty)
                                                Text(
                                                  hit.subtitle,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: theme.textSecondary,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        LucideIcon(
                                          LucideGlyph.chevronRight,
                                          size: 16,
                                          color: theme.textMuted,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
