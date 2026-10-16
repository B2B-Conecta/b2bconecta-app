import 'dart:async';

import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'package:motolink_pro_app/core/layout/list_page_bar.dart';
import 'package:motolink_pro_app/core/utils/app_date_format.dart';
import 'package:motolink_pro_app/features/admin/user_presence.dart';
import 'package:motolink_pro_app/features/profile/profile_role_labels.dart';

/// Lista de presencia, de 10 en 10 (máximo 20), dentro de Ingresos.
class AdminUserPresenceSection extends StatefulWidget {
  const AdminUserPresenceSection({super.key, this.loadRows});

  final Future<List<AdminUserPresenceRow>> Function()? loadRows;

  @override
  State<AdminUserPresenceSection> createState() =>
      _AdminUserPresenceSectionState();
}

class _AdminUserPresenceSectionState extends State<AdminUserPresenceSection> {
  List<AdminUserPresenceRow> _rows = const [];
  bool _loading = true;
  String? _error;
  Timer? _timer;
  int _pageIndex = 0;
  int _pageSize = listPageSizeOptions.first;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      unawaited(_load(silent: true));
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final rows = await (widget.loadRows ?? SupabaseService.listAdminUserPresence)();
      if (!mounted) return;
      setState(() {
        _rows = _sorted(rows);
        _pageIndex = clampListPageIndex(
          pageIndex: _pageIndex,
          total: _rows.length,
          pageSize: _pageSize,
        );
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'No se pudo cargar la presencia.';
      });
    }
  }

  List<AdminUserPresenceRow> _sorted(List<AdminUserPresenceRow> rows) {
    final now = DateTime.now();
    final copy = [...rows];
    copy.sort((a, b) {
      final online = (b.isOnlineAt(now) ? 1 : 0) - (a.isOnlineAt(now) ? 1 : 0);
      if (online != 0) return online;
      final aSeen = a.lastSeenAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bSeen = b.lastSeenAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bSeen.compareTo(aSeen);
    });
    return copy;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final online = _rows.where((r) => r.isOnlineAt(now)).length;
    final page = sliceListPage(
      items: _rows,
      pageIndex: _pageIndex,
      pageSize: _pageSize,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Presencia en línea',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Text(
              _loading ? '…' : '$online en línea',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.brand,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          'Actividad de los últimos 5 minutos. Una cuenta, una fila.',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 8),
        if (_error != null)
          Text(
            _error!,
            style: TextStyle(color: Colors.red.shade800, fontSize: 13),
          )
        else if (_loading && _rows.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else if (_rows.isEmpty)
          Text(
            'Todavía no hay actividad reciente.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          )
        else ...[
          for (final row in page) _PresenceRow(row: row, now: now),
          ListPageBar(
            total: _rows.length,
            pageIndex: _pageIndex,
            pageSize: _pageSize,
            onPageIndex: (index) => setState(() => _pageIndex = index),
            onPageSize: (size) => setState(() {
              _pageSize = size;
              _pageIndex = 0;
            }),
          ),
        ],
      ],
    );
  }
}

class _PresenceRow extends StatelessWidget {
  const _PresenceRow({required this.row, required this.now});

  final AdminUserPresenceRow row;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final online = row.isOnlineAt(now);
    final business = row.businessName?.trim();
    final sameName = business != null &&
        business.isNotEmpty &&
        business.toLowerCase() == row.displayName.trim().toLowerCase();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: online ? AppColors.successGreen : AppColors.textSecondary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      [
                        ProfileRoleLabels.labelEs(row.role),
                        if (!sameName && business != null && business.isNotEmpty)
                          business,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _PresenceBadge(online: online),
                  const SizedBox(height: 4),
                  Text(
                    formatEsShortDateTime(row.lastSeenAt),
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PresenceBadge extends StatelessWidget {
  const _PresenceBadge({required this.online});

  final bool online;

  @override
  Widget build(BuildContext context) {
    final color = online ? AppColors.successGreen : AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        online ? 'En línea' : 'Ausente',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}
