import 'package:flutter/material.dart';

/// Shared geometry for the retailer's expanded, collapsed and static headers.
abstract final class AliadoHeaderMetrics {
  static const toolbarPadding = EdgeInsets.fromLTRB(14, 10, 10, 8);
  static const searchPadding = EdgeInsets.fromLTRB(14, 2, 14, 14);

  static double _textExtra(BuildContext context) =>
      (MediaQuery.textScalerOf(context).scale(16) - 16).clamp(0.0, 32.0);

  static double topInset(BuildContext context) =>
      MediaQuery.viewPaddingOf(context).top + 6;

  static double toolbarHeight(BuildContext context) =>
      68 + _textExtra(context) * 2;

  static double searchHeight(BuildContext context) => 70 + _textExtra(context);
}
