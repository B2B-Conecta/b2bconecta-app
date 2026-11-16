import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Reclaims header space after scrolling, without changing scroll controllers.
/// Separate thresholds prevent small trackpad movements from toggling the UI.
class ScrollCompactLayout extends StatefulWidget {
  const ScrollCompactLayout({
    super.key,
    required this.builder,
    this.enabled = true,
    this.resetKey,
    this.scrollProgress,
    this.collapseHeadingWhenCompact,
  });

  final Widget Function(BuildContext context, bool compact) builder;
  final bool enabled;
  final Object? resetKey;

  /// Optional normalized progress for a header that follows the scroll offset.
  final ValueNotifier<double>? scrollProgress;

  /// A nested workspace can hide the list heading while preserving detail titles.
  /// Null leaves that decision to the active descendant workspace.
  final bool? collapseHeadingWhenCompact;

  static Duration motionDuration(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 160);

  @override
  State<ScrollCompactLayout> createState() => _ScrollCompactLayoutState();
}

class _ScrollCompactLayoutState extends State<ScrollCompactLayout> {
  bool _compact = false;
  bool _descendantCollapsesHeading = false;

  @override
  void initState() {
    super.initState();
    _publishHeadingPolicy();
  }

  void _publishHeadingPolicy() {
    if (widget.collapseHeadingWhenCompact == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.collapseHeadingWhenCompact == null) return;
      _CompactHeadingPolicyNotification(widget.collapseHeadingWhenCompact!)
          .dispatch(context);
    });
  }

  @override
  void didUpdateWidget(covariant ScrollCompactLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.collapseHeadingWhenCompact !=
        widget.collapseHeadingWhenCompact) {
      _publishHeadingPolicy();
    }
    if (oldWidget.resetKey != widget.resetKey || !widget.enabled) {
      _compact = false;
      widget.scrollProgress?.value = 0;
    }
  }

  bool _onScroll(ScrollNotification notification) {
    if (!widget.enabled ||
        notification.depth != 0 ||
        notification.metrics.axis != Axis.vertical) {
      return false;
    }
    if (_compact &&
        notification is OverscrollNotification &&
        notification.metrics.pixels <= 8 &&
        notification.overscroll < 0) {
      widget.scrollProgress?.value = 0;
      setState(() => _compact = false);
      return false;
    }
    if (notification is! ScrollUpdateNotification ||
        notification.scrollDelta == null ||
        notification.scrollDelta == 0) {
      return false;
    }
    // IndexedStack keeps other workspaces mounted. The viewport being scrolled
    // must own the shell's heading policy, even after switching destinations.
    if (widget.collapseHeadingWhenCompact != null) {
      _CompactHeadingPolicyNotification(widget.collapseHeadingWhenCompact!)
          .dispatch(context);
    }
    final offset = notification.metrics.pixels;
    widget.scrollProgress?.value = (offset / 70).clamp(0.0, 1.0);
    if (!_compact && offset > 64) {
      setState(() => _compact = true);
    } else if (_compact && offset <= 8) {
      setState(() => _compact = false);
    }
    // Let the enclosing desktop header receive the same main-viewport scroll.
    return false;
  }

  @override
  Widget build(BuildContext context) =>
      NotificationListener<_CompactHeadingPolicyNotification>(
        onNotification: (notification) {
          if (_descendantCollapsesHeading != notification.collapse) {
            setState(() => _descendantCollapsesHeading = notification.collapse);
          }
          return false;
        },
        child: NotificationListener<ScrollNotification>(
          onNotification: _onScroll,
          child: ScrollCompactState(
            compact: _compact,
            scrollProgress: widget.scrollProgress,
            hideHeading: _compact &&
                (widget.collapseHeadingWhenCompact ??
                    _descendantCollapsesHeading),
            child: Builder(
                builder: (context) => widget.builder(context, _compact)),
          ),
        ),
      );
}

class _CompactHeadingPolicyNotification extends Notification {
  const _CompactHeadingPolicyNotification(this.collapse);
  final bool collapse;
}

class ScrollCompactState extends InheritedWidget {
  const ScrollCompactState({
    super.key,
    required this.compact,
    this.hideHeading = false,
    this.scrollProgress,
    required super.child,
  });

  final bool compact;
  final bool hideHeading;
  final ValueListenable<double>? scrollProgress;

  static ValueListenable<double>? progressOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<ScrollCompactState>()
      ?.scrollProgress;

  static bool hideHeadingOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<ScrollCompactState>()
          ?.hideHeading ??
      false;

  static bool of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<ScrollCompactState>()
          ?.compact ??
      false;

  @override
  bool updateShouldNotify(ScrollCompactState oldWidget) =>
      compact != oldWidget.compact ||
      hideHeading != oldWidget.hideHeading ||
      scrollProgress != oldWidget.scrollProgress;
}

/// Fades a heading and releases its space in proportion to scroll progress.
class ScrollFadeHeading extends StatelessWidget {
  const ScrollFadeHeading({
    super.key,
    required this.progress,
    required this.child,
  });

  final double progress;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final remaining =
        reducedMotion ? (progress > .3 ? 0.0 : 1.0) : 1 - progress;
    if (remaining == 0) return const SizedBox.shrink();
    return ClipRect(
      child: Align(
        alignment: Alignment.topLeft,
        heightFactor: remaining,
        child: ExcludeSemantics(
          excluding: progress > .3,
          child: Opacity(
            opacity: reducedMotion
                ? 1
                : 1 - Curves.easeOut.transform((progress / .7).clamp(0.0, 1.0)),
            child: child,
          ),
        ),
      ),
    );
  }
}
