import 'package:flutter/material.dart';

import '../../app/main_shell_tab.dart';
import '../../app/theme/b2b_theme_extension.dart';
import '../../core/widgets/lucide_icon.dart';

enum RetailerTourStop { home, catalog, product, cart }

enum RetailerCartTopic { shipping, minimums, delivery }

final _active = ValueNotifier(false);

void endRetailerTour() => _active.value = false;

void startRetailerTour() {
  _active.value = true;
  MainShellTabController.navigateToHomeTab();
}

Future<void> showRetailerInduction(BuildContext context) async {
  final start = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Guía de compra'),
      content: const Text(
        'Te acompañamos por el catálogo, la ficha del repuesto y tu bolsa.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Ahora no'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Iniciar recorrido'),
        ),
      ],
    ),
  );
  if (context.mounted && start == true) startRetailerTour();
}

class RetailerTourButton extends StatelessWidget {
  const RetailerTourButton({super.key});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => showRetailerInduction(context),
      icon: const LucideIcon(LucideGlyph.sparkles, size: 18),
      label: const Text('Guía de compra'),
    );
  }
}

class RetailerTourTarget extends StatelessWidget {
  const RetailerTourTarget({super.key, required this.child, this.topic});

  final Widget child;
  final RetailerCartTopic? topic;

  @override
  Widget build(BuildContext context) {
    final tour = context.findAncestorStateOfType<_RetailerTourScreenState>();
    if (tour == null) return child;
    tour.track(context, topic);
    return child;
  }
}

class RetailerTourScreen extends StatefulWidget {
  const RetailerTourScreen({
    super.key,
    required this.stop,
    required this.child,
    this.onNext,
  });

  final RetailerTourStop stop;
  final Widget child;
  final VoidCallback? onNext;

  @override
  State<RetailerTourScreen> createState() => _RetailerTourScreenState();
}

class _RetailerTourScreenState extends State<RetailerTourScreen> {
  final _layer = GlobalKey();
  final _targets = <BuildContext, RetailerCartTopic?>{};
  RetailerCartTopic _topic = RetailerCartTopic.shipping;

  RetailerCartTopic? get _targetTopic =>
      widget.stop == RetailerTourStop.cart ? _topic : null;
  Rect? _hole;
  bool _queued = false;
  RetailerCartTopic? _revealedTopic;

  void track(BuildContext target, RetailerCartTopic? topic) {
    _targets[target] = topic;
    _measure();
  }

  void _measure() {
    if (_queued || !_active.value) return;
    _queued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _queued = false;
      if (!mounted || !_active.value) return;
      final layer = _layer.currentContext?.findRenderObject();
      if (layer is! RenderBox || !layer.hasSize) return;
      final bounds = Offset.zero & layer.size;
      Rect? next;
      BuildContext? offscreen;
      _targets.removeWhere((target, _) => !target.mounted);
      for (final MapEntry(key: target, value: topic) in _targets.entries) {
        if (topic != _targetTopic) continue;
        final box = target.findRenderObject();
        if (box is! RenderBox || !box.attached || !box.hasSize || box.size.isEmpty) continue;
        final offset = box.localToGlobal(Offset.zero, ancestor: layer);
        final rect = (offset & box.size).inflate(4);
        if (rect.isFinite && bounds.contains(rect.center)) {
          next = rect.intersect(bounds);
          break;
        }
        offscreen ??= target;
      }
      if (next == null && offscreen != null && _targetTopic != null &&
          _revealedTopic != _targetTopic) {
        _revealedTopic = _targetTopic;
        Scrollable.ensureVisible(offscreen, alignment: 0.3);
      }
      if (_hole != next) setState(() => _hole = next);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _active,
      child: widget.child,
      builder: (context, active, screen) {
        final theme = B2BThemeExtension.of(context);
        if (active) _measure();
        final (title, message) = switch (widget.stop) {
          RetailerTourStop.home => (
              '1 de 6 · Inicio',
              'Desde Inicio puedes buscar repuestos. Abre el catálogo para continuar.',
            ),
          RetailerTourStop.catalog => (
              '2 de 6 · Catálogo y filtros',
              'Puedes aplicar filtros, tocar un repuesto o pulsar Siguiente para abrir el primer resultado.',
            ),
          RetailerTourStop.product => (
              '3 de 6 · Ficha y cantidad',
              'Elige la cantidad y agrega el repuesto. Luego abre tu carrito.',
            ),
          RetailerTourStop.cart => switch (_topic) {
              RetailerCartTopic.shipping => (
                '4 de 6 · Condiciones de envío',
                'Cada proveedor define si el flete está incluido, tiene un costo '
                    'adicional o puede ser gratis según el monto y el destino.',
              ),
              RetailerCartTopic.minimums => (
                '5 de 6 · Mínimos del proveedor',
                'Si el proveedor pide un monto o unidades mínimas, revisa cuánto falta. '
                    'Un mínimo combinable suma las unidades de los repuestos elegibles.',
              ),
              RetailerCartTopic.delivery => (
                '6 de 6 · Continuar con la entrega',
                'Cuando cumplas los mínimos, pulsa Continuar con la entrega '
                    'para ver las opciones disponibles para tu dirección.',
              ),
            },
        };
        return LayoutBuilder(builder: (context, constraints) {
          if (active) _measure();
          final hole = active ? _hole : null;
          final nearBottom = hole != null &&
              hole.center.dy > constraints.maxHeight / 2;
          return Stack(
            key: _layer,
            fit: StackFit.expand,
            children: [
              NotificationListener<ScrollNotification>(
                onNotification: (_) {
                  _measure();
                  return false;
                },
                child: screen!,
              ),
              if (hole != null)
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _RetailerSpotlight(
                        hole,
                        theme.textPrimary.withOpacity(0.32),
                        theme.brand,
                      ),
                    ),
                  ),
                ),
              if (active)
                Positioned(
                  left: 12,
                  right: 12,
                  top: nearBottom ? 12 : null,
                  bottom: nearBottom ? null : 12,
                  child: SafeArea(
                    child: Align(
                      alignment: Alignment.center,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Material(
                          color: theme.dialogSurface,
                          elevation: 6,
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(title,
                                          style: TextStyle(
                                            color: theme.textPrimary,
                                            fontWeight: FontWeight.w700,
                                          )),
                                      Text(message,
                                          style: TextStyle(
                                            color: theme.textSecondary,
                                          )),
                                      if (widget.stop == RetailerTourStop.home)
                                        TextButton(
                                          onPressed: () => MainShellTabController
                                              .navigateToAliadoCatalog(),
                                          child: const Text('Abrir catálogo'),
                                        ),
                                      if (widget.stop == RetailerTourStop.catalog)
                                        FilledButton(
                                          onPressed: widget.onNext,
                                          child: const Text('Siguiente'),
                                        ),
                                      if (widget.stop == RetailerTourStop.cart)
                                        if (_topic == RetailerCartTopic.delivery)
                                          TextButton(
                                            onPressed: endRetailerTour,
                                            child: const Text('Finalizar recorrido'),
                                          )
                                        else
                                          FilledButton(
                                            onPressed: () {
                                              setState(() {
                                                _topic = RetailerCartTopic
                                                    .values[_topic.index + 1];
                                                _hole = null;
                                              });
                                            },
                                            child: const Text('Siguiente'),
                                          ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Cerrar guía',
                                  onPressed: endRetailerTour,
                                  icon: const Icon(Icons.close),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        });
      },
    );
  }
}

class _RetailerSpotlight extends CustomPainter {
  const _RetailerSpotlight(this.hole, this.scrim, this.border);

  final Rect hole;
  final Color scrim;
  final Color border;

  @override
  void paint(Canvas canvas, Size size) {
    final shape = RRect.fromRectAndRadius(hole, const Radius.circular(10));
    final mask = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(shape);
    canvas.drawPath(mask, Paint()..color = scrim);
    canvas.drawRRect(
      shape,
      Paint()
        ..color = border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_RetailerSpotlight oldDelegate) =>
      oldDelegate.hole != hole ||
      oldDelegate.scrim != scrim ||
      oldDelegate.border != border;
}
