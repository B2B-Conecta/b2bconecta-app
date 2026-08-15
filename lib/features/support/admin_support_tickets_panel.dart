import 'package:flutter/material.dart';

import 'support_ticket_model.dart';
import 'support_ticket_status.dart';
import 'support_ticket_detail_screen.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/utils/app_date_format.dart';
import 'package:motolink_pro_app/app/main_shell_tab.dart';

enum _AdminSupportFilter { abiertos, todos }

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
  String? _expandedTicketId;
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
      setState(() => _expandedTicketId = pending);
    } else if (!_loading) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
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
    final visible = _filteredRows;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Buscar por asunto o negocio…',
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true,
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: SegmentedButton<_AdminSupportFilter>(
            segments: const [
              ButtonSegment(
                value: _AdminSupportFilter.abiertos,
                label: Text('Abiertos'),
              ),
              ButtonSegment(
                value: _AdminSupportFilter.todos,
                label: Text('Todos'),
              ),
            ],
            selected: {_filter},
            onSelectionChanged: (s) {
              setState(() => _filter = s.first);
              _load();
            },
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
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
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: visible.isEmpty
                          ? ListView(
                              children: const [
                                SizedBox(height: 80),
                                Center(
                                  child: Text(
                                    'No hay reclamos en esta vista.',
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            )
                          : ListView.separated(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 0, 16, 24),
                              itemCount: visible.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, i) {
                                final t = visible[i];
                                final expanded = _expandedTicketId == t.id;
                                final color = t.isClosed
                                    ? AppColors.textSecondary
                                    : (t.status ==
                                            SupportTicketStatus.enRevision
                                        ? AppColors.brandBlue
                                        : AppColors.brand);
                                return Card(
                                  clipBehavior: Clip.antiAlias,
                                  child: InkWell(
                                    onTap: () => _openDetail(t),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color:
                                                      color.withOpacity(0.12),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
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
                                            '${t.authorRole == 'importador' ? 'Importador' : 'Aliado'} · '
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
                                          if (expanded) ...[
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
                              },
                            ),
                    ),
        ),
      ],
    );
  }
}
