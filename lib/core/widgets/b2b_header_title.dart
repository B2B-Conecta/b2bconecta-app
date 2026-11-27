import 'package:flutter/material.dart';

class B2bHeaderTitle extends StatelessWidget {
  const B2bHeaderTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.signatureColor = Colors.white,
  });

  static const _signatureSize = 11.0;
  static const _gap = 3.0;

  final Text title;
  final Text? subtitle;
  final Color signatureColor;

  static double singleLineToolbarHeight(
    BuildContext context, {
    required double titleFontSize,
  }) {
    final scale = MediaQuery.textScalerOf(context);
    final defaultHeight =
        Theme.of(context).appBarTheme.toolbarHeight ?? kToolbarHeight;
    final contentHeight = scale.scale(titleFontSize) * 1.2 +
        _gap +
        scale.scale(_signatureSize) * 1.1;
    return contentHeight + 12 > defaultHeight
        ? (contentHeight + 12).ceilToDouble()
        : defaultHeight;
  }

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          title,
          if (subtitle case final text?)
            text
          else ...[
            const SizedBox(height: _gap),
            Text.rich(
              semanticsLabel: 'B2B Conecta',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              const TextSpan(
                children: [
                  TextSpan(
                    text: 'B2B',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  TextSpan(text: ' CONECTA'),
                ],
              ),
              style: TextStyle(
                color: signatureColor,
                fontSize: _signatureSize,
                height: 1.1,
                letterSpacing: 0.4,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      );
}
