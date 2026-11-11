import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import 'motolink_pro_logo.dart';

class BrandLoadingScreen extends StatefulWidget {
  const BrandLoadingScreen({super.key});

  @override
  State<BrandLoadingScreen> createState() => _BrandLoadingScreenState();
}

class _BrandLoadingScreenState extends State<BrandLoadingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
    value: 1,
  );
  late final Animation<double> _opacity = _pulse
      .drive(CurveTween(curve: Curves.easeInOutSine))
      .drive(Tween(begin: 0.55, end: 1.0));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulse.value = 1;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.brandBlue,
        body: Semantics(
          label: 'Cargando B2B Conecta',
          child: Stack(
            fit: StackFit.expand,
            children: [
              Center(
                child: FadeTransition(
                  opacity: _opacity,
                  child: const B2bConectaMark(size: 104, forceWhite: true),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                    24, 0, 24, MediaQuery.paddingOf(context).bottom + 36),
                child: const Align(
                  alignment: Alignment.bottomCenter,
                  child: Text(
                    'por B2B Conecta',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}
