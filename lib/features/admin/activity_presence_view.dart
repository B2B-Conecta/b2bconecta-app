import 'dart:async';

import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'package:motolink_pro_app/core/layout/list_page_bar.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';
import 'package:motolink_pro_app/features/admin/admin_audit_event.dart';
import 'package:motolink_pro_app/features/admin/admin_recent_activity.dart';
import 'package:motolink_pro_app/features/admin/admin_user_monitoring_panel.dart';
import 'package:motolink_pro_app/features/admin/admin_users_chrome.dart';

/// Vista Actividad: log de auditoría + presencia (sin catálogos).
typedef AdminUsersActivityLogPanel = ActivityPresenceView;

class ActivityPresenceView extends StatefulWidget {
  const ActivityPresenceView({
    super.key,
    this.presenceRequest = 0,
  });

  final int presenceRequest;

  @override
  State<ActivityPresenceView> createState() => _ActivityPresenceViewState();
}

class _ActivityPresenceViewState extends State<ActivityPresenceView> {
  final _searchCtrl = TextEditingController();
  final _activity = AdminRecentActivity();
  List<AdminAuditEvent> _events = const [];
  bool _loading = true;
  bool _usingSamples = false;
  bool _showPresence = false;
  int _pageIndex = 0;
  int _pageSize = listPageSizeOptions.first;

  static const _months = [
    'Ene',
    'Feb',
    'Mar',
    'Abr',
    'May',
    'Jun',
    'Jul',
    'Ago',
    'Sep',
    'Oct',
    'Nov',
    'Dic',
  ];

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() => _pageIndex = 0));
    if (widget.presenceRequest > 0) _showPresence = true;
    _activity.addListener(_onActivity);
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant ActivityPresenceView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.presenceRequest > 0 &&
        widget.presenceRequest != oldWidget.presenceRequest) {
      setState(() => _showPresence = true);
    }
  }

  @override
  void dispose() {
    _activity.removeListener(_onActivity);
    _activity.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onActivity() {
    if (!mounted) return;
    _applyFromFeed(_activity.snapshot);
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    await _activity.refresh();
    if (!mounted) return;
    _applyFromFeed(_activity.snapshot);
    setState(() => _loading = false);
  }

  void _applyFromFeed(AdminRecentActivitySnapshot snap) {
    final mapped = snap.items.map(_fromRecent).toList();
    final useSamples = mapped.isEmpty || snap.isFallback;
    setState(() {
      _usingSamples = useSamples;
      _events = useSamples ? AdminAuditEvent.sampleRows() : mapped;
    });
  }

  AdminAuditEvent _fromRecent(RecentActivityItem item) {
    final action = switch (item.kind) {
      RecentActivityKind.orderCreated => AdminAuditAction.orderCreated,
      RecentActivityKind.orderUpdated => AdminAuditAction.orderUpdated,
      RecentActivityKind.accountRegistered => AdminAuditAction.accountCreated,
      RecentActivityKind.accountPendingReview => AdminAuditAction.kycSubmitted,
    };
    return AdminAuditEvent(
      id: item.id,
      at: item.at,
      action: action,
      actorName: item.actorName,
      targetName: item.actorName,
      source: 'plataforma',
      detail: item.description,
    );
  }

  List<AdminAuditEvent> get _filtered {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return _events;
    return _events.where((e) {
      return e.actorName.toLowerCase().contains(q) ||
          e.targetName.toLowerCase().contains(q) ||
          e.action.labelEs.toLowerCase().contains(q) ||
          e.ipOrSource.toLowerCase().contains(q) ||
          (e.detail?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  String _formatAt(DateTime at) {
    final d = at.toLocal();
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '${d.day} ${_months[d.month - 1]} ${d.year} · $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 240),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: _showPresence ? _presencePane() : _auditPane(),
    );
  }

  Widget _presencePane() {
    return Column(
      key: const ValueKey('presence'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              _PresencePill(
                active: false,
                label: 'Auditoría',
                icon: LucideGlyph.arrowLeft,
                onTap: () => setState(() => _showPresence = false),
              ),
              const SizedBox(width: 8),
              const _PresencePill(
                active: true,
                label: 'Presencia',
                icon: LucideGlyph.activity,
                onTap: null,
              ),
            ],
          ),
        ),
        Expanded(
          child: AdminUserMonitoringPanel(
            showCatalogCoverage: true,
            presenceRequest: widget.presenceRequest,
          ),
        ),
      ],
    );
  }

  Widget _auditPane() {
    final theme = B2BThemeExtension.of(context);
    final filtered = _filtered;
    final page = sliceListPage(
      items: filtered,
      pageIndex: _pageIndex,
      pageSize: _pageSize,
    );

    return RefreshIndicator(
      key: const ValueKey('audit'),
      onRefresh: _load,
      color: AdminUsersChrome.brand,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: AdminUsersChrome.card(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Log de auditoría',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AdminUsersChrome.titleColor,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Fecha, IP/origen, acción y responsable.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AdminUsersChrome.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _PresencePill(
                      active: false,
                      label: 'Presencia',
                      icon: LucideGlyph.activity,
                      onTap: () => setState(() => _showPresence = true),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      tooltip: 'Actualizar',
                      visualDensity: VisualDensity.compact,
                      onPressed: _loading ? null : _load,
                      icon: LucideIcon(
                        LucideGlyph.refreshCw,
                        size: 16,
                        color: AdminUsersChrome.muted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _searchCtrl,
                  style: const TextStyle(fontSize: 13),
                  decoration: AdminUsersChrome.field(
                    label: 'Buscar',
                    hint: 'Actor, acción, IP…',
                  ).copyWith(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    prefixIcon: Padding(
                      padding: EdgeInsets.only(left: 10, right: 6),
                      child: LucideIcon(
                        LucideGlyph.search,
                        size: 16,
                        color: AdminUsersChrome.muted,
                      ),
                    ),
                    prefixIconConstraints:
                        const BoxConstraints(minWidth: 36, minHeight: 36),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _usingSamples
                      ? '${filtered.length} eventos de ejemplo'
                      : '${filtered.length} evento${filtered.length == 1 ? '' : 's'}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: theme.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 28),
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.2),
                      ),
                    ),
                  )
                else ...[
                  const _Header(),
                  if (page.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 28),
                      child: Text(
                        'Ningún evento coincide con la búsqueda.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.textSecondary,
                        ),
                      ),
                    )
                  else
                    for (var i = 0; i < page.length; i++)
                      _Row(
                        event: page[i],
                        zebra: i.isOdd,
                        when: _formatAt(page[i].at),
                      ),
                  ListPageBar(
                    total: filtered.length,
                    pageIndex: _pageIndex,
                    pageSize: _pageSize,
                    alwaysShow: filtered.isNotEmpty,
                    entityLabel: 'eventos',
                    onPageIndex: (index) => setState(() => _pageIndex = index),
                    onPageSize: (size) => setState(() {
                      _pageSize = size;
                      _pageIndex = 0;
                    }),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PresencePill extends StatelessWidget {
  const _PresencePill({
    required this.active,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final bool active;
  final String label;
  final LucideGlyph icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final bg = active ? theme.brand : theme.brandContainer;
    final fg = active ? theme.surfaceCard : theme.brand;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              LucideIcon(icon, size: 14, color: fg),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final compact = MediaQuery.sizeOf(context).width < 760;
    Widget cell(String label, {int flex = 2}) => Expanded(
          flex: flex,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: theme.textSecondary,
            ),
          ),
        );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: AdminUsersChrome.zebra,
        border: Border(
          bottom: BorderSide(color: AdminUsersChrome.border),
          top: BorderSide(color: AdminUsersChrome.border),
        ),
      ),
      child: Row(
        children: [
          cell('Fecha / hora', flex: 3),
          if (!compact) ...[
            cell('IP / Origen', flex: 2),
            cell('Acción', flex: 2),
            cell('Responsable', flex: 3),
          ] else
            cell('Detalle', flex: 4),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.event,
    required this.zebra,
    required this.when,
  });

  final AdminAuditEvent event;
  final bool zebra;
  final String when;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final compact = MediaQuery.sizeOf(context).width < 760;
    final actionBadge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: theme.brandContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        event.action.labelEs,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AdminUsersChrome.brand,
        ),
      ),
    );

    if (compact) {
      return ColoredBox(
        color: zebra ? AdminUsersChrome.zebra : AdminUsersChrome.rowEven,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                when,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: theme.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              actionBadge,
              const SizedBox(height: 4),
              Text(
                event.actorName,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AdminUsersChrome.titleColor,
                ),
              ),
              Text(
                '${event.ipOrSource} · ${event.detail ?? event.targetName}',
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
      );
    }

    return ColoredBox(
      color: zebra ? AdminUsersChrome.zebra : AdminUsersChrome.rowEven,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Text(
                when,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AdminUsersChrome.titleColor,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                event.ipOrSource,
                style: TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                  color: theme.textSecondary,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: actionBadge,
              ),
            ),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.actorName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AdminUsersChrome.titleColor,
                    ),
                  ),
                  Text(
                    event.detail ?? event.targetName,
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
    );
  }
}
