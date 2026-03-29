import 'package:flutter/material.dart';

import '../gen/motolink_pro_logo_bytes.dart';
import '../theme/app_theme.dart';

/// Logo oficial MotoLink Pro (`assets/logo_motolinkpro.png` embebido en código
/// para que siempre se pinte, también en web con `file://` o fallos de AssetManifest).
class MotoLinkProLogo extends StatelessWidget {
  const MotoLinkProLogo({
    super.key,
    required this.height,
    this.fit = BoxFit.contain,
  });

  final double height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return Image.memory(
      decodeMotoLinkProLogoPng(),
      height: height,
      fit: fit,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, __, ___) => Icon(
        Icons.two_wheeler_outlined,
        size: height * 0.65,
        color: AppColors.brand,
      ),
    );
  }
}
