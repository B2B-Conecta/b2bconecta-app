import 'package:flutter/material.dart';

import 'app_breakpoints.dart';

/// Layout responsive compartido para paneles de pedidos (aliado / importador).
abstract final class B2bOrdersPanelLayout {
  static bool isDesktop(double width) => width >= AppBreakpoints.b2bDesktop;

  /// Padding horizontal de listas: el marco de escritorio ya aporta margen.
  static double listHorizontalPadding(double width) => isDesktop(width) ? 0 : 16;

  static double listBottomPadding(double width) => isDesktop(width) ? 8 : 24;

  /// Botones de acción en fila en pantallas anchas.
  static bool useHorizontalActionButtons(double width) => width >= 600;

  /// Ancho máximo útil para barras de búsqueda en escritorio.
  static double searchMaxWidth(double width) =>
      isDesktop(width) ? 560 : double.infinity;

  /// Ancho máximo del contenido expandido de una ficha (evita líneas muy largas).
  static double expandedSectionMaxWidth(double width) =>
      isDesktop(width) ? orderCardMaxWidth(width) : double.infinity;

  /// Ancho máximo de cada ficha de pedido en listas B2B (escritorio).
  static double orderCardMaxWidth(double width) =>
      isDesktop(width) ? AppBreakpoints.formMaxWidth : double.infinity;

  static double sectionGap(double width) => isDesktop(width) ? 8 : 8;

  /// Centra y limita el ancho de fichas, títulos y controles de lista en escritorio.
  static Widget listColumn(BuildContext context, Widget child) {
    final width = MediaQuery.sizeOf(context).width;
    final maxW = orderCardMaxWidth(width);
    final pad = listHorizontalPadding(width);

    var content = child;
    if (pad > 0) {
      content = Padding(
        padding: EdgeInsets.symmetric(horizontal: pad),
        child: content,
      );
    }

    if (maxW >= width) return content;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW),
        child: content,
      ),
    );
  }

  /// Envuelve el contenido expandido de una ficha (ancho máximo + alineación).
  static Widget expandedContent(BuildContext context, Widget child) {
    final width = MediaQuery.sizeOf(context).width;
    final maxW = expandedSectionMaxWidth(width);
    if (maxW >= width) return child;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW),
        child: child,
      ),
    );
  }
}

/// Tipografía, espaciado y botones compactos para fichas de pedido en escritorio.
class B2bOrderCardDensity {
  const B2bOrderCardDensity._({required this.isDesktop});

  final bool isDesktop;

  factory B2bOrderCardDensity.of(double width) {
    return B2bOrderCardDensity._(
      isDesktop: B2bOrdersPanelLayout.isDesktop(width),
    );
  }

  factory B2bOrderCardDensity.ofContext(BuildContext context) {
    return B2bOrderCardDensity.of(MediaQuery.sizeOf(context).width);
  }

  double get productTitleSize => isDesktop ? 13.0 : 15.0;
  double get trackingHeadlineSize => isDesktop ? 10.0 : 11.0;
  double get metaTextSize => isDesktop ? 10.5 : 12.0;
  double get skuTextSize => isDesktop ? 9.5 : 11.0;
  double get secondaryTextSize => isDesktop ? 10.0 : 11.0;

  double get sectionTitleSize => isDesktop ? 12.0 : 13.5;
  double get sectionSubtitleSize => isDesktop ? 10.5 : 11.5;

  double get panelCardTitleSize => isDesktop ? 12.0 : 13.5;
  double get panelCardSubtitleSize => isDesktop ? 11.0 : 12.5;
  double get panelCardIconSize => isDesktop ? 16.0 : 20.0;

  double get contentTitleSize => isDesktop ? 11.0 : 12.0;
  double get contentBodySize => isDesktop ? 10.5 : 11.5;
  double get contentSmallSize => isDesktop ? 9.5 : 10.5;

  double get chipLabelSize => isDesktop ? 9.0 : 10.0;

  EdgeInsets get cardHeaderPadding => isDesktop
      ? const EdgeInsets.fromLTRB(10, 8, 6, 8)
      : const EdgeInsets.fromLTRB(12, 10, 8, 10);

  EdgeInsets get cardExpandedPadding => isDesktop
      ? const EdgeInsets.fromLTRB(10, 0, 10, 10)
      : const EdgeInsets.fromLTRB(12, 0, 12, 12);

  EdgeInsets get sectionHeaderPadding => isDesktop
      ? const EdgeInsets.fromLTRB(10, 8, 6, 8)
      : const EdgeInsets.fromLTRB(12, 12, 8, 12);

  EdgeInsets get sectionBodyPadding => isDesktop
      ? const EdgeInsets.fromLTRB(10, 0, 10, 8)
      : const EdgeInsets.fromLTRB(12, 0, 12, 12);

  EdgeInsets get panelCardPadding => isDesktop
      ? const EdgeInsets.all(10)
      : const EdgeInsets.all(14);

  double get sectionBorderRadius => isDesktop ? 8.0 : 12.0;
  double get cardMarginBottom => isDesktop ? 8.0 : 10.0;

  double get buttonMinHeight => isDesktop ? 34.0 : 44.0;
  double get buttonTextSize => isDesktop ? 12.0 : 14.0;
  double get buttonIconSize => isDesktop ? 16.0 : 20.0;

  EdgeInsets get buttonPadding => isDesktop
      ? const EdgeInsets.symmetric(horizontal: 10, vertical: 6)
      : const EdgeInsets.symmetric(horizontal: 16, vertical: 12);

  VisualDensity get buttonVisualDensity =>
      isDesktop ? VisualDensity.compact : VisualDensity.standard;

  Size get actionButtonMinSize => Size(0, buttonMinHeight);

  ButtonStyle outlinedButtonStyle({Color? foregroundColor}) {
    return OutlinedButton.styleFrom(
      foregroundColor: foregroundColor,
      minimumSize: actionButtonMinSize,
      padding: buttonPadding,
      textStyle: TextStyle(fontSize: buttonTextSize),
      visualDensity: buttonVisualDensity,
    );
  }

  ButtonStyle filledButtonStyle({Color? backgroundColor}) {
    return FilledButton.styleFrom(
      backgroundColor: backgroundColor,
      minimumSize: actionButtonMinSize,
      padding: buttonPadding,
      textStyle: TextStyle(fontSize: buttonTextSize),
      visualDensity: buttonVisualDensity,
    );
  }
}

/// Propaga densidad compacta a secciones hijas de una ficha de pedido.
class B2bOrderCardDensityScope extends InheritedWidget {
  const B2bOrderCardDensityScope({
    super.key,
    required this.density,
    required super.child,
  });

  final B2bOrderCardDensity density;

  static B2bOrderCardDensity of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<B2bOrderCardDensityScope>();
    return scope?.density ?? B2bOrderCardDensity.ofContext(context);
  }

  static B2bOrderCardDensity? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<B2bOrderCardDensityScope>()
        ?.density;
  }

  @override
  bool updateShouldNotify(covariant B2bOrderCardDensityScope oldWidget) =>
      density.isDesktop != oldWidget.density.isDesktop;
}
