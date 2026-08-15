import 'package:flutter/material.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';

import 'rating_scale_labels.dart';

/// Slider discreto 1–5 con gradiente rojo→naranja (C4 v2).
class RatingDimensionSlider extends StatelessWidget {
  const RatingDimensionSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.compact = false,
  });

  final int? value;
  final ValueChanged<int> onChanged;
  final bool enabled;
  final bool compact;

  static const _min = 1;
  static const _max = 5;

  @override
  Widget build(BuildContext context) {
    final v = value ?? kRatingScaleDefault;
    final label = ratingValueLabelEs(v);
    final color = ratingValueColor(v);
    final trackHeight = compact ? 6.0 : 8.0;
    final thumbRadius = compact ? 10.0 : 14.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: trackHeight,
            thumbShape: RoundSliderThumbShape(enabledThumbRadius: thumbRadius),
            overlayShape: RoundSliderOverlayShape(overlayRadius: compact ? 16 : 22),
            inactiveTrackColor: AppColors.borderSubtle,
            activeTrackColor: Colors.transparent,
            thumbColor: color,
            overlayColor: color.withOpacity(0.18),
          ),
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Container(
                height: trackHeight,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(trackHeight),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE53935), Color(0xFFFF9800)],
                  ),
                ),
              ),
              Slider(
                value: v.toDouble(),
                min: _min.toDouble(),
                max: _max.toDouble(),
                divisions: _max - _min,
                onChanged: enabled
                    ? (d) => onChanged(d.round().clamp(_min, _max))
                    : null,
              ),
            ],
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Muy mal',
              style: TextStyle(
                fontSize: compact ? 9 : 10,
                color: AppColors.textSecondary,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: compact ? 12 : 14,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            Text(
              'Excelente',
              style: TextStyle(
                fontSize: compact ? 9 : 10,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Tarjeta por dimensión + zoom opcional.
class RatingDimensionCard extends StatelessWidget {
  const RatingDimensionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final String title;
  final String subtitle;
  final int? value;
  final ValueChanged<int> onChanged;
  final bool enabled;

  Future<void> _openZoom(BuildContext context) async {
    if (!enabled) return;
    var local = value ?? kRatingScaleDefault;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                16,
                20,
                MediaQuery.of(ctx).viewPadding.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.35,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  RatingDimensionSlider(
                    value: local,
                    onChanged: (v) => setModal(() => local = v),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () {
                      onChanged(local);
                      Navigator.of(ctx).pop();
                    },
                    child: const Text('Listo'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.35,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: enabled ? () => _openZoom(context) : null,
                  icon: const Icon(Icons.zoom_out_map, size: 20),
                  tooltip: 'Ampliar',
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 8),
            RatingDimensionSlider(
              value: value,
              onChanged: onChanged,
              enabled: enabled,
            ),
          ],
        ),
        ),
      ),
    );
  }
}
