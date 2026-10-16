import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/app_theme.dart';

import 'app_breakpoints.dart';

/// Ancho máximo de los diálogos admin en escritorio.
const double kAdminDialogMaxWidth = 600;

/// Escritorio admin: barra lateral y diálogos centrados.
bool isAdminDesktopLayout(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= AppBreakpoints.adminDesktop;

/// Bottom sheet en móvil; diálogo centrado con fondo difuminado en escritorio.
///
/// [builder] recibe un [ScrollController] que el contenido puede enlazar a su
/// lista. En móvil viene de [DraggableScrollableSheet] si [draggable] es true.
/// El contenido debe tolerar altura acotada (usar [Expanded] solo si
/// [draggable] es true).
Future<T?> showAdaptiveAdminSheet<T>({
  required BuildContext context,
  required Widget Function(BuildContext context, ScrollController? scroll)
      builder,
  bool showDragHandle = true,
  bool draggable = false,
  double initialChildSize = 0.6,
  double minChildSize = 0.35,
  double maxChildSize = 0.92,
  bool isDismissible = true,
}) {
  if (!isAdminDesktopLayout(context)) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      isDismissible: isDismissible,
      showDragHandle: showDragHandle,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        if (!draggable) return builder(ctx, null);
        return DraggableScrollableSheet(
          initialChildSize: initialChildSize,
          minChildSize: minChildSize,
          maxChildSize: maxChildSize,
          expand: false,
          builder: (sheetCtx, scroll) => builder(sheetCtx, scroll),
        );
      },
    );
  }

  return showDialog<T>(
    context: context,
    barrierDismissible: isDismissible,
    barrierColor: Colors.black.withOpacity(0.28),
    builder: (ctx) => _AdminDesktopDialog(
      draggable: draggable,
      builder: builder,
    ),
  );
}

class _AdminDesktopDialog extends StatefulWidget {
  const _AdminDesktopDialog({
    required this.draggable,
    required this.builder,
  });

  final bool draggable;
  final Widget Function(BuildContext context, ScrollController? scroll) builder;

  @override
  State<_AdminDesktopDialog> createState() => _AdminDesktopDialogState();
}

class _AdminDesktopDialogState extends State<_AdminDesktopDialog> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = math.min(MediaQuery.sizeOf(context).height * 0.86, 760.0);
    Widget content = widget.builder(
      context,
      widget.draggable ? _scroll : null,
    );
    // Contenido con Expanded necesita altura fija; los formularios se ajustan.
    content = widget.draggable
        ? SizedBox(height: maxHeight * 0.8, child: content)
        : content;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: kAdminDialogMaxWidth,
            maxHeight: maxHeight,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderSubtle),
              boxShadow: [
                BoxShadow(
                  color: AppColors.black.withOpacity(0.14),
                  blurRadius: 32,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Material(
                  type: MaterialType.transparency,
                  child: content,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
