import 'package:flutter/widgets.dart';

/// Umbral (px) para pedir la siguiente página antes de llegar al final.
const double kInfiniteScrollThreshold = 480;

/// True cuando el scroll vertical ya está cerca del final (o no hay más que
/// desplazar: el contenido no llena la pantalla).
bool infiniteScrollShouldLoadMore(
  ScrollNotification notification, {
  double threshold = kInfiniteScrollThreshold,
}) {
  if (notification.metrics.axis != Axis.vertical) return false;
  if (notification is! ScrollUpdateNotification &&
      notification is! OverscrollNotification &&
      notification is! ScrollEndNotification) {
    return false;
  }
  return notification.metrics.extentAfter <= threshold;
}

/// Si la lista no llena el viewport, pide otra página (evita el hueco en web).
void scheduleLoadMoreIfViewportNotFilled({
  required ScrollController controller,
  required bool hasMore,
  required bool isLoading,
  required VoidCallback loadMore,
  int attempt = 0,
}) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!hasMore || isLoading) return;
    if (!controller.hasClients) {
      if (attempt < 4) {
        scheduleLoadMoreIfViewportNotFilled(
          controller: controller,
          hasMore: hasMore,
          isLoading: isLoading,
          loadMore: loadMore,
          attempt: attempt + 1,
        );
      }
      return;
    }
    final position = controller.position;
    if (!position.hasContentDimensions) return;
    if (position.maxScrollExtent <= 48) {
      loadMore();
    }
  });
}
