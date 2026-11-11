import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

/// Bounded backdrop blur for navigation surfaces that overlap scrolling content.
class IosGlass extends StatelessWidget {
  const IosGlass({
    super.key,
    required this.tint,
    required this.border,
    required this.radius,
    required this.child,
    this.blur = true,
  });

  final Color tint;
  final Color border;
  final BorderRadius radius;
  final Widget child;
  final bool blur;

  @override
  Widget build(BuildContext context) {
    final surface = DecoratedBox(
      decoration: BoxDecoration(color: tint, borderRadius: radius),
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(color: border),
        ),
        child: child,
      ),
    );
    // Keep the descendants mounted as the pinned header switches materials.
    final sigma = blur && !MediaQuery.highContrastOf(context) ? 16.0 : 0.0;
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: surface,
      ),
    );
  }
}

/// Keeps the hit target still while its contents compress and spring back.
class IosPressable extends StatefulWidget {
  const IosPressable({
    super.key,
    required this.onTap,
    required this.child,
    required this.radius,
  });

  final VoidCallback onTap;
  final Widget child;
  final BorderRadius radius;

  @override
  State<IosPressable> createState() => _IosPressableState();
}

class _IosPressableState extends State<IosPressable>
    with SingleTickerProviderStateMixin {
  late final _scale = AnimationController.unbounded(vsync: this, value: 1);

  void _highlight(bool pressed) {
    if (MediaQuery.disableAnimationsOf(context)) {
      _scale.value = 1;
    } else if (pressed) {
      _scale.animateTo(.95,
          duration: const Duration(milliseconds: 100), curve: Curves.easeOut);
    } else {
      _scale.animateWith(SpringSimulation(
        const SpringDescription(mass: 1, stiffness: 460, damping: 24),
        _scale.value,
        1,
        0,
      ));
    }
  }

  @override
  void dispose() {
    _scale.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: widget.onTap,
        onHighlightChanged: _highlight,
        borderRadius: widget.radius,
        child: ScaleTransition(
          scale: _scale,
          child: widget.child,
        ),
      );
}

/// Apple's system face when available, with installed system faces elsewhere.
const iosChromeFontFallback = [
  '.AppleSystemUIFont',
  'SF Pro Text',
  'Segoe UI',
  'Roboto',
  'Arial',
];
