import 'dart:math' as math;
import 'package:flutter/widgets.dart';

/// The artwork keeps its own proportions; space around it is not painted.
Size promoBannerImageSize(double availableWidth, double aspectRatio) {
  final ratio = aspectRatio.isFinite && aspectRatio > 0 ? aspectRatio : 3.0;
  final maxHeight = availableWidth < 600 ? 180.0 : 220.0;
  final width = math.min(availableWidth, maxHeight * ratio);
  return Size(width, width / ratio);
}
