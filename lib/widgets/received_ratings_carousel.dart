import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Carrusel horizontal de tarjetas de valoración (E2 — panel dedicado).
class ReceivedRatingsCarousel extends StatefulWidget {
  const ReceivedRatingsCarousel({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.height = 360,
  });

  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;
  final double height;

  @override
  State<ReceivedRatingsCarousel> createState() =>
      _ReceivedRatingsCarouselState();
}

class _ReceivedRatingsCarouselState extends State<ReceivedRatingsCarousel> {
  late final PageController _pageController;
  int _pageIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.92);
  }

  @override
  void didUpdateWidget(covariant ReceivedRatingsCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.itemCount != widget.itemCount) {
      _pageIndex = 0;
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.itemCount;
    if (count == 0) return const SizedBox.shrink();
    final showPager = count > 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showPager) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: _pageIndex > 0
                    ? () => _pageController.previousPage(
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeOut,
                        )
                    : null,
                icon: const Icon(Icons.chevron_left),
                visualDensity: VisualDensity.compact,
                tooltip: 'Anterior',
              ),
              Text(
                '${_pageIndex + 1} / $count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade700,
                ),
              ),
              IconButton(
                onPressed: _pageIndex < count - 1
                    ? () => _pageController.nextPage(
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeOut,
                        )
                    : null,
                icon: const Icon(Icons.chevron_right),
                visualDensity: VisualDensity.compact,
                tooltip: 'Siguiente',
              ),
            ],
          ),
          const SizedBox(height: 4),
        ],
        SizedBox(
          height: widget.height,
          child: PageView.builder(
            controller: _pageController,
            itemCount: count,
            onPageChanged: (i) => setState(() => _pageIndex = i),
            itemBuilder: (context, i) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: widget.itemBuilder(context, i),
                ),
              );
            },
          ),
        ),
        if (showPager) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(count, (i) {
              final active = i == _pageIndex;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 8 : 6,
                height: active ? 8 : 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: active
                      ? AppColors.brandBlue
                      : Colors.grey.shade400,
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}
