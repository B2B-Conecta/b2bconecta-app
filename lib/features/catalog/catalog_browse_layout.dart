import 'package:flutter/material.dart';
import 'package:motolink_pro_app/core/layout/scroll_compact_layout.dart';

/// Keeps search and filter controls mounted while the optional chrome recedes.
class CatalogBrowseLayout extends StatelessWidget {
  const CatalogBrowseLayout({
    super.key,
    this.heading,
    required this.search,
    this.quickFilters,
    this.notice,
    this.promotions,
    required this.content,
    this.footer,
  });

  final Widget? heading;
  final Widget search;
  final Widget? quickFilters;
  final Widget? notice;
  final Widget? promotions;
  final Widget content;
  final Widget? footer;

  @override
  Widget build(BuildContext context) => ScrollCompactLayout(
        collapseHeadingWhenCompact: true,
        builder: (context, compact) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (heading != null)
              _CollapsingSection(
                  key: const ValueKey('catalog-heading'),
                  compact: compact,
                  child: heading!),
            search,
            if (quickFilters != null) quickFilters!,
            if (notice != null) notice!,
            if (promotions != null)
              _CollapsingSection(
                  key: const ValueKey('catalog-promotions'),
                  compact: compact,
                  child: promotions!),
            Expanded(key: const ValueKey('catalog-content'), child: content),
            if (footer != null) footer!,
          ],
        ),
      );
}

class _CollapsingSection extends StatelessWidget {
  const _CollapsingSection(
      {super.key, required this.compact, required this.child});

  final bool compact;
  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        duration: ScrollCompactLayout.motionDuration(context),
        curve: Curves.easeOutCubic,
        tween: Tween(begin: 1, end: compact ? 0 : 1),
        child: ExcludeFocus(
          excluding: compact,
          child: IgnorePointer(
            ignoring: compact,
            child: ExcludeSemantics(excluding: compact, child: child),
          ),
        ),
        builder: (context, factor, child) => ClipRect(
          child: Align(
            alignment: Alignment.topLeft,
            heightFactor: factor,
            child: Opacity(opacity: factor, child: child),
          ),
        ),
      );
}
