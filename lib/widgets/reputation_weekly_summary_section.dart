import 'package:flutter/material.dart';

import '../models/reputation_weekly_snapshot_model.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_date_format.dart';
import '../utils/rating_scale_labels.dart';

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

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Resumen semanal',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              IconButton(
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.refresh, size: 18),
                tooltip: 'Actualizar',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          Text(
            'Promedio y volumen de valoraciones por semana (cierre los lunes).',
            style: TextStyle(
              fontSize: 10.5,
              height: 1.35,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 10),
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (_error != null)
            Text(_error!, style: TextStyle(fontSize: 11, color: Colors.red.shade800))
          else if (_weeks.isEmpty)
            Text(
              'Sin cierres semanales todavía.',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
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
                color: Colors.grey.shade800,
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
              style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
            ),
          ),
        ],
      ),
    );
  }
}
