import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:motolink_pro_app/app/main_shell_tab.dart';
import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'package:motolink_pro_app/core/layout/app_breakpoints.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';
import 'package:motolink_pro_app/features/admin/admin_global_search_service.dart';
import 'package:motolink_pro_app/features/admin/admin_reports_hub_section.dart';
import 'package:motolink_pro_app/features/admin/admin_users_hub_section.dart';
import 'package:motolink_pro_app/features/catalog/part_model.dart';
import 'package:motolink_pro_app/features/catalog/product_detail_screen.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_model.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_status.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';
import 'package:motolink_pro_app/features/profile/profile_role_labels.dart';

enum AdminGlobalSearchKind { quickAction, user, order, product }

class AdminGlobalSearchHit {
  const AdminGlobalSearchHit({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.glyph,
    required this.onOpen,
    this.badge,
    this.trailing,
    this.imageUrl,
    this.initials,
  });

  final AdminGlobalSearchKind kind;
  final String title;
  final String subtitle;
  final LucideGlyph glyph;
  final VoidCallback onOpen;
  final String? badge;
  final String? trailing;
  final String? imageUrl;
  final String? initials;
}

/// Paleta de comandos admin (⌘K / Ctrl+K): usuarios, pedidos, productos y atajos.
Future<void> showAdminGlobalSearchModal(
  BuildContext context, {
  String initialQuery = '',
}) {
  final theme = B2BThemeExtension.of(context);
  final mobile =
      MediaQuery.sizeOf(context).width < AppBreakpoints.mobileMenu;
  final host = context;

  if (mobile) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: theme.dialogSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SizedBox(
        height: MediaQuery.sizeOf(ctx).height * 0.92,
        child: _AdminGlobalSearchDialog(
          initialQuery: initialQuery,
          hostContext: host,
          compact: true,
        ),
      ),
    );
  }

  return showDialog<void>(
    context: context,
    barrierColor: theme.textPrimary.withOpacity(0.45),
    builder: (ctx) => _AdminGlobalSearchDialog(
      initialQuery: initialQuery,
      hostContext: host,
      compact: false,
    ),
  );
}

class _AdminGlobalSearchDialog extends StatefulWidget {
  const _AdminGlobalSearchDialog({
    required this.initialQuery,
    required this.hostContext,
    required this.compact,
  });

  final String initialQuery;
  final BuildContext hostContext;
  final bool compact;

  @override
  State<_AdminGlobalSearchDialog> createState() =>
      _AdminGlobalSearchDialogState();
}

class _AdminGlobalSearchDialogState extends State<_AdminGlobalSearchDialog> {
  late final TextEditingController _ctrl;
  late final FocusNode _inputFocus;
  Timer? _debounce;
  var _loading = false;
  String _query = '';
  List<AdminGlobalSearchHit> _hits = const [];
  int _selectedIndex = 0;
  int _searchGen = 0;

  List<(String, String, LucideGlyph, VoidCallback)> get _quickActions => [
        (
          'Cuentas por revisar',
          'KYC y acceso pendiente',
          LucideGlyph.userRound,
          () => MainShellTabController.navigateToAdminUsers(
                section: AdminUsersHubSection.cuentas,
                pendingReviewOnly: true,
              ),
        ),
        (
          'Pedidos por gestionar',
          'Confirmación / atención operativa',
          LucideGlyph.package,
          MainShellTabController.navigateToAdminPedidosPendingConfirmation,
        ),
        (
          'Soporte abierto',
          'Tickets sin resolver',
          LucideGlyph.headset,
          () => MainShellTabController.navigateToAdminSupportForNotification(),
        ),
        (
          'Actividad / presencia',
          'Ingresos recientes del panel',
          LucideGlyph.activity,
          MainShellTabController.navigateToAdminPresence,
        ),
        (
          'Devoluciones en revisión',
          'Postventa abierta',
          LucideGlyph.undo2,
          () => MainShellTabController.navigateToAdminReportes(
                section: AdminReportsHubSection.devoluciones,
                openReturnsOnly: true,
              ),
        ),
      ];

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialQuery);
    _inputFocus = FocusNode();
    _query = widget.initialQuery.trim();
    _hits = _quickHits();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _inputFocus.requestFocus();
      if (_query.length >= 2) _runSearch(_query);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  void _closeThen(VoidCallback action) {
    Navigator.of(context).pop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.hostContext.mounted) action();
    });
  }

  List<AdminGlobalSearchHit> _quickHits() {
    return [
      for (final a in _quickActions)
        AdminGlobalSearchHit(
          kind: AdminGlobalSearchKind.quickAction,
          title: a.$1,
          subtitle: a.$2,
          glyph: a.$3,
          onOpen: () => _closeThen(a.$4),
        ),
    ];
  }

  void _onQueryChanged(String raw) {
    final q = raw.trim();
    setState(() {
      _query = q;
      _selectedIndex = 0;
      if (q.length < 2) {
        _hits = _quickHits();
        _loading = false;
      }
    });
    _debounce?.cancel();
    if (q.length < 2) return;
    _debounce = Timer(const Duration(milliseconds: 300), () => _runSearch(q));
  }

  String _roleBadge(ProfileModel p) {
    if (p.isEntrepreneurRetailer) return 'Emprendedor';
    if (p.isImportador) return 'Proveedor';
    if (p.isAliado) return 'Minorista';
    return ProfileRoleLabels.labelEs(p.role);
  }

  String _initials(ProfileModel p) {
    final raw = (p.businessName?.trim().isNotEmpty == true)
        ? p.businessName!.trim()
        : (p.email?.trim().isNotEmpty == true)
            ? p.email!.trim()
            : p.id;
    final parts = raw.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final s = parts.first;
      return s.substring(0, s.length >= 2 ? 2 : 1).toUpperCase();
    }
    return ('${parts[0][0]}${parts[1][0]}').toUpperCase();
  }

  String _orderRef(TransactionRequestModel r) {
    final src = (r.checkoutGroupId?.trim().isNotEmpty == true)
        ? r.checkoutGroupId!.trim()
        : r.id;
    final compact = src.replaceAll('-', '');
    final take = compact.length >= 8 ? compact.substring(0, 8) : compact;
    return '#${take.toUpperCase()}';
  }

  String? _productThumb(PartModel part) {
    String? pick(String? raw) {
      final u = raw?.trim() ?? '';
      if (u.isEmpty) return null;
      if (u.startsWith('http://') || u.startsWith('https://')) return u;
      return null;
    }

    for (final u in part.imageUrls) {
      final ok = pick(u);
      if (ok != null) return ok;
    }
    return pick(part.imagenUrl);
  }

  Future<void> _runSearch(String q) async {
    if (!mounted) return;
    final gen = ++_searchGen;
    setState(() => _loading = true);
    try {
      final result = await AdminGlobalSearchService.search(q, limit: 5);
      if (!mounted || gen != _searchGen || _ctrl.text.trim() != q) return;

      final userHits = <AdminGlobalSearchHit>[
        for (final p in result.users)
          AdminGlobalSearchHit(
            kind: AdminGlobalSearchKind.user,
            title: (p.businessName?.trim().isNotEmpty == true)
                ? p.businessName!.trim()
                : (p.email?.trim() ?? p.id),
            subtitle: [
              if ((p.email ?? '').trim().isNotEmpty) p.email!.trim(),
              if ((p.rif ?? '').trim().isNotEmpty) 'RIF ${p.rif!.trim()}',
              if ((p.cedula ?? '').trim().isNotEmpty) 'CI ${p.cedula!.trim()}',
            ].join(' · '),
            glyph: LucideGlyph.users,
            badge: _roleBadge(p),
            initials: _initials(p),
            onOpen: () => _closeThen(() {
              MainShellTabController.navigateToAdminUsers(
                section: AdminUsersHubSection.cuentas,
                userId: p.id,
              );
            }),
          ),
      ];

      final orderHits = <AdminGlobalSearchHit>[
        for (final r in result.orders)
          AdminGlobalSearchHit(
            kind: AdminGlobalSearchKind.order,
            title: _orderRef(r),
            subtitle: [
              if ((r.aliadoBusinessName ?? '').trim().isNotEmpty &&
                  (r.ownerBusinessName ?? '').trim().isNotEmpty)
                '${r.aliadoBusinessName!.trim()} → ${r.ownerBusinessName!.trim()}'
              else ...[
                if ((r.aliadoBusinessName ?? '').trim().isNotEmpty)
                  r.aliadoBusinessName!.trim(),
                if ((r.ownerBusinessName ?? '').trim().isNotEmpty)
                  r.ownerBusinessName!.trim(),
              ],
              if ((r.productName ?? '').trim().isNotEmpty) r.productName!.trim(),
            ].join(' · '),
            glyph: LucideGlyph.package,
            badge: r.statusLabelEs(),
            trailing:
                '\$${r.precioTotal.toStringAsFixed(r.precioTotal == r.precioTotal.roundToDouble() ? 0 : 2)}',
            onOpen: () => _closeThen(() {
              MainShellTabController.setPendingNotificationRelatedId(r.id);
              final closed = r.status == TransactionRequestStatus.entregado ||
                  r.status == TransactionRequestStatus.rechazado;
              if (closed) {
                MainShellTabController.navigateToAdminCerradosForNotification();
              } else {
                MainShellTabController.navigateToAdminActivosForNotification();
              }
            }),
          ),
      ];

      final productHits = <AdminGlobalSearchHit>[
        for (final part in result.products)
          AdminGlobalSearchHit(
            kind: AdminGlobalSearchKind.product,
            title: part.nombre.trim().isNotEmpty ? part.nombre.trim() : 'Producto',
            subtitle: [
              if ((part.sku ?? '').trim().isNotEmpty) 'SKU ${part.sku}',
              if ((part.ownerBusinessName ?? '').trim().isNotEmpty)
                part.ownerBusinessName!.trim(),
            ].join(' · '),
            glyph: LucideGlyph.tag,
            trailing:
                '\$${part.precio.toStringAsFixed(part.precio == part.precio.roundToDouble() ? 0 : 2)}',
            imageUrl: _productThumb(part),
            onOpen: () => _closeThen(() {
              Navigator.of(widget.hostContext).push(
                MaterialPageRoute<void>(
                  builder: (_) => ProductDetailScreen(
                    part: part,
                    guestPreview: true,
                  ),
                ),
              );
            }),
          ),
      ];

      setState(() {
        _hits = [...userHits, ...orderHits, ...productHits];
        _selectedIndex = _hits.isEmpty ? 0 : 0;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || gen != _searchGen) return;
      setState(() {
        _hits = const [];
        _loading = false;
      });
    }
  }

  String _sectionLabel(AdminGlobalSearchKind kind) => switch (kind) {
        AdminGlobalSearchKind.quickAction => 'Accesos rápidos',
        AdminGlobalSearchKind.user => 'Usuarios',
        AdminGlobalSearchKind.order => 'Pedidos',
        AdminGlobalSearchKind.product => 'Productos',
      };

  LucideGlyph _sectionGlyph(AdminGlobalSearchKind kind) => switch (kind) {
        AdminGlobalSearchKind.quickAction => LucideGlyph.layoutDashboard,
        AdminGlobalSearchKind.user => LucideGlyph.users,
        AdminGlobalSearchKind.order => LucideGlyph.package,
        AdminGlobalSearchKind.product => LucideGlyph.tag,
      };

  void _moveSelection(int delta) {
    if (_hits.isEmpty) return;
    setState(() {
      _selectedIndex = (_selectedIndex + delta).clamp(0, _hits.length - 1);
    });
  }

  void _activateSelected() {
    if (_hits.isEmpty) return;
    final i = _selectedIndex.clamp(0, _hits.length - 1);
    _hits[i].onOpen();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown) {
      _moveSelection(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      _moveSelection(-1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      _activateSelected();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      Navigator.of(context).maybePop();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final isMac = Theme.of(context).platform == TargetPlatform.macOS ||
        Theme.of(context).platform == TargetPlatform.iOS;
    AdminGlobalSearchKind? lastKind;

    final body = Focus(
      autofocus: false,
      onKeyEvent: _onKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.compact)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.borderSubtle,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              widget.compact ? 10 : 14,
              8,
              10,
            ),
            child: Row(
              children: [
                LucideIcon(
                  LucideGlyph.search,
                  size: 18,
                  color: theme.textSecondary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Focus(
                    onKeyEvent: _onKey,
                    child: TextField(
                      controller: _ctrl,
                      focusNode: _inputFocus,
                      autofocus: true,
                      textInputAction: TextInputAction.search,
                      onChanged: _onQueryChanged,
                      onSubmitted: (_) => _activateSelected(),
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
                ),
                if (!widget.compact)
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
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          LucideIcon(
                            LucideGlyph.searchX,
                            size: 28,
                            color: theme.textMuted,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _query.length < 2
                                ? 'Escribe al menos 2 caracteres o elige un acceso rápido.'
                                : 'No se encontraron resultados para «$_query»',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: theme.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
                    itemCount: _hits.length,
                    itemBuilder: (context, i) {
                      final hit = _hits[i];
                      final showHeader = hit.kind != lastKind;
                      lastKind = hit.kind;
                      final selected = i == _selectedIndex;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (showHeader)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
                              child: Row(
                                children: [
                                  LucideIcon(
                                    _sectionGlyph(hit.kind),
                                    size: 14,
                                    color: theme.textMuted,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _sectionLabel(hit.kind),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: theme.textMuted,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          _HitTile(
                            hit: hit,
                            selected: selected,
                            onTap: hit.onOpen,
                            onHover: () {
                              if (_selectedIndex != i) {
                                setState(() => _selectedIndex = i);
                              }
                            },
                          ),
                        ],
                      );
                    },
                  ),
          ),
          if (!widget.compact)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                '↑↓ navegar · Enter abrir · Esc cerrar',
                style: TextStyle(
                  fontSize: 11,
                  color: theme.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );

    if (widget.compact) return body;

    return Dialog(
      backgroundColor: theme.surfaceCard,
      elevation: 16,
      shadowColor: theme.textPrimary.withOpacity(0.28),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: theme.borderSubtle),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 580),
        child: body,
      ),
    );
  }
}

class _HitTile extends StatelessWidget {
  const _HitTile({
    required this.hit,
    required this.selected,
    required this.onTap,
    required this.onHover,
  });

  final AdminGlobalSearchHit hit;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onHover;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    return MouseRegion(
      onEnter: (_) => onHover(),
      child: Material(
        color: selected ? theme.brandContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              children: [
                _Leading(hit: hit),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              hit.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: theme.textPrimary,
                              ),
                            ),
                          ),
                          if ((hit.trailing ?? '').isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Text(
                              hit.trailing!,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: theme.textPrimary,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (hit.subtitle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          hit.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if ((hit.badge ?? '').isNotEmpty) ...[
                  const SizedBox(width: 8),
                  _Pill(label: hit.badge!),
                ],
                const SizedBox(width: 4),
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
    );
  }
}

class _Leading extends StatelessWidget {
  const _Leading({required this.hit});
  final AdminGlobalSearchHit hit;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final url = hit.imageUrl?.trim();
    if (url != null && url.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(
          url,
          width: 36,
          height: 36,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _glyphBox(theme),
        ),
      );
    }
    if ((hit.initials ?? '').isNotEmpty) {
      return Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: theme.surfaceSubtle,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: theme.borderSubtle),
        ),
        child: Text(
          hit.initials!,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: theme.textPrimary,
          ),
        ),
      );
    }
    return _glyphBox(theme);
  }

  Widget _glyphBox(B2BThemeExtension theme) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: theme.brandContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: LucideIcon(hit.glyph, size: 18, color: theme.brand),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    return Container(
      constraints: const BoxConstraints(maxWidth: 110),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: theme.surfaceSubtle,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: theme.borderSubtle),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: theme.textSecondary,
        ),
      ),
    );
  }
}
