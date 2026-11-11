import 'package:flutter/material.dart';

import '../../core/widgets/ios_chrome.dart';

/// A single rounded surface owns both toolbar and collapsing search.
class AliadoHomeHeader extends StatelessWidget {
  const AliadoHomeHeader({
    super.key,
    required this.identity,
    required this.actions,
    required this.searchAction,
    required this.search,
  });

  final Widget Function(bool compact) identity;
  final List<Widget> actions;
  final Widget searchAction;
  final Widget search;

  @override
  Widget build(BuildContext context) {
    final extra =
        (MediaQuery.textScalerOf(context).scale(16) - 16).clamp(0.0, 32.0);
    return SliverPersistentHeader(
      pinned: true,
      delegate: _HeaderDelegate(
        topInset: MediaQuery.paddingOf(context).top,
        toolbarHeight: 64 + extra * 2,
        searchHeight: 66 + extra,
        search: search,
        toolbar: (progress) {
          final compact = progress > .3;
          final buttons = Row(mainAxisSize: MainAxisSize.min, children: [
            if (compact)
              Opacity(
                opacity: ((progress - .3) / .7).clamp(0, 1),
                child: searchAction,
              ),
            ...actions,
          ]);
          return Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 10, 4),
            child: Row(children: [
              Expanded(child: identity(compact)),
              buttons,
            ]),
          );
        },
      ),
    );
  }
}

class _HeaderDelegate extends SliverPersistentHeaderDelegate {
  const _HeaderDelegate(
      {required this.topInset,
      required this.toolbarHeight,
      required this.searchHeight,
      required this.toolbar,
      required this.search});
  final double topInset;
  final double toolbarHeight;
  final double searchHeight;
  final Widget Function(double progress) toolbar;
  final Widget search;
  @override
  double get minExtent => topInset + toolbarHeight;
  @override
  double get maxExtent => minExtent + searchHeight;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final progress = (shrinkOffset / searchHeight).clamp(0.0, 1.0);
    final compact = progress > .3;
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final opacity = reducedMotion
        ? (compact ? 0.0 : 1.0)
        : 1 - Curves.easeOut.transform((progress / .7).clamp(0.0, 1.0));
    final dark = Theme.of(context).brightness == Brightness.dark;
    final glass = progress > 0 && !MediaQuery.highContrastOf(context);
    final color = dark ? const Color(0xFF0A317B) : const Color(0xFF004BDD);
    return IosGlass(
      tint: color.withOpacity(glass ? 1 - .16 * progress : 1),
      border: const Color(0x29FFFFFF),
      radius: const BorderRadius.vertical(bottom: Radius.circular(24)),
      blur: glass,
      child: Material(
        type: MaterialType.transparency,
        child: Stack(fit: StackFit.expand, children: [
          Positioned(
              top: topInset,
              left: 0,
              right: 0,
              height: toolbarHeight,
              child: toolbar(reducedMotion ? (compact ? 1 : 0) : progress)),
          if (opacity > 0)
            Positioned(
                top: minExtent,
                left: 0,
                right: 0,
                height: searchHeight,
                child: ExcludeFocus(
                    excluding: compact,
                    child: ExcludeSemantics(
                        excluding: compact,
                        child: IgnorePointer(
                            ignoring: compact,
                            child: Opacity(opacity: opacity, child: search))))),
        ]),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _HeaderDelegate oldDelegate) =>
      topInset != oldDelegate.topInset ||
      toolbarHeight != oldDelegate.toolbarHeight ||
      searchHeight != oldDelegate.searchHeight ||
      toolbar != oldDelegate.toolbar ||
      search != oldDelegate.search;
}
