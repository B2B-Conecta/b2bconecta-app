import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'catalog_photo_adjustments.dart';

class CatalogPhotoMaskEditor extends StatefulWidget {
  const CatalogPhotoMaskEditor(
      {super.key, required this.source, required this.mask});

  final Uint8List source;
  final Uint8List mask;

  @override
  State<CatalogPhotoMaskEditor> createState() => _CatalogPhotoMaskEditorState();
}

class _CatalogPhotoMaskEditorState extends State<CatalogPhotoMaskEditor> {
  late Uint8List _mask = Uint8List.fromList(widget.mask);
  final _history = <Uint8List>[];
  final _stroke = <Offset>[];
  Uint8List? _preview;
  int? _pointer;
  bool _restore = false;
  bool _compare = false;
  bool _busy = true;
  double _size = .04;
  String? _error;

  @override
  void initState() {
    super.initState();
    _render();
  }

  Future<void> _render() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await compute(
          previewCatalogMask, (bytes: widget.source, mask: _mask));
      if (mounted) setState(() => _preview = result.bytes);
    } catch (_) {
      if (mounted)
        setState(() => _error =
            'No se pudo mostrar el borde. Prueba deshacer el último trazo.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Offset _point(Offset local, Size size) => Offset(
        (local.dx / size.width).clamp(0, 1),
        (local.dy / size.height).clamp(0, 1),
      );

  void _commitStroke(Size canvas) {
    if (_stroke.isEmpty) return;
    if (_history.length >= 20) _history.removeAt(0);
    _history.add(Uint8List.fromList(_mask));
    final shortSide = math.min(canvas.width, canvas.height);
    final radiusX = _size * shortSide / canvas.width;
    final radiusY = _size * shortSide / canvas.height;
    for (var i = 0; i < _stroke.length; i++) {
      final end = _stroke[i];
      final start = i == 0 ? end : _stroke[i - 1];
      final steps =
          math.max(1, ((end - start).distance * catalogMaskSide).ceil());
      for (var step = 0; step <= steps; step++) {
        _paintAt(Offset.lerp(start, end, step / steps)!, radiusX, radiusY);
      }
    }
    _stroke.clear();
    _render();
  }

  void _paintAt(Offset point, double radiusX, double radiusY) {
    const side = catalogMaskSide;
    final cx = point.dx * (side - 1);
    final cy = point.dy * (side - 1);
    final rx = math.max(1, radiusX * side);
    final ry = math.max(1, radiusY * side);
    for (var y = math.max(0, (cy - ry).floor());
        y <= math.min(side - 1, (cy + ry).ceil());
        y++) {
      for (var x = math.max(0, (cx - rx).floor());
          x <= math.min(side - 1, (cx + rx).ceil());
          x++) {
        final dx = (x - cx) / rx;
        final dy = (y - cy) / ry;
        if (dx * dx + dy * dy <= 1) _mask[y * side + x] = _restore ? 255 : 0;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final png = ByteData.sublistView(widget.source);
    final sourceSize =
        Size(png.getUint32(16).toDouble(), png.getUint32(20).toDouble());
    final colors = Theme.of(context).colorScheme;
    final preview = _preview;
    return Scaffold(
      appBar: AppBar(title: const Text('Corregir borde')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                const Text(
                    'Pinta para recuperar partes de la pieza o borrar restos del fondo.'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                        label: const Text('Borrar fondo'),
                        selected: !_restore,
                        onSelected: _busy
                            ? null
                            : (_) => setState(() {
                                  _restore = false;
                                  _compare = false;
                                })),
                    ChoiceChip(
                        label: const Text('Recuperar pieza'),
                        selected: _restore,
                        onSelected: _busy
                            ? null
                            : (_) => setState(() {
                                  _restore = true;
                                  _compare = false;
                                })),
                    TextButton(
                        onPressed: _busy
                            ? null
                            : () => setState(() => _compare = !_compare),
                        child: Text(_compare ? 'Ver recorte' : 'Ver original')),
                  ],
                ),
                if (_busy) const LinearProgressIndicator(),
                if (_error case final message?)
                  Text(message, style: TextStyle(color: colors.error)),
                Expanded(
                  child: LayoutBuilder(builder: (_, bounds) {
                    final size =
                        applyBoxFit(BoxFit.contain, sourceSize, bounds.biggest)
                            .destination;
                    return Center(
                      child: SizedBox.fromSize(
                        size: size,
                        child: Listener(
                          behavior: HitTestBehavior.opaque,
                          onPointerDown: (event) {
                            if (_busy || _compare || _pointer != null) return;
                            _pointer = event.pointer;
                            setState(() =>
                                _stroke.add(_point(event.localPosition, size)));
                          },
                          onPointerMove: (event) {
                            if (_pointer != event.pointer) return;
                            setState(() =>
                                _stroke.add(_point(event.localPosition, size)));
                          },
                          onPointerUp: (event) {
                            if (_pointer != event.pointer) return;
                            _pointer = null;
                            _commitStroke(size);
                          },
                          onPointerCancel: (event) {
                            if (_pointer != event.pointer) return;
                            _pointer = null;
                            setState(_stroke.clear);
                          },
                          child: ClipRect(
                            child: ColoredBox(
                              color: Colors.white,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Opacity(
                                    opacity: _compare
                                        ? 1
                                        : _restore
                                            ? .26
                                            : 0,
                                    child: Image.memory(widget.source,
                                        fit: BoxFit.fill),
                                  ),
                                  if (!_compare && preview != null)
                                    Image.memory(preview,
                                        fit: BoxFit.fill,
                                        gaplessPlayback: true),
                                  if (_stroke.isNotEmpty)
                                    CustomPaint(
                                        painter: _MaskStrokePainter(
                                      List.of(_stroke),
                                      _size,
                                      (_restore ? colors.primary : colors.error)
                                          .withOpacity(.45),
                                    )),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                Row(
                  children: [
                    const Text('Tamaño'),
                    Expanded(
                        child: Slider(
                      value: _size,
                      min: .01,
                      max: .12,
                      divisions: 11,
                      onChanged: _busy
                          ? null
                          : (value) => setState(() => _size = value),
                    )),
                    IconButton(
                      tooltip: 'Deshacer trazo',
                      onPressed: _busy || _history.isEmpty
                          ? null
                          : () {
                              _mask = _history.removeLast();
                              _render();
                            },
                      icon: const Icon(Icons.undo),
                    ),
                  ],
                ),
                SafeArea(
                  top: false,
                  minimum: const EdgeInsets.only(bottom: 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _busy || _error != null
                          ? null
                          : () => Navigator.pop(context, _mask),
                      child: const Text('Aplicar borde'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MaskStrokePainter extends CustomPainter {
  _MaskStrokePainter(this.points, this.radius, this.color);
  final List<Offset> points;
  final double radius;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final brush = radius * size.shortestSide;
    final paint = Paint()
      ..color = color
      ..strokeWidth = brush * 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    Offset pointAt(int i) =>
        Offset(points[i].dx * size.width, points[i].dy * size.height);
    if (points.length == 1) {
      canvas.drawCircle(pointAt(0), brush, paint);
    } else {
      final path = Path()..moveTo(pointAt(0).dx, pointAt(0).dy);
      for (var i = 1; i < points.length; i++) {
        final point = pointAt(i);
        path.lineTo(point.dx, point.dy);
      }
      paint.style = PaintingStyle.stroke;
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_MaskStrokePainter oldDelegate) => true;
}
