import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'package:motolink_pro_app/core/layout/list_page_bar.dart';

void main() {
  testWidgets('ListPageBar keeps scroll offset when changing page',
      (tester) async {
    var page = 0;
    final controller = ScrollController();

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          extensions: const [B2BThemeExtension.light],
        ),
        home: Scaffold(
          body: ListView(
            controller: controller,
            children: [
              const SizedBox(height: 800),
              StatefulBuilder(
                builder: (context, setState) {
                  return ListPageBar(
                    total: 40,
                    pageIndex: page,
                    pageSize: 10,
                    alwaysShow: true,
                    onPageIndex: (i) => setState(() => page = i),
                  );
                },
              ),
              const SizedBox(height: 800),
            ],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    controller.jumpTo(420);
    await tester.pumpAndSettle();
    expect(controller.offset, closeTo(420, 0.5));

    await tester.tap(find.byTooltip('Siguiente'));
    await tester.pump();
    await tester.pump(); // post-frame restore
    expect(page, 1);
    expect(controller.offset, closeTo(420, 0.5));
  });
}
