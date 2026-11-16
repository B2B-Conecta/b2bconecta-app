import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:motolink_pro_app/app/main_shell_tab.dart';
import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'package:motolink_pro_app/core/data/supabase_access.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'package:motolink_pro_app/core/layout/app_breakpoints.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';
import 'package:motolink_pro_app/features/kyc/kyc_approved_aliado_model.dart';

enum _HitKind { action, order, sku, store }

class _Hit {
  const _Hit({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.glyph,
    required this.onOpen,
  });

  final _HitKind kind;
  final String title;
  final String subtitle;
  final LucideGlyph glyph;
  final VoidCallback onOpen;
}

/// Paleta ⌘K del importador: pedidos, SKUs y tiendas compradoras.
Future<void> showImporterCommandPalette(BuildContext context) {
  final theme = B2BThemeExtension.of(context);
  final mobile = MediaQuery.sizeOf(context).width < AppBreakpoints.mobileMenu;
  if (mobile) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: theme.dialogSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: SizedBox(
          height: MediaQuery.sizeOf(ctx).height * 0.88,
          child: const _Palette(compact: true),
        ),
      ),
    );
  }
  return showDialog<void>(
    context: context,
    barrierColor: theme.textPrimary.withOpacity(0.45),
    builder: (ctx) => Dialog(
      backgroundColor: theme.dialogSurface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: const SizedBox(
        width: 640,
        height: 520,
        child: _Palette(compact: false),
      ),
    ),
  );
}

class _Palette extends StatefulWidget {
  const _Palette({required this.compact});

  final bool compact;

  @override
  State<_Palette> createState() => _PaletteState();
}

class _PaletteState extends State<_Palette> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;
  var _loading = false;
  var _generation = 0;
  List<_Hit> _hits = const [];
  var _selected = 0;

  @override
  void initState() {
    super.initState();
    _hits = _actions();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  List<_Hit> _actions() => [
        _Hit(
          kind: _HitKind.action,
          title: 'Pedidos por confirmar',
          subtitle: 'Abrir la bandeja con el filtro de pendientes',
          glyph: LucideGlyph.shoppingCart,
          onOpen: () {
            Navigator.of(context).pop();
            MainShellTabController.navigateToImporterPedidosExplore('nuevos');
          },
        ),
        _Hit(
          kind: _HitKind.action,
          title: 'Inventario',
          subtitle: 'Productos, stock y precios',
          glyph: LucideGlyph.package,
          onOpen: () {
            Navigator.of(context).pop();
            MainShellTabController.navigateToImporterInventory();
          },
        ),
        _Hit(
          kind: _HitKind.action,
          title: 'Comisiones por pagar',
          subtitle: 'Cortes emitidos pendientes de pago',
          glyph: LucideGlyph.badgeDollarSign,
          onOpen: () {
            Navigator.of(context).pop();
            MainShellTabController.navigateToImporterPendingCommissions();
          },
        ),
      ];

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 220), () {
      unawaited(_search(value));
    });
  }

  Future<void> _search(String raw) async {
    final q = raw.trim();
    final gen = ++_generation;
    if (q.length < 2) {
      if (!mounted || gen != _generation) return;
      setState(() {
        _loading = false;
        _hits = _actions();
        _selected = 0;
      });
      return;
    }
    setState(() => _loading = true);
    final hits = await _queryHits(q);
    if (!mounted || gen != _generation) return;
    setState(() {
      _loading = false;
      _hits = hits.isEmpty ? _actions() : hits;
      _selected = 0;
    });
  }

  Future<List<_Hit>> _queryHits(String q) async {
    final uid = SupabaseAccess.currentUserId;
    if (uid == null) return const [];
    final needle = q.toLowerCase();
    final like = '%${q.replaceAll(RegExp(r'[%_,]'), ' ').trim()}%';
    final results = await Future.wait<Object?>([
      _orders(uid, needle),
      _skus(uid, like),
      _stores(needle),
    ]);
    return [
      ...results[0] as List<_Hit>,
      ...results[1] as List<_Hit>,
      ...results[2] as List<_Hit>,
    ];
  }

  Future<List<_Hit>> _orders(String uid, String needle) async {
    try {
      final rows = await SupabaseAccess.client
          .from('transaction_requests')
          .select(
            'id, status, total_ref, aliado:profiles!transaction_requests_aliado_id_fkey(business_name)',
          )
          .eq('importador_id', uid)
          .order('created_at', ascending: false)
          .limit(40);
      final hits = <_Hit>[];
      for (final raw in rows as List<dynamic>) {
        final map = Map<String, dynamic>.from(raw as Map);
        final id = map['id']?.toString() ?? '';
        final aliado = map['aliado'];
        final name = aliado is Map
            ? aliado['business_name']?.toString().trim() ?? ''
            : '';
        final status = map['status']?.toString() ?? '';
        final hay = '$id $name $status'.toLowerCase();
        if (!hay.contains(needle)) continue;
        final total = map['total_ref'];
        final amount = total is num ? total.toStringAsFixed(2) : '—';
        hits.add(_Hit(
          kind: _HitKind.order,
          title: name.isEmpty ? 'Pedido' : name,
          subtitle: '$status · USD $amount',
          glyph: LucideGlyph.shoppingCart,
          onOpen: () {
            Navigator.of(context).pop();
            MainShellTabController.openImporterOrder(id);
          },
        ));
        if (hits.length == 5) break;
      }
      return hits;
    } catch (_) {
      return const [];
    }
  }

  Future<List<_Hit>> _skus(String uid, String like) async {
    try {
      final rows = await SupabaseAccess.client
          .from('products')
          .select('name, sku')
          .eq('owner_id', uid)
          .or('name.ilike.$like,sku.ilike.$like')
          .limit(5);
      return [
        for (final raw in rows as List<dynamic>)
          () {
            final map = Map<String, dynamic>.from(raw as Map);
            final name = map['name']?.toString().trim() ?? 'Producto';
            final sku = map['sku']?.toString().trim() ?? '';
            return _Hit(
              kind: _HitKind.sku,
              title: name,
              subtitle: sku.isEmpty ? 'Inventario' : 'SKU $sku',
              glyph: LucideGlyph.package,
              onOpen: () {
                Navigator.of(context).pop();
                MainShellTabController.navigateToImporterInventorySearch(
                  sku.isEmpty ? name : sku,
                );
              },
            );
          }(),
      ];
    } catch (_) {
      return const [];
    }
  }

  Future<List<_Hit>> _stores(String needle) async {
    try {
      final rows = await SupabaseService.listKycApprovedAliadosForImportador();
      final hits = <_Hit>[];
      for (final KycApprovedAliadoModel store in rows) {
        final name = store.displayName;
        final rif = store.rif ?? '';
        if (!'$name $rif'.toLowerCase().contains(needle)) continue;
        hits.add(_Hit(
          kind: _HitKind.store,
          title: name,
          subtitle: rif.isEmpty ? 'Tienda compradora' : rif,
          glyph: LucideGlyph.store,
          onOpen: () {
            Navigator.of(context).pop();
            MainShellTabController.navigateToImporterPedidosSearch(name);
          },
        ));
        if (hits.length == 5) break;
      }
      return hits;
    } catch (_) {
      return const [];
    }
  }

  void _openSelected() {
    if (_hits.isEmpty) return;
    _hits[_selected.clamp(0, _hits.length - 1)].onOpen();
  }

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.arrowDown): _MoveIntent(1),
        SingleActivator(LogicalKeyboardKey.arrowUp): _MoveIntent(-1),
        SingleActivator(LogicalKeyboardKey.enter): _OpenIntent(),
      },
      child: Actions(
        actions: {
          _MoveIntent: CallbackAction<_MoveIntent>(onInvoke: (intent) {
            if (_hits.isEmpty) return null;
            setState(() {
              _selected = (_selected + intent.delta) % _hits.length;
              if (_selected < 0) _selected = _hits.length - 1;
            });
            return null;
          }),
          _OpenIntent: CallbackAction<_OpenIntent>(onInvoke: (_) {
            _openSelected();
            return null;
          }),
        },
        child: Material(
          color: theme.dialogSurface,
          borderRadius: BorderRadius.circular(widget.compact ? 0 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: TextField(
                  controller: _ctrl,
                  focusNode: _focus,
                  onChanged: _onChanged,
                  onSubmitted: (_) => _openSelected(),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: theme.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Pedidos, SKU o tienda…',
                    hintStyle: TextStyle(color: theme.textMuted),
                    prefixIcon: Padding(
                      padding: const EdgeInsets.only(left: 10, right: 6),
                      child: LucideIcon(
                        LucideGlyph.search,
                        size: 18,
                        color: theme.textMuted,
                      ),
                    ),
                    prefixIconConstraints:
                        const BoxConstraints(minWidth: 40, minHeight: 40),
                    suffixIcon: Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: Center(
                        child: Text(
                          '⌘K',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: theme.textMuted,
                          ),
                        ),
                      ),
                    ),
                    suffixIconConstraints:
                        const BoxConstraints(minWidth: 40, minHeight: 36),
                    filled: true,
                    fillColor: theme.inputFill,
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: theme.borderSubtle),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: theme.borderSubtle),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: theme.brand, width: 1.4),
                    ),
                  ),
                ),
              ),
              if (_loading)
                LinearProgressIndicator(
                  minHeight: 2,
                  color: theme.brand,
                  backgroundColor: theme.borderSubtle,
                ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
                  itemCount: _hits.length,
                  itemBuilder: (context, i) {
                    final hit = _hits[i];
                    final selected = i == _selected;
                    return Material(
                      color: selected ? theme.brandContainer : theme.dialogSurface,
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: hit.onOpen,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 10,
                          ),
                          child: Row(
                            children: [
                              LucideIcon(
                                hit.glyph,
                                size: 16,
                                color: selected ? theme.brand : theme.textSecondary,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      hit.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: theme.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      hit.subtitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: theme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
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

class _MoveIntent extends Intent {
  const _MoveIntent(this.delta);
  final int delta;
}

class _OpenIntent extends Intent {
  const _OpenIntent();
}
