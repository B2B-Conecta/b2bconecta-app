import 'package:flutter/material.dart';

import 'support_ticket_model.dart';
import 'support_ticket_status.dart';
import 'support_ticket_detail_screen.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/widgets/admin_list_skeleton.dart';
import 'package:motolink_pro_app/core/widgets/segmented_filter_bar.dart';
import 'package:motolink_pro_app/core/layout/list_page_bar.dart';
import 'package:motolink_pro_app/core/utils/app_date_format.dart';
import 'package:motolink_pro_app/app/main_shell_tab.dart';

enum _AdminSupportFilter { abiertos, todos }

/// Ancho del panel a partir del cual se muestra lista + detalle lado a lado.
const double _kMasterDetailMinWidth = 840;
const double _kMasterListWidth = 380;

/// Admin: bandeja de reclamos de atención al cliente.
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
      final rows = await SupabaseService.listSupportTicketsForAdmin(
        openOnly: _filter == _AdminSupportFilter.abiertos,
      );
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _loading = false;
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

  List<SupportTicketModel> get _filteredRows {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return _rows;
    return _rows
        .where(
          (t) =>
              t.subject.toLowerCase().contains(q) ||
              t.creatorDisplayName.toLowerCase().contains(q) ||
              t.categoryLabel.toLowerCase().contains(q),
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

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _masterDetail = constraints.maxWidth >= _kMasterDetailMinWidth;
        final list = _buildList();
        if (!_masterDetail) return list;

        final selected =
            _rows.where((t) => t.id == _selectedTicketId).firstOrNull;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: _kMasterListWidth, child: list),
            VerticalDivider(width: 1, color: AppColors.divider),
            Expanded(
              child: selected == null
                  ? const _DetailPlaceholder()
                  : SupportTicketDetailScreen(
                      key: ValueKey<String>('support-detail-${selected.id}'),
                      ticket: selected,
                      isAdminView: true,
                      embedded: true,
                      onTicketChanged: () => _load(silent: true),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildList() {
    final visible = _filteredRows;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'Buscar por asunto o negocio…',
              prefixIcon: Icon(Icons.search, size: 20),
              isDense: true,
              border: OutlineInputBorder(),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: SegmentedFilterBar(
            labels: const ['Abiertos', 'Todos'],
            selectedIndex: _filter.index,
            onSelected: (index) {
              setState(() => _filter = _AdminSupportFilter.values[index]);
              _load();
            },
          ),
        ),
        Expanded(
          child: _loading
              ? const AdminListSkeleton(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 24),
                )
              : _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.red.shade800),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton(
                              onPressed: _load,
                              child: const Text('Reintentar'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : visible.isEmpty
                      ? RefreshIndicator(
                          onRefresh: _load,
                          child: ListView(
                            children: const [
                              SizedBox(height: 80),
                              Center(
                                child: Text(
                                  'No hay reclamos en esta vista.',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        )
                      : PagedItems<SupportTicketModel>(
                          items: visible,
                          itemKey: (t) => t.id,
                          resetKey: '${_filter.name}|${_searchCtrl.text}',
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          separator: 8,
                          onRefresh: _load,
                          itemBuilder: (t) => _SupportTicketTile(
                            ticket: t,
                            selected: _selectedTicketId == t.id,
                            showOpenHint: !_masterDetail,
                            onTap: () => _openDetail(t),
                          ),
                        ),
        ),
      ],
    );
  }
}

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

  @override
  Widget build(BuildContext context) {
    final t = ticket;
    final color = t.isClosed
        ? AppColors.textSecondary
        : (t.status == SupportTicketStatus.enRevision
            ? AppColors.brandBlue
            : AppColors.brand);
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      margin: EdgeInsets.zero,
      color: selected ? AppColors.brandBlueContainer : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected
              ? AppColors.brandAccent.withOpacity(0.6)
              : AppColors.borderSubtle,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      t.statusLabel,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    t.categoryLabel,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                t.subject,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${t.authorRole == 'importador' ? 'Importador' : 'Tienda minorista'} · '
                '${t.creatorDisplayName}',
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                formatEsShortDateTime(t.createdAt),
                style: TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textSecondary,
                ),
              ),
              if (selected && showOpenHint) ...[
                const SizedBox(height: 8),
                Text(
                  'Toque la fila para abrir el detalle y responder.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.brandBlue,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailPlaceholder extends StatelessWidget {
  const _DetailPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.forum_outlined,
            size: 40,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 10),
          Text(
            'Seleccione un reclamo para ver la conversación.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
