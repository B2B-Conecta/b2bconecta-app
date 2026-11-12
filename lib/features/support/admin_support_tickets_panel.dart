import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/main_shell_tab.dart';
import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'package:motolink_pro_app/core/layout/app_breakpoints.dart';
import 'package:motolink_pro_app/core/layout/list_page_bar.dart';
import 'package:motolink_pro_app/core/utils/app_date_format.dart';
import 'package:motolink_pro_app/core/widgets/admin_list_skeleton.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';
import 'package:motolink_pro_app/core/widgets/segmented_filter_bar.dart';
import 'package:motolink_pro_app/features/admin/unified_action_dialog.dart';
import 'package:motolink_pro_app/features/support/support_ticket_category.dart';
import 'package:motolink_pro_app/features/support/support_ticket_detail_screen.dart';
import 'package:motolink_pro_app/features/support/support_ticket_model.dart';
import 'package:motolink_pro_app/features/support/support_ticket_status.dart';

enum _AdminSupportFilter { abiertos, enRevision, cerrados, todos }

/// Ancho mínimo para lista + detalle lado a lado.
const double _kMasterDetailMinWidth = 840;
const double _kMasterListMinWidth = 340;
const double _kMasterListFlex = 35;

/// Admin: bandeja de reclamos / Centro de Resolución B2B.
class AdminSupportTicketsPanel extends StatefulWidget {
  const AdminSupportTicketsPanel({super.key});

  @override
  State<AdminSupportTicketsPanel> createState() =>
      _AdminSupportTicketsPanelState();
}

class _AdminSupportTicketsPanelState extends State<AdminSupportTicketsPanel> {
  List<SupportTicketModel> _rows = [];
  bool _loading = true;
  String? _error;
  String? _selectedTicketId;
  bool _masterDetail = false;
  _AdminSupportFilter _filter = _AdminSupportFilter.abiertos;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    MainShellTabController.registerAdminSupportNotificationDeepLink(
      _onSupportNotificationDeepLink,
    );
    _load();
  }

  @override
  void dispose() {
    MainShellTabController.registerAdminSupportNotificationDeepLink(null);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSupportNotificationDeepLink() {
    final pending = MainShellTabController.peekPendingSupportTicketId() ??
        MainShellTabController.peekPendingNotificationRelatedId();
    if (pending == null) return;
    if (_rows.any((t) => t.id == pending)) {
      MainShellTabController.consumePendingSupportTicketId();
      MainShellTabController.consumePendingNotificationRelatedId();
      setState(() => _selectedTicketId = pending);
    } else if (!_loading) {
      _load();
    }
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      // Siempre todos: KPIs y pestañas se resuelven en cliente.
      final rows = await SupabaseService.listSupportTicketsForAdmin(
        openOnly: false,
      );
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _loading = false;
        if (_selectedTicketId != null &&
            !_rows.any((t) => t.id == _selectedTicketId)) {
          _selectedTicketId = null;
        }
      });
      _onSupportNotificationDeepLink();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  int get _countAbiertos =>
      _rows.where((t) => t.status == SupportTicketStatus.abierto).length;

  int get _countEnRevision =>
      _rows.where((t) => t.status == SupportTicketStatus.enRevision).length;

  int get _countResueltosHoy {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return _rows.where((t) {
      if (!t.isClosed) return false;
      final closed = t.closedAt?.toLocal() ?? t.updatedAt?.toLocal();
      if (closed == null) return false;
      final d = DateTime(closed.year, closed.month, closed.day);
      return d == today;
    }).length;
  }

  List<SupportTicketModel> get _tabRows {
    switch (_filter) {
      case _AdminSupportFilter.abiertos:
        return _rows
            .where((t) => t.status == SupportTicketStatus.abierto)
            .toList();
      case _AdminSupportFilter.enRevision:
        return _rows
            .where((t) => t.status == SupportTicketStatus.enRevision)
            .toList();
      case _AdminSupportFilter.cerrados:
        return _rows.where((t) => t.isClosed).toList();
      case _AdminSupportFilter.todos:
        return _rows;
    }
  }

  List<SupportTicketModel> get _filteredRows {
    final q = _searchCtrl.text.trim().toLowerCase();
    final base = _tabRows;
    if (q.isEmpty) return base;
    return base
        .where(
          (t) =>
              t.subject.toLowerCase().contains(q) ||
              t.creatorDisplayName.toLowerCase().contains(q) ||
              t.categoryLabel.toLowerCase().contains(q) ||
              t.id.toLowerCase().contains(q),
        )
        .toList();
  }

  Future<void> _openDetail(SupportTicketModel ticket) async {
    if (_masterDetail) {
      setState(() => _selectedTicketId = ticket.id);
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => SupportTicketDetailScreen(
          ticket: ticket,
          isAdminView: true,
        ),
      ),
    );
    await _load();
  }

  Future<void> _openManualTicketDialog() async {
    final created = await UnifiedActionDialog.show<bool>(
      context: context,
      builder: (ctx) => _AdminManualTicketDialog(
        onCreated: () => Navigator.of(ctx).pop(true),
      ),
    );
    if (created == true && mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SupportHeader(
            abiertos: _countAbiertos,
            enRevision: _countEnRevision,
            resueltosHoy: _countResueltosHoy,
            onNewTicket: _openManualTicketDialog,
            onRefresh: _load,
          ),
          const SizedBox(height: 14),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                _masterDetail =
                    constraints.maxWidth >= _kMasterDetailMinWidth;
                final listW = _masterDetail
                    ? (constraints.maxWidth * (_kMasterListFlex / 100))
                        .clamp(_kMasterListMinWidth, 420.0)
                    : constraints.maxWidth;
                final shell = DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.surfaceCard,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: theme.borderSubtle),
                    boxShadow: [
                      BoxShadow(
                        color: theme.textPrimary.withOpacity(
                          Theme.of(context).brightness == Brightness.dark
                              ? 0.28
                              : 0.05,
                        ),
                        blurRadius: 12,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: _masterDetail
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(
                                width: listW,
                                child: _buildListPane(theme),
                              ),
                              VerticalDivider(
                                width: 1,
                                thickness: 1,
                                color: theme.borderSubtle,
                              ),
                              Expanded(child: _buildDetailPane(theme)),
                            ],
                          )
                        : _buildListPane(theme),
                  ),
                );
                return shell;
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailPane(B2BThemeExtension theme) {
    final selected =
        _rows.where((t) => t.id == _selectedTicketId).firstOrNull;
    if (selected == null) {
      return const _ResolutionEmptyState();
    }
    return SupportTicketDetailScreen(
      key: ValueKey<String>('support-detail-${selected.id}'),
      ticket: selected,
      isAdminView: true,
      embedded: true,
      onTicketChanged: () => _load(silent: true),
    );
  }

  Widget _buildListPane(B2BThemeExtension theme) {
    final visible = _filteredRows;
    return ColoredBox(
      color: theme.surfaceCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              style: TextStyle(color: theme.textPrimary, fontSize: 13.5),
              decoration: InputDecoration(
                hintText: 'Buscar por asunto, ID o empresa…',
                hintStyle: TextStyle(
                  color: theme.textMuted,
                  fontSize: 13.5,
                ),
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(left: 10, right: 6),
                  child: LucideIcon(
                    LucideGlyph.search,
                    size: 18,
                    color: theme.textSecondary,
                  ),
                ),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 36,
                  minHeight: 36,
                ),
                filled: true,
                fillColor: theme.inputFill,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.borderSubtle),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.borderSubtle),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.brand, width: 1.2),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
            child: SegmentedFilterBar(
              labels: const ['Abiertos', 'En revisión', 'Cerrados', 'Todos'],
              selectedIndex: _filter.index,
              onSelected: (index) {
                setState(
                  () => _filter = _AdminSupportFilter.values[index],
                );
              },
            ),
          ),
          Expanded(
            child: _loading
                ? const AdminListSkeleton(
                    padding: EdgeInsets.fromLTRB(14, 4, 14, 16),
                  )
                : _error != null
                    ? _ErrorState(message: _error!, onRetry: _load)
                    : visible.isEmpty
                        ? RefreshIndicator(
                            onRefresh: _load,
                            color: theme.brand,
                            child: ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: const [
                                SizedBox(height: 48),
                                _InboxEmptyState(),
                              ],
                            ),
                          )
                        : PagedItems<SupportTicketModel>(
                            items: visible,
                            itemKey: (t) => t.id,
                            resetKey:
                                '${_filter.name}|${_searchCtrl.text}',
                            padding: const EdgeInsets.fromLTRB(10, 4, 10, 16),
                            separator: 6,
                            onRefresh: _load,
                            itemBuilder: (t) => _SupportTicketTile(
                              ticket: t,
                              selected: _selectedTicketId == t.id &&
                                  _masterDetail,
                              showOpenHint: !_masterDetail,
                              onTap: () => _openDetail(t),
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

// ─── Header + KPIs ───────────────────────────────────────────────────────────

class _SupportHeader extends StatelessWidget {
  const _SupportHeader({
    required this.abiertos,
    required this.enRevision,
    required this.resueltosHoy,
    required this.onNewTicket,
    required this.onRefresh,
  });

  final int abiertos;
  final int enRevision;
  final int resueltosHoy;
  final VoidCallback onNewTicket;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final narrow = MediaQuery.sizeOf(context).width < 720;
    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Soporte',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: theme.textPrimary,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Reclamos · atención a talleres y proveedores',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: theme.textSecondary,
          ),
        ),
      ],
    );

    final pills = Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _KpiPill(
          label: 'Abiertos',
          value: abiertos,
          foreground: theme.brand,
          background: theme.brandContainer,
        ),
        _KpiPill(
          label: 'En revisión',
          value: enRevision,
          foreground: theme.textPrimary,
          background: theme.surfaceSubtle,
        ),
        _KpiPill(
          label: 'Resueltos hoy',
          value: resueltosHoy,
          foreground: theme.successFg,
          background: theme.successBg,
        ),
        IconButton(
          tooltip: 'Actualizar',
          onPressed: onRefresh,
          style: IconButton.styleFrom(
            minimumSize: const Size(
              AppBreakpoints.minTouchTarget,
              AppBreakpoints.minTouchTarget,
            ),
          ),
          icon: LucideIcon(
            LucideGlyph.refreshCw,
            size: 18,
            color: theme.textSecondary,
          ),
        ),
        FilledButton.icon(
          onPressed: onNewTicket,
          style: FilledButton.styleFrom(
            backgroundColor: theme.brand,
            foregroundColor: theme.surfaceCard,
            minimumSize: const Size(0, 40),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          icon: LucideIcon(
            LucideGlyph.plus,
            size: 16,
            color: theme.surfaceCard,
          ),
          label: Text(
            narrow ? 'Nuevo' : 'Nuevo ticket manual',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: theme.surfaceCard,
            ),
          ),
        ),
      ],
    );

    if (narrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          titleBlock,
          const SizedBox(height: 12),
          pills,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: titleBlock),
        const SizedBox(width: 12),
        pills,
      ],
    );
  }
}

class _KpiPill extends StatelessWidget {
  const _KpiPill({
    required this.label,
    required this.value,
    required this.foreground,
    required this.background,
  });

  final String label;
  final int value;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: foreground.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$value',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: foreground,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Ticket row ──────────────────────────────────────────────────────────────

class _SupportTicketTile extends StatelessWidget {
  const _SupportTicketTile({
    required this.ticket,
    required this.selected,
    required this.showOpenHint,
    required this.onTap,
  });

  final SupportTicketModel ticket;
  final bool selected;
  final bool showOpenHint;
  final VoidCallback onTap;

  String _initials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final s = parts.first;
      return s.substring(0, s.length >= 2 ? 2 : 1).toUpperCase();
    }
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  String get _roleLabel =>
      ticket.authorRole == 'importador' ? 'Mayorista' : 'Minorista';

  String get _excerpt {
    final cat = ticket.categoryLabel;
    return '$cat · ${_roleLabel.toLowerCase()}';
  }

  bool get _urgent =>
      !ticket.isClosed &&
      (ticket.category == SupportTicketCategory.pago ||
          ticket.category == SupportTicketCategory.kyc);

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final t = ticket;
    final when = t.updatedAt ?? t.createdAt;

    return Material(
      color: selected ? theme.brandContainer : theme.surfaceCard,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 11, 10, 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? theme.brand.withOpacity(0.55) : theme.borderSubtle,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: theme.brandContainer,
                    child: Text(
                      _initials(t.creatorDisplayName),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: theme.brand,
                      ),
                    ),
                  ),
                  Positioned(
                    right: -4,
                    bottom: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: theme.surfaceSubtle,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: theme.borderSubtle),
                      ),
                      child: Text(
                        _roleLabel == 'Mayorista' ? 'May' : 'Min',
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          color: theme.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            t.creatorDisplayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: theme.textSecondary,
                            ),
                          ),
                        ),
                        Text(
                          _relativeEs(when),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: theme.textMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      t.subject,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: theme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _excerpt,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: theme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (_urgent)
                          _StatusChip(
                            label: 'Urgente',
                            foreground:
                                Theme.of(context).colorScheme.error,
                            background: Theme.of(context)
                                .colorScheme
                                .error
                                .withOpacity(0.12),
                          ),
                        _StatusChip.fromTicket(t, theme),
                      ],
                    ),
                    if (selected && showOpenHint) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Toque para abrir la conversación',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: theme.brand,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.foreground,
    required this.background,
  });

  factory _StatusChip.fromTicket(
    SupportTicketModel t,
    B2BThemeExtension theme,
  ) {
    if (t.isClosed) {
      return _StatusChip(
        label: 'Resuelto',
        foreground: theme.successFg,
        background: theme.successBg,
      );
    }
    if (t.status == SupportTicketStatus.enRevision) {
      return _StatusChip(
        label: 'En revisión',
        foreground: theme.textPrimary,
        background: theme.surfaceSubtle,
      );
    }
    return _StatusChip(
      label: 'Abierto',
      foreground: theme.brand,
      background: theme.brandContainer,
    );
  }

  final String label;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: foreground,
        ),
      ),
    );
  }
}

// ─── Empty / error / placeholder ─────────────────────────────────────────────

class _InboxEmptyState extends StatelessWidget {
  const _InboxEmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: theme.surfaceSubtle,
              shape: BoxShape.circle,
              border: Border.all(color: theme.borderSubtle),
            ),
            alignment: Alignment.center,
            child: LucideIcon(
              LucideGlyph.inbox,
              size: 28,
              color: theme.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Bandeja al día',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: theme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'No hay reclamos pendientes en esta categoría',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: theme.textSecondary,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResolutionEmptyState extends StatelessWidget {
  const _ResolutionEmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    return ColoredBox(
      color: theme.surfaceCard,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
            decoration: BoxDecoration(
              color: theme.surfaceSubtle,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.borderSubtle),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: theme.brandContainer,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: LucideIcon(
                    LucideGlyph.messagesSquare,
                    size: 32,
                    color: theme.brand,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Centro de Resolución B2B',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: theme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Selecciona un reclamo de la bandeja para ver la '
                  'conversación, responder al taller o proveedor y '
                  'cerrar el ticket cuando quede resuelto.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: theme.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final err = Theme.of(context).colorScheme.error;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LucideIcon(LucideGlyph.circleAlert, size: 28, color: err),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: err, fontSize: 13),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.textPrimary,
                side: BorderSide(color: theme.borderStrong),
              ),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Nuevo ticket manual ─────────────────────────────────────────────────────

class _AdminManualTicketDialog extends StatefulWidget {
  const _AdminManualTicketDialog({required this.onCreated});

  final VoidCallback onCreated;

  @override
  State<_AdminManualTicketDialog> createState() =>
      _AdminManualTicketDialogState();
}

class _AdminManualTicketDialogState extends State<_AdminManualTicketDialog> {
  final _subjectCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  String _category = SupportTicketCategory.plataforma;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final subject = _subjectCtrl.text.trim();
    final body = _bodyCtrl.text.trim();
    if (subject.isEmpty || body.isEmpty) {
      setState(() => _error = 'Asunto y descripción son obligatorios.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await SupabaseService.createSupportTicket(
        subject: subject,
        category: _category,
        body: body,
      );
      if (!mounted) return;
      widget.onCreated();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    return UnifiedActionDialog(
      title: 'Nuevo ticket manual',
      subtitle: 'Registra un reclamo interno o de seguimiento.',
      glyph: LucideGlyph.messageSquarePlus,
      tone: UnifiedActionTone.info,
      maxWidth: 480,
      busy: _busy,
      primaryEnabled: !_busy,
      primaryLabel: 'Crear ticket',
      onPrimary: _submit,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            value: _category,
            decoration: InputDecoration(
              labelText: 'Categoría',
              filled: true,
              fillColor: theme.inputFill,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            items: [
              for (final c in SupportTicketCategory.all)
                DropdownMenuItem(
                  value: c,
                  child: Text(SupportTicketCategory.labelEs(c)),
                ),
            ],
            onChanged: _busy
                ? null
                : (v) {
                    if (v != null) setState(() => _category = v);
                  },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _subjectCtrl,
            enabled: !_busy,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Asunto',
              filled: true,
              fillColor: theme.inputFill,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _bodyCtrl,
            enabled: !_busy,
            minLines: 3,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Descripción / primer mensaje',
              alignLabelWithHint: true,
              filled: true,
              fillColor: theme.inputFill,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String _relativeEs(DateTime? dt) {
  if (dt == null) return '—';
  final local = dt.toLocal();
  final d = DateTime.now().difference(local);
  if (d.inSeconds < 45) return 'Ahora';
  if (d.inMinutes < 60) return 'Hace ${d.inMinutes}m';
  if (d.inHours < 24) return 'Hace ${d.inHours}h';
  if (d.inDays < 7) return 'Hace ${d.inDays}d';
  return formatEsShortDateTime(local);
}
