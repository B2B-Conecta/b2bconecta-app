part of 'reputation_overview.dart';

const _reputationBlue = Color(0xFF004BDD);

String _ratingCountLabel(int count) =>
    count == 1 ? '1 valoración' : '$count valoraciones';

Color _reputationPanelColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? B2BThemeExtension.of(context).surfaceElevated
        : const Color(0xFFEBEEF8);

TextStyle _reputationHeading(BuildContext context, {double size = 18}) =>
    TextStyle(
      fontSize: size,
      height: 1.15,
      fontWeight: FontWeight.w800,
      color: B2BThemeExtension.of(context).textPrimary,
    );

AppBar _reputationAppBar(BuildContext context, String title,
    {List<Widget>? actions}) {
  if (MediaQuery.sizeOf(context).width >= AppBreakpoints.mobileMenu) {
    return desktopWorkflowAppBar(context, title, actions: actions);
  }
  return AppBar(
    backgroundColor: _reputationBlue,
    foregroundColor: Colors.white,
    titleTextStyle:
        Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white),
    surfaceTintColor: Colors.transparent,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
    ),
    toolbarHeight: MediaQuery.textScalerOf(context).scale(18) > 23 ? 96 : 72,
    titleSpacing: 8,
    title: B2bHeaderTitle(
      title: Text(title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w800)),
    ),
    actions: actions,
  );
}

class _MobileRatingPanel extends StatelessWidget {
  const _MobileRatingPanel({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: _reputationPanelColor(context),
            borderRadius: BorderRadius.circular(16)),
        child: child,
      );
}

LucideGlyph _criterionIcon(String id) {
  final key = id.toLowerCase();
  if (key.contains('pago') || key.contains('pay')) {
    return LucideGlyph.creditCard;
  }
  if (key.contains('comunic') || key.contains('commun')) {
    return LucideGlyph.messageCircle;
  }
  return LucideGlyph.clipboardCheck;
}

extension on _ReputationOverviewState {
  Widget _mobileOverview() {
    final theme = B2BThemeExtension.of(context);
    final profile = widget.profile;
    final name = profile.businessName?.trim() ?? '';
    return Scaffold(
      backgroundColor: theme.surfaceCard,
      appBar: _reputationAppBar(context, 'Mi reputación', actions: [
        IconButton(
          tooltip: 'Actualizar reputación',
          onPressed: _refreshing ? null : _refresh,
          icon: const LucideIcon(LucideGlyph.refreshCw,
              size: 21, color: Colors.white),
        ),
        const SizedBox(width: 8),
      ]),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Row(children: [
                ClipOval(
                    child: ImporterCatalogLogo(
                        storagePath: profile.logoStoragePath, size: 60)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name.isEmpty ? 'Mi tienda' : name,
                          style: _reputationHeading(context, size: 20)),
                      Text(
                          profile.isEntrepreneurRetailer
                              ? 'Tienda emprendedora'
                              : 'Tienda minorista',
                          style: TextStyle(color: theme.textSecondary)),
                    ],
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              _mobileScore(),
              const SizedBox(height: 16),
              FutureBuilder<_ReviewData>(
                future: _reviews,
                builder: (context, snapshot) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Por criterio', style: _reputationHeading(context)),
                    const SizedBox(height: 8),
                    _mobileCriteria(snapshot),
                    const SizedBox(height: 14),
                    _mobileWeek(),
                    const SizedBox(height: 14),
                    _mobileRecent(snapshot),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mobileScore() {
    final (:average, :count, :period) = _summaryStats;
    final theme = B2BThemeExtension.of(context);
    return _MobileRatingPanel(
      child: LayoutBuilder(builder: (context, constraints) {
        final compact = constraints.maxWidth < 305 ||
            MediaQuery.textScalerOf(context).scale(14) > 17;
        final info = TextButton(
          onPressed: _showCalculation,
          style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 5)),
          child: const Text('Cómo se calcula'),
        );
        final score =
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.star_rounded, size: 42, color: Color(0xFFF5A400)),
          const SizedBox(width: 9),
          Expanded(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(average == null ? 'Sin nota aún' : '${_score(average)} / 5',
                  style: _reputationHeading(context, size: 30)),
              const SizedBox(height: 3),
              Text(count == null
                  ? 'Valoraciones recibidas'
                  : '${_ratingCountLabel(count)} ${count == 1 ? 'recibida' : 'recibidas'}'),
              if (average != null)
                Text(period,
                    style: TextStyle(fontSize: 12, color: theme.textSecondary)),
            ],
          )),
        ]);
        if (compact) {
          return Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [score, info]);
        }
        return Row(children: [Expanded(child: score), info]);
      }),
    );
  }

  Widget _mobileCriteria(AsyncSnapshot<_ReviewData> snapshot) {
    final data = snapshot.data;
    final theme = B2BThemeExtension.of(context);
    return _MobileRatingPanel(
      child: data == null
          ? _loadState(snapshot.hasError)
          : data.dimensions.isEmpty
              ? const Text('Aún no hay puntuaciones por criterio.')
              : Column(children: [
                  for (final question in data.questionnaire.questions)
                    if (data.dimensions[question.id] case final stat?)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(children: [
                          LucideIcon(_criterionIcon(question.id),
                              size: 21, color: theme.brand),
                          const SizedBox(width: 10),
                          Expanded(
                              child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                        child: Text(question.displayTitle,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w700))),
                                    const SizedBox(width: 8),
                                    Text('${_score(stat.average)} / 5',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w800)),
                                  ]),
                              const SizedBox(height: 5),
                              LinearProgressIndicator(
                                value: (stat.average / 5).clamp(0.0, 1.0),
                                semanticsLabel: question.displayTitle,
                                semanticsValue: '${_score(stat.average)} de 5',
                                minHeight: 6,
                                borderRadius: BorderRadius.circular(8),
                                color: theme.brand,
                                backgroundColor: theme.borderStrong,
                              ),
                            ],
                          )),
                        ]),
                      ),
                ]),
    );
  }

  Widget _mobileWeek() => FutureBuilder<List<ReputationWeeklySnapshotModel>>(
        future: _weeks,
        builder: (context, snapshot) {
          final weeks = snapshot.data;
          final theme = B2BThemeExtension.of(context);
          final latest = weeks?.firstOrNull;
          return _MobileRatingPanel(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                LucideIcon(LucideGlyph.calendar, size: 23, color: theme.brand),
                const SizedBox(width: 10),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('Último cierre semanal',
                          style: _reputationHeading(context, size: 15)),
                      if (latest != null)
                        Text(formatEsWeekRange(latest.weekStart),
                            style: TextStyle(color: theme.textSecondary)),
                    ])),
                if (latest != null) ...[
                  const SizedBox(width: 8),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(
                        latest.avgOverall == null
                            ? '—'
                            : '${_score(latest.avgOverall!)} / 5',
                        style: _reputationHeading(context)),
                    Text(_ratingCountLabel(latest.ratingCount),
                        style: const TextStyle(fontSize: 12)),
                  ]),
                ],
              ]),
              if (weeks == null) ...[
                const SizedBox(height: 8),
                _loadState(snapshot.hasError),
              ] else if (latest == null) ...[
                const SizedBox(height: 6),
                const Text('Aún no hay cierres semanales.'),
              ] else if (weeks.length > 1)
                Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                        onPressed: () => _showWeeklyHistory(weeks),
                        child: const Text('Ver historial'))),
            ],
          ));
        },
      );

  Widget _mobileRecent(AsyncSnapshot<_ReviewData> snapshot) {
    final data = snapshot.data;
    final reviews = _sortedReviews(data);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(
            child: Text('Valoraciones recientes',
                style: _reputationHeading(context))),
        if (data != null && reviews.isNotEmpty)
          TextButton(
            onPressed: () => Navigator.of(context).push<void>(MaterialPageRoute(
                builder: (_) => _MobileRatingList(
                    reviews: reviews, questionnaire: data.questionnaire))),
            child: const Text('Ver todas'),
          ),
      ]),
      if (data == null)
        _loadState(snapshot.hasError)
      else if (reviews.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text('Aquí aparecerán las valoraciones de tus proveedores.'),
        )
      else
        for (final review in reviews.take(3))
          _MobileReviewRow(review: review, questionnaire: data.questionnaire),
    ]);
  }
}

class _MobileRatingList extends StatefulWidget {
  const _MobileRatingList({required this.reviews, required this.questionnaire});
  final List<_Review> reviews;
  final RatingQuestionnaireModel questionnaire;

  @override
  State<_MobileRatingList> createState() => _MobileRatingListState();
}

class _MobileRatingListState extends State<_MobileRatingList> {
  int? _stars;
  _Review? _selected;
  final _scroll = ScrollController(keepScrollOffset: false);

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final results = widget.reviews
        .where((review) => _stars == null || review.stars == _stars)
        .toList();
    final average =
        widget.reviews.fold<int>(0, (total, review) => total + review.stars) /
            widget.reviews.length;
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    final selected = _selected;
    return Scaffold(
      backgroundColor: theme.surfaceCard,
      appBar: _reputationAppBar(context, 'Valoraciones recibidas'),
      body: SafeArea(
          top: false,
          child: Row(children: [
            Expanded(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
                    child: Text(
                        '${_ratingCountLabel(widget.reviews.length)} · Promedio ${_score(average)} / 5',
                        style: _reputationHeading(context, size: 17))),
                if (widget.reviews.length == 100)
                  Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text('Últimas 100 valoraciones',
                          style: TextStyle(color: theme.textSecondary))),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(children: [
                    for (final stars in <int?>[null, 5, 4, 3, 2, 1])
                      Padding(
                          padding: const EdgeInsets.only(right: 7),
                          child: ChoiceChip(
                            label: Text(stars == null
                                ? 'Todas'
                                : stars == 1
                                    ? '1 estrella'
                                    : '$stars estrellas'),
                            selected: _stars == stars,
                            showCheckmark: false,
                            shape: const StadiumBorder(),
                            side: BorderSide(
                                color: _stars == stars
                                    ? _reputationBlue
                                    : theme.borderStrong),
                            selectedColor: _reputationBlue,
                            labelStyle: TextStyle(
                                color: _stars == stars
                                    ? Colors.white
                                    : theme.textPrimary),
                            onSelected: (_) {
                              if (_scroll.hasClients) _scroll.jumpTo(0);
                              setState(() {
                                _stars = stars;
                                if (stars != null &&
                                    _selected?.stars != stars) {
                                  _selected = null;
                                }
                              });
                            },
                          )),
                  ]),
                ),
                Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                    child: Text('Más recientes',
                        style: TextStyle(color: theme.textSecondary))),
                Expanded(
                    child: results.isEmpty
                        ? const Center(
                            child: Padding(
                                padding: EdgeInsets.all(24),
                                child: Text(
                                    'No hay valoraciones con esta puntuación.',
                                    textAlign: TextAlign.center)))
                        : ListView.separated(
                            controller: _scroll,
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            itemCount: results.length,
                            separatorBuilder: (_, __) =>
                                Divider(height: 1, color: theme.border),
                            itemBuilder: (_, index) => _MobileReviewRow(
                                review: results[index],
                                questionnaire: widget.questionnaire,
                                returnLabel: 'Volver a valoraciones',
                                onTap: wide
                                    ? () => setState(
                                        () => _selected = results[index])
                                    : null,
                                selected: identical(selected, results[index])),
                          )),
              ],
            )),
            if (wide) ...[
              const VerticalDivider(width: 1),
              Expanded(
                  child: selected == null
                      ? const Center(
                          child: Text(
                              'Selecciona una valoración para ver el detalle.'))
                      : _MobileReviewDetail(
                          key: ObjectKey(selected),
                          review: selected,
                          questionnaire: widget.questionnaire,
                          returnLabel: 'Volver a valoraciones',
                          embedded: true,
                        )),
            ],
          ])),
    );
  }
}

class _MobileReviewRow extends StatelessWidget {
  const _MobileReviewRow({
    required this.review,
    required this.questionnaire,
    this.returnLabel = 'Volver al resumen',
    this.onTap,
    this.selected = false,
  });
  final _Review review;
  final RatingQuestionnaireModel questionnaire;
  final String returnLabel;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final comment = review.comment.trim();
    return Ink(
      color: selected ? theme.brand.withOpacity(0.08) : null,
      child: InkWell(
        onTap: onTap ??
            () => Navigator.of(context).push<void>(MaterialPageRoute(
                builder: (_) => _MobileReviewDetail(
                    review: review,
                    questionnaire: questionnaire,
                    returnLabel: returnLabel))),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(children: [
            _AnonymousReviewerAvatar(
                size:
                    MediaQuery.textScalerOf(context).scale(14) > 19 ? 36 : 44),
            const SizedBox(width: 10),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(review.author,
                      style: _reputationHeading(context, size: 15)),
                  const SizedBox(height: 3),
                  if (comment.isNotEmpty)
                    Text(comment, maxLines: 2, overflow: TextOverflow.ellipsis),
                  if (review.date case final date?)
                    Text(formatEsShortDate(date),
                        style: TextStyle(
                            fontSize: 12, color: theme.textSecondary)),
                ])),
            const SizedBox(width: 6),
            _MobileStars(score: review.stars),
            const SizedBox(width: 4),
            LucideIcon(LucideGlyph.chevronRight,
                size: 16, color: theme.textSecondary),
          ]),
        ),
      ),
    );
  }
}

class _AnonymousReviewerAvatar extends StatelessWidget {
  const _AnonymousReviewerAvatar({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: theme.surfaceCard,
          border: Border.all(color: theme.borderStrong)),
      alignment: Alignment.center,
      child:
          LucideIcon(LucideGlyph.store, size: size * .47, color: theme.brand),
    );
  }
}

class _MobileStars extends StatelessWidget {
  const _MobileStars({required this.score, this.max = 5});
  final int score;
  final int max;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
            color: B2BThemeExtension.of(context).surfaceCard,
            border:
                Border.all(color: B2BThemeExtension.of(context).borderStrong),
            borderRadius: BorderRadius.circular(9)),
        child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.star_rounded,
                  size: 16, color: Color(0xFFF5A400)),
              const SizedBox(width: 2),
              Text('$score / $max',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
            ])),
      );
}

class _MobileReviewDetail extends StatelessWidget {
  const _MobileReviewDetail(
      {super.key,
      required this.review,
      required this.questionnaire,
      required this.returnLabel,
      this.embedded = false});
  final _Review review;
  final RatingQuestionnaireModel questionnaire;
  final String returnLabel;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final comment = review.comment.trim();
    final criteria = <({RatingQuestionModel question, int score})>[];
    for (final question in questionnaire.questions) {
      final raw = review.answers[question.id];
      final score = raw is num ? raw.toInt() : int.tryParse('$raw');
      if (score != null &&
          score >= questionnaire.scaleMin &&
          score <= questionnaire.scaleMax) {
        criteria.add((question: question, score: score));
      }
    }
    final detail = SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (embedded) ...[
              Text('Detalle de la valoración',
                  style: _reputationHeading(context)),
              const SizedBox(height: 16),
            ],
            Row(children: [
              const _AnonymousReviewerAvatar(size: 54),
              const SizedBox(width: 11),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(review.author,
                        style: _reputationHeading(context, size: 20)),
                    if (review.date case final date?)
                      Text(formatEsShortDate(date),
                          style: TextStyle(color: theme.textSecondary)),
                  ])),
            ]),
            const SizedBox(height: 16),
            _MobileRatingPanel(
                child: Column(children: [
              Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Icon(Icons.star_rounded,
                        size: 46, color: Color(0xFFF5A400)),
                    Text('${review.stars} / 5',
                        style: _reputationHeading(context, size: 38)),
                  ]),
              const SizedBox(height: 8),
              Text(
                  comment.isEmpty
                      ? 'Sin comentario escrito'
                      : 'Comentario del proveedor',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: theme.textSecondary)),
              if (comment.isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(comment,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 18,
                        height: 1.3,
                        fontWeight: FontWeight.w700)),
              ],
            ])),
            if (criteria.isNotEmpty) ...[
              const SizedBox(height: 12),
              _MobileRatingPanel(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                    Text('Puntuación por criterio',
                        style: _reputationHeading(context)),
                    const SizedBox(height: 6),
                    for (final (index, criterion) in criteria.indexed) ...[
                      if (index > 0)
                        Divider(height: 1, color: theme.borderStrong),
                      Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(children: [
                            LucideIcon(_criterionIcon(criterion.question.id),
                                size: 21, color: theme.brand),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text(criterion.question.displayTitle)),
                            const SizedBox(width: 8),
                            _MobileStars(
                                score: criterion.score,
                                max: questionnaire.scaleMax),
                          ])),
                    ],
                  ])),
            ],
            const SizedBox(height: 20),
            if (!embedded)
              FilledButton(
                onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(
                  backgroundColor: _reputationBlue,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(returnLabel, textAlign: TextAlign.center),
              ),
          ],
        ));
    if (embedded) return detail;
    return Scaffold(
      backgroundColor: theme.surfaceCard,
      appBar: _reputationAppBar(context, 'Detalle de la valoración'),
      body: detail,
    );
  }
}
