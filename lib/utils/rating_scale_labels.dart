import 'package:flutter/material.dart';

/// Valor inicial de cada slider dimensional (Regular).
const int kRatingScaleDefault = 3;

/// Etiquetas y color de la escala 1–5 (C4 v2: Muy mal → Excelente).
String ratingValueLabelEs(int value) {
  switch (value.clamp(1, 5)) {
    case 1:
      return 'Muy mal';
    case 2:
      return 'Mal';
    case 3:
      return 'Regular';
    case 4:
      return 'Bien';
    case 5:
      return 'Excelente';
    default:
      return '';
  }
}

Color ratingValueColor(int value) {
  final t = ((value.clamp(1, 5) - 1) / 4).toDouble();
  return Color.lerp(const Color(0xFFE53935), const Color(0xFFFF9800), t) ??
      const Color(0xFFE53935);
}

/// Promedio simple redondeado (misma regla que `resolve_rating_submission` en BD).
int overallStarsFromDimensionAnswers(Iterable<int> values) {
  final list = values.where((v) => v >= 1 && v <= 5).toList();
  if (list.isEmpty) return 0;
  final avg = list.reduce((a, b) => a + b) / list.length;
  return avg.round().clamp(1, 5);
}
