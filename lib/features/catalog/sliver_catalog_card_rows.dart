import 'package:flutter/material.dart';

/// Lazy rows sized to their tallest card, without a global fixed card height.
class SliverCatalogCardRows extends StatelessWidget {
  const SliverCatalogCardRows(
      {super.key,
      required this.columns,
      required this.spacing,
      required this.itemCount,
      required this.itemBuilder});
  final int columns;
  final double spacing;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  @override
  Widget build(BuildContext context) =>
      SliverLayoutBuilder(builder: (context, constraints) {
        final count = columns < 1 ? 1 : columns;
        final width =
            (constraints.crossAxisExtent - spacing * (count - 1)) / count;
        return SliverList(
            delegate: SliverChildBuilderDelegate(
                (context, row) => Padding(
                    padding: EdgeInsets.only(bottom: spacing),
                    child: IntrinsicHeight(
                        child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                          for (var column = 0;
                              column < count &&
                                  row * count + column < itemCount;
                              column++) ...[
                            if (column > 0) SizedBox(width: spacing),
                            SizedBox(
                                width: width,
                                child:
                                    itemBuilder(context, row * count + column)),
                          ],
                        ]))),
                childCount: (itemCount + count - 1) ~/ count));
      });
}
