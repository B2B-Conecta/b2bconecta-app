import 'package:flutter/material.dart';

import '../../app/theme/b2b_theme_extension.dart';
import '../layout/app_breakpoints.dart';

AppBar desktopWorkflowAppBar(BuildContext context, String title,
    {VoidCallback? onBack, List<Widget>? actions}) {
  final theme = B2BThemeExtension.of(context);
  return AppBar(
    centerTitle: false,
    backgroundColor: theme.surfaceCard,
    foregroundColor: theme.textPrimary,
    surfaceTintColor: Colors.transparent,
    leading: BackButton(onPressed: onBack),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
    actions: actions,
  );
}

class DesktopWorkflow extends StatelessWidget {
  const DesktopWorkflow(
      {super.key, this.header, required this.body, required this.actions});

  final Widget? header;
  final Widget body;
  final Widget actions;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final stacked = Column(children: [
      if (header != null) header!,
      Expanded(child: body),
      actions,
    ]);
    if (MediaQuery.sizeOf(context).width < AppBreakpoints.mobileMenu) {
      return stacked;
    }
    return SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: LayoutBuilder(builder: (context, constraints) {
            if (constraints.maxWidth < 1000 ||
                MediaQuery.textScalerOf(context).scale(14) > 21) {
              return stacked;
            }
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(children: [
                if (header != null) header!,
                Expanded(
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Expanded(child: body),
                      const SizedBox(width: 20),
                      SizedBox(
                          width: 330,
                          child: SingleChildScrollView(
                              child: Card(
                            margin: EdgeInsets.zero,
                            color: theme.surfaceCard,
                            child: actions,
                          ))),
                    ])),
              ]),
            );
          }),
        ),
      ),
    );
  }
}
