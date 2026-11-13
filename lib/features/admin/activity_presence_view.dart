import 'dart:async';

import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'package:motolink_pro_app/core/layout/app_breakpoints.dart';
import 'package:motolink_pro_app/core/layout/list_page_bar.dart';
import 'package:motolink_pro_app/core/widgets/app_date_picker.dart';
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
  final _auditScrollCtrl = ScrollController();
  final _activity = AdminRecentActivity();
  List<AdminAuditEvent> _events = const [];
  bool _loading = true;
  bool _usingSamples = false;
  bool _showPresence = false;
  int _pageIndex = 0;
  int _pageSize = listPageSizeOptions.first;

  /// `null` = todos los meses; 1–12 = mes del año actual.
  int? _monthFilter;

  /// Rango personalizado (inclusive). Si está activo, anula el filtro de mes.
  DateTimeRange? _customRange;

  static const _monthsShort = [
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

  static const _monthsFull = [
    'Enero',
    'Febrero',
    'Marzo',
    'Abril',
    'Mayo',
    'Junio',
    'Julio',
    'Agosto',
    'Septiembre',
    'Octubre',
    'Noviembre',
    'Diciembre',
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
    _auditScrollCtrl.dispose();
    super.dispose();
  }

  void _onActivity() {
    if (!mounted) return;
    _applyFromFeed(_activity.snapshot);
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    await _activity.refresh(
      orderLimit: 100,
      profileLimit: 60,
      take: 160,
    );
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
    final year = DateTime.now().year;
    final range = _customRange;
    final month = _monthFilter;

    return _events.where((e) {
      if (q.isNotEmpty) {
        final hit = e.actorName.toLowerCase().contains(q) ||
            e.targetName.toLowerCase().contains(q) ||
            e.action.labelEs.toLowerCase().contains(q) ||
            e.ipOrSource.toLowerCase().contains(q) ||
            (e.detail?.toLowerCase().contains(q) ?? false);
        if (!hit) return false;
      }

      final at = e.at.toLocal();
      if (range != null) {
        final start = DateTime(
          range.start.year,
          range.start.month,
          range.start.day,
        );
        final end = DateTime(
          range.end.year,
          range.end.month,
          range.end.day,
          23,
          59,
          59,
          999,
        );
        if (at.isBefore(start) || at.isAfter(end)) return false;
      } else if (month != null) {
        if (at.year != year || at.month != month) return false;
      }
      return true;
    }).toList();
  }

  String _formatAt(DateTime at) {
    final d = at.toLocal();
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '${d.day} ${_monthsShort[d.month - 1]} ${d.year} · $hh:$mm';
  }

  void _setPageIndex(int index) {
    final offset =
        _auditScrollCtrl.hasClients ? _auditScrollCtrl.offset : null;
    setState(() => _pageIndex = index);
    if (offset == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_auditScrollCtrl.hasClients) return;
      final max = _auditScrollCtrl.position.maxScrollExtent;
      _auditScrollCtrl.jumpTo(offset.clamp(0.0, max));
    });
  }

  void _setPageSize(int size) {
    final offset =
        _auditScrollCtrl.hasClients ? _auditScrollCtrl.offset : null;
    setState(() {
      _pageSize = size;
      _pageIndex = 0;
    });
    if (offset == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_auditScrollCtrl.hasClients) return;
      final max = _auditScrollCtrl.position.maxScrollExtent;
      _auditScrollCtrl.jumpTo(offset.clamp(0.0, max));
    });
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final first = DateTime(now.year - 2, 1, 1);
    final last = DateTime(now.year, now.month, now.day);
    final picked = await showAppDateRangeDialog(
      context: context,
      firstDate: first,
      lastDate: last,
      initialFrom: _customRange?.start,
      initialTo: _customRange?.end,
    );
    if (!mounted || picked == null) return;
    setState(() {
      _customRange = DateTimeRange(start: picked.from, end: picked.to);
      _monthFilter = null;
      _pageIndex = 0;
    });
  }

  void _clearDateFilters() {
    setState(() {
      _monthFilter = null;
      _customRange = null;
      _pageIndex = 0;
    });
  }

  String get _rangePillLabel {
    final range = _customRange;
    if (range == null) return 'Fecha';
    if (range.start.year == range.end.year &&
        range.start.month == range.end.month &&
        range.start.day == range.end.day) {
      return formatAppFilterDate(range.start);
    }
    return '${formatAppFilterDate(range.start)} – ${formatAppFilterDate(range.end)}';
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
    final mobile =
        MediaQuery.sizeOf(context).width < AppBreakpoints.mobileMenu;
    final filtered = _filtered;
    final page = sliceListPage(
      items: filtered,
      pageIndex: _pageIndex,
      pageSize: _pageSize,
    );
    final year = DateTime.now().year;
    final monthActive = _customRange == null && _monthFilter != null;
    final rangeActive = _customRange != null;

    return Column(
      key: const ValueKey('audit'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            color: AdminUsersChrome.brand,
            child: ListView(
              controller: _auditScrollCtrl,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
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
                                const SizedBox(height: 2),
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
                      if (mobile) ...[
                        TextField(
                          controller: _searchCtrl,
                          style: const TextStyle(fontSize: 13),
                          decoration: _searchDecoration(),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _MonthPill(
                              label: monthActive
                                  ? '${_monthsFull[_monthFilter! - 1]} $year'
                                  : 'Mes',
                              active: monthActive,
                              onSelected: (m) => setState(() {
                                _monthFilter = m;
                                _customRange = null;
                                _pageIndex = 0;
                              }),
                              year: year,
                              months: _monthsFull,
                              selectedMonth: _monthFilter,
                            ),
                            _FilterPill(
                              label: _rangePillLabel,
                              active: rangeActive,
                              icon: LucideGlyph.calendar,
                              onTap: _pickCustomRange,
                              onClear: rangeActive ? _clearDateFilters : null,
                            ),
                            if (monthActive || rangeActive)
                              TextButton(
                                onPressed: _clearDateFilters,
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  'Limpiar',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: theme.brand,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ] else
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _searchCtrl,
                                style: const TextStyle(fontSize: 13),
                                decoration: _searchDecoration(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _MonthPill(
                              label: monthActive
                                  ? '${_monthsFull[_monthFilter! - 1]} $year'
                                  : 'Mes',
                              active: monthActive,
                              onSelected: (m) => setState(() {
                                _monthFilter = m;
                                _customRange = null;
                                _pageIndex = 0;
                              }),
                              year: year,
                              months: _monthsFull,
                              selectedMonth: _monthFilter,
                            ),
                            const SizedBox(width: 8),
                            _FilterPill(
                              label: _rangePillLabel,
                              active: rangeActive,
                              icon: LucideGlyph.calendar,
                              onTap: _pickCustomRange,
                              onClear: rangeActive ? _clearDateFilters : null,
                            ),
                          ],
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
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                              ),
                            ),
                          ),
                        )
                      else ...[
                        const _Header(),
                        if (page.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 28),
                            child: Text(
                              'Ningún evento coincide con los filtros.',
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
                          keepScrollOffset: true,
                          onPageIndex: _setPageIndex,
                          onPageSize: _setPageSize,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  InputDecoration _searchDecoration() {
    return AdminUsersChrome.field(
      label: 'Buscar',
      hint: 'Actor, acción, IP…',
    ).copyWith(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 10,
      ),
      prefixIcon: Padding(
        padding: const EdgeInsets.only(left: 10, right: 6),
        child: LucideIcon(
          LucideGlyph.search,
          size: 16,
          color: AdminUsersChrome.muted,
        ),
      ),
      prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
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

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.active,
    required this.icon,
    required this.onTap,
    this.onClear,
  });

  final String label;
  final bool active;
  final LucideGlyph icon;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final bg = active ? theme.brandContainer : theme.surfaceSubtle;
    final fg = active ? theme.brand : theme.textSecondary;
    final border = active ? theme.brand : theme.borderSubtle;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              LucideIcon(icon, size: 14, color: fg),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 160),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: fg,
                  ),
                ),
              ),
              if (onClear != null) ...[
                const SizedBox(width: 4),
                InkWell(
                  onTap: onClear,
                  borderRadius: BorderRadius.circular(999),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: LucideIcon(
                      LucideGlyph.close,
                      size: 12,
                      color: fg,
                    ),
                  ),
                ),
              ] else ...[
                const SizedBox(width: 4),
                LucideIcon(
                  LucideGlyph.chevronDown,
                  size: 14,
                  color: fg,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MonthPill extends StatelessWidget {
  const _MonthPill({
    required this.label,
    required this.active,
    required this.onSelected,
    required this.year,
    required this.months,
    required this.selectedMonth,
  });

  final String label;
  final bool active;
  final ValueChanged<int?> onSelected;
  final int year;
  final List<String> months;
  final int? selectedMonth;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final bg = active ? theme.brandContainer : theme.surfaceSubtle;
    final fg = active ? theme.brand : theme.textSecondary;
    final border = active ? theme.brand : theme.borderSubtle;
    final nowMonth = DateTime.now().month;

    return PopupMenuButton<int?>(
      tooltip: 'Filtrar por mes',
      initialValue: selectedMonth,
      onSelected: onSelected,
      color: theme.dialogSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.borderSubtle),
      ),
      itemBuilder: (ctx) => [
        PopupMenuItem<int?>(
          value: null,
          child: Text(
            'Todos los meses',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: theme.textPrimary,
            ),
          ),
        ),
        const PopupMenuDivider(),
        for (var m = 1; m <= nowMonth; m++)
          PopupMenuItem<int?>(
            value: m,
            child: Text(
              '${months[m - 1]} $year',
              style: TextStyle(
                fontWeight:
                    selectedMonth == m ? FontWeight.w800 : FontWeight.w600,
                color: selectedMonth == m ? theme.brand : theme.textPrimary,
              ),
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 140),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ),
            ),
            const SizedBox(width: 4),
            LucideIcon(LucideGlyph.chevronDown, size: 14, color: fg),
          ],
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
    final compact =
        MediaQuery.sizeOf(context).width < AppBreakpoints.mobileMenu;
    Widget cell(String label, {int flex = 2}) => Expanded(
          flex: flex,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
    final compact =
        MediaQuery.sizeOf(context).width < AppBreakpoints.mobileMenu;
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
