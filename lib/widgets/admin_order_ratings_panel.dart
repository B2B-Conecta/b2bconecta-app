import 'package:flutter/material.dart';

import '../models/admin_order_rating_row_model.dart';
import '../models/rating_questionnaire_model.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_date_format.dart';
import 'aliado_order_experience_display.dart';
import 'order_rating_form.dart';

/// C4: expediente admin — listado de valoraciones con nombres reales.
class AdminOrderRatingsPanel extends StatefulWidget {
  const AdminOrderRatingsPanel({super.key});

  @override
  State<AdminOrderRatingsPanel> createState() => _AdminOrderRatingsPanelState();
}

class _AdminOrderRatingsPanelState extends State<AdminOrderRatingsPanel> {
  bool _loading = true;
  String? _error;
  List<AdminOrderRatingRowModel> _rows = const [];
  RatingQuestionnaireModel _aliadoQ = const RatingQuestionnaireModel(
    version: 'bucket_v1',
    questions: [],
  );
  RatingQuestionnaireModel _importadorQ = const RatingQuestionnaireModel(
    version: 'bucket_v1',
    questions: [],
  );
  int _offset = 0;
  static const _pageSize = 50;
  bool _end = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _offset = 0;
      _end = false;
    });
    try {
      final results = await Future.wait([
        SupabaseService.listAdminOrderRatings(
          limit: _pageSize,
          offset: 0,
        ),
        SupabaseService.fetchRatingQuestionnaire(
            audience: 'aliado_rates_importer'),
        SupabaseService.fetchRatingQuestionnaire(
            audience: 'importer_rates_aliado'),
      ]);
      if (!mounted) return;
      final batch = results[0] as List<AdminOrderRatingRowModel>;
      final aq = results[1] as RatingQuestionnaireModel;
      final iq = results[2] as RatingQuestionnaireModel;
      setState(() {
        _rows = batch;
        _aliadoQ = aq;
        _importadorQ = iq;
        _offset = _rows.length;
        _end = batch.length < _pageSize;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _end) return;
    setState(() => _loading = true);
    try {
      final batch = await SupabaseService.listAdminOrderRatings(
        limit: _pageSize,
        offset: _offset,
      );
      if (!mounted) return;
      setState(() {
        _rows = [..._rows, ...batch];
        _offset = _rows.length;
        _end = batch.length < _pageSize;
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

  RatingQuestionnaireModel _questionnaireFor(AdminOrderRatingRowModel r) {
    if (r.raterRole == 'aliado') return _aliadoQ;
    if (r.raterRole == 'importador') return _importadorQ;
    return const RatingQuestionnaireModel(version: 'bucket_v1', questions: []);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _rows.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _rows.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => _load(),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }
    if (_rows.isEmpty) {
      return Center(
        child: Text(
          'No hay valoraciones registradas.',
          style: TextStyle(color: Colors.grey.shade700),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _load(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        itemCount: _rows.length + (_end ? 0 : 1),
        itemBuilder: (context, i) {
          if (i == _rows.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: TextButton(
                  onPressed: _loadMore,
                  child: const Text('Cargar más'),
                ),
              ),
            );
          }
          final r = _rows[i];
          final q = _questionnaireFor(r);
          final at = r.submittedAt;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          r.raterLabelEs,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (at != null)
                        Text(
                          formatEsShortDateTime(at),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Importador: ${r.importadorName}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
                  ),
                  Text(
                    'Aliado: ${r.aliadoName}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
                  ),
                  if (r.checkoutGroupId != null &&
                      r.checkoutGroupId!.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Carrito: ${r.checkoutGroupId}',
                      style: TextStyle(
                          fontSize: 10.5, color: Colors.grey.shade600),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      AliadoExperienceStarsRow(
                        stars: r.overallStars.clamp(1, 5),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${r.overallStars} / 5',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  if (r.comment.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      '«${r.comment.trim()}»',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: Colors.grey.shade900,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                  if (r.answers.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    OrderRatingAnswersReadOnly(
                      answers: r.answers,
                      questionnaire: q,
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
