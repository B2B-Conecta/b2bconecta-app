import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/widgets/motolink_pro_logo.dart';

/// Entrada de teléfono: fondo azul, isotipo blanco y «por B2B Conecta».
/// Cuando [reveal] pasa a true, la cortina sube y queda el panel.
class PhoneBrandIntro extends StatefulWidget {
  const PhoneBrandIntro({
    super.key,
    required this.reveal,
    required this.child,
    required this.onFinished,
  });

  final bool reveal;
  final Widget child;
  final VoidCallback onFinished;

  @override
  State<PhoneBrandIntro> createState() => _PhoneBrandIntroState();
}

class _PhoneBrandIntroState extends State<PhoneBrandIntro>
    with TickerProviderStateMixin {
  late final AnimationController _enter;
  late final AnimationController _exit;
  bool _exitStarted = false;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _exit = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeReveal());
  }

  @override
  void didUpdateWidget(PhoneBrandIntro oldWidget) {
    super.didUpdateWidget(oldWidget);
    _maybeReveal();
  }

  void _maybeReveal() {
    if (!widget.reveal || _exitStarted || !mounted) return;
    _exitStarted = true;
    Future<void>.delayed(const Duration(milliseconds: 750), () {
      if (!mounted) return;
      _exit.forward().whenComplete(() {
        if (mounted) widget.onFinished();
      });
    });
  }

  @override
  void dispose() {
    _enter.dispose();
    _exit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        AnimatedBuilder(
          animation: Listenable.merge([_enter, _exit]),
          builder: (context, _) {
            final enter = Curves.easeOutCubic.transform(_enter.value);
            final leave = Curves.easeInCubic.transform(_exit.value);
            return IgnorePointer(
              ignoring: leave > 0.92,
              child: Transform.translate(
                offset: Offset(0, -leave * height),
                child: ColoredBox(
                  color: AppColors.brandBlue,
                  child: Opacity(
                    opacity: (1 - leave).clamp(0.0, 1.0),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Center(
                          child: Transform.scale(
                            scale: 0.9 + (0.1 * enter),
                            child: Opacity(
                              opacity: enter,
                              child: const B2bConectaMark(
                                size: 104,
                                forceWhite: true,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 24,
                          right: 24,
                          bottom: MediaQuery.paddingOf(context).bottom + 36,
                          child: Opacity(
                            opacity: ((enter - 0.25) / 0.75).clamp(0.0, 1.0),
                            child: const Text(
                              'por B2B Conecta',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.2,
                                decoration: TextDecoration.none,
                                decorationColor: AppColors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
