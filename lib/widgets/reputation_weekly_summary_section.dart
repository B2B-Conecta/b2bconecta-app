import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

import '../models/reputation_weekly_snapshot_model.dart';
import '../services/supabase_service.dart';
import '../utils/app_date_format.dart';
import '../utils/rating_scale_labels.dart';
import 'profile_section_helpers.dart';

/// Resumen de cierres semanales (E2.2 métrica global).
class ReputationWeeklySummarySection extends StatefulWidget {
  const ReputationWeeklySummarySection({super.key});

  @override
  State<ReputationWeeklySummarySection> createState() =>
      _ReputationWeeklySummarySectionState();
}

class _ReputationWeeklySummarySectionState
    extends State<ReputationWeeklySummarySection> {
  bool _loading = true;
  String? _error;
  List<ReputationWeeklySnapshotModel> _weeks = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final weeks = await SupabaseService.listMyReputationWeeklySnapshots(
        limit: 8,
      );
      if (!mounted) return;
      setState(() {
        _weeks = weeks;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _sectionSubtitle() {
    if (_loading) return 'Cargando…';
    if (_weeks.isEmpty) return 'Sin cierres todavía';
    final latest = _weeks.first;
    final avg = latest.avgOverall;
    if (avg != null) {
      return 'Última semana: ${avg.toStringAsFixed(1)} · ${latest.ratingCount} valoraciones';
    }
    return '${_weeks.length} semana(s) registrada(s)';
  }

  @override
  Widget build(BuildContext context) {
    return ProfileCollapsibleSection(
      title: 'Resumen semanal',
      subtitle: _sectionSubtitle(),
      initiallyExpanded: _weeks.isNotEmpty,
      infoMessage:
          'Promedio semanal · cierre los lunes',
      trailingActions: [
        IconButton(
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh, size: 18),
          tooltip: 'Actualizar',
          visualDensity: VisualDensity.compact,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (_error != null)
            Text(
              _error!,
              style: TextStyle(fontSize: 11, color: Colors.red.shade800),
            )
          else if (_weeks.isEmpty)
            Text(
              'Sin cierres semanales todavía.',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            )
          else
            ..._weeks.map(_weekRow),
        ],
      ),
    );
  }

  Widget _weekRow(ReputationWeeklySnapshotModel w) {
    final avg = w.avgOverall;
    final stars = avg != null ? avg.round().clamp(1, 5) : 0;
    const maxBar = 5.0;
    final barW = avg != null ? (avg / maxBar).clamp(0.0, 1.0) : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              formatEsWeekRange(w.weekStart),
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: barW,
                minHeight: 8,
                backgroundColor: Colors.grey.shade200,
                color: stars > 0
                    ? ratingValueColor(stars)
                    : Colors.grey.shade400,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 52,
            child: Text(
              avg != null ? avg.toStringAsFixed(1) : '—',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
            ),
          ),
          SizedBox(
            width: 28,
            child: Text(
              '${w.ratingCount}',
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
