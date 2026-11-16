import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'catalog_photo_adjustments.dart';
import 'catalog_photo_mask_editor.dart';
import 'catalog_photo_processing.dart';

typedef CatalogPhotoEditorResult = ({
  CatalogPhotoAdjustments adjustments,
  CatalogEditedPhoto? edited,
  bool restore,
});

class CatalogPhotoEditor extends StatefulWidget {
  const CatalogPhotoEditor({
    super.key,
    required this.original,
    this.current,
    this.batchCount,
  });

  final Uint8List original;
  final Uint8List? current;
  final int? batchCount;

  @override
  State<CatalogPhotoEditor> createState() => _CatalogPhotoEditorState();
}

class _CatalogPhotoEditorState extends State<CatalogPhotoEditor> {
  late Uint8List _source = widget.current ?? widget.original;
  Uint8List? _preview;
  int _turns = 0;
  double _brightness = 1;
  double _quality = 90;
  bool _center = false;
  bool _white = false;
  bool _busy = false;
  String? _error;
  String? _cutoutNotice;
  Uint8List? _segmentationSource;
  Uint8List? _mask;
  bool _compare = false;
  double _fill = .8;
  bool _shadow = false;
  double _contrast = 1;
  double _sharpness = 0;
  double _denoise = 0;

  CatalogPhotoAdjustments get _adjustments =>
      _settings(prepared: _mask != null);

  CatalogPhotoAdjustments _settings({required bool prepared}) =>
      CatalogPhotoAdjustments(
        turns: _turns,
        brightness: _brightness,
        quality: _quality.round(),
        center: _center || prepared,
        whiteBackground: _white || prepared,
        removeBackground: prepared,
        fill: _fill,
        shadow: _shadow,
        contrast: _contrast,
        sharpness: _sharpness,
        denoise: _denoise,
      );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _render();
    });
  }

  Future<void> _render({bool apply = false}) async {
    final adjustments = _adjustments;
    final batch = widget.batchCount != null;
    if (batch && apply) {
      Navigator.of(context).pop((
        adjustments: adjustments,
        edited: null as CatalogEditedPhoto?,
        restore: false,
      ));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await compute(renderCatalogPhotoWithMask, (
        request: (
          bytes: _segmentationSource ?? _source,
          adjustments: adjustments,
          preview: !apply,
          lossless: false,
        ),
        mask: _mask,
      ));
      if (!mounted) return;
      if (apply) {
        Navigator.of(context).pop((
          adjustments: adjustments,
          edited: result,
          restore: false,
        ));
      } else {
        setState(() => _preview = result.bytes);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'No se pudo procesar la edición. Ajusta el recorte o recupera la imagen original.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _prepareForCatalog() async {
    setState(() {
      _busy = true;
      _cutoutNotice = null;
      _compare = false;
    });
    try {
      final source = await segmentCatalogPhoto(_source);
      if (!mounted) return;
      final preview = await compute(renderCatalogPhotoWithMask, (
        request: (
          bytes: source.bytes,
          adjustments: _settings(prepared: true),
          preview: true,
          lossless: false,
        ),
        mask: source.mask,
      ));
      if (!mounted) return;
      setState(() {
        _mask = source.mask;
        _segmentationSource = source.bytes;
        _preview = preview.bytes;
        _error = null;
      });
    } catch (_) {
      if (mounted)
        setState(() => _cutoutNotice =
            'No se pudo separar la pieza. Puedes volver a intentar o usar el recorte manual.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _correctMask() async {
    final next = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(
          builder: (_) => CatalogPhotoMaskEditor(
                source: _segmentationSource!,
                mask: _mask!,
              )),
    );
    if (!mounted || next == null) return;
    _mask = next;
    _compare = false;
    await _render();
  }

  void _removeMask() {
    _mask = null;
    _segmentationSource = null;
    _compare = false;
    _render();
  }

  Widget _adjustmentSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> change,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label ${(value * 100).round()} %'),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          semanticFormatterCallback: (value) =>
              '$label ${(value * 100).round()} por ciento',
          onChanged: _busy ? null : (value) => setState(() => change(value)),
          onChangeEnd: _busy ? null : (_) => _render(),
        ),
      ],
    );
  }

  Future<void> _crop() async {
    // Crop the underlying image to avoid baking brightness and compression twice.
    final cropped = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(builder: (_) => _CatalogCropPage(bytes: _source)),
    );
    if (!mounted || cropped == null) return;
    _source = cropped;
    await _render();
  }

  void _restore() {
    Navigator.of(context).pop((
      adjustments: const CatalogPhotoAdjustments(),
      edited: null as CatalogEditedPhoto?,
      restore: true,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final batch = widget.batchCount;
    final bytes = _compare ? widget.original : _preview;
    final prepared = _mask != null;
    final disabled = _busy;
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(
            title: Text(batch == null ? 'Editar foto' : 'Editar $batch fotos')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              children: [
                if (batch != null)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: Text(
                        'Previsualización de la primera foto. Los ajustes se aplican a las fotos incluidas que aún no has editado.'),
                  ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: ColoredBox(
                    color: _white || prepared
                        ? Colors.white
                        : theme.colorScheme.surfaceContainerHigh,
                    child: SizedBox(
                      height:
                          MediaQuery.sizeOf(context).height.clamp(420, 900) *
                              .32,
                      child: bytes == null
                          ? Center(
                              child: _busy
                                  ? const CircularProgressIndicator()
                                  : const Icon(Icons.broken_image_outlined))
                          : Image.memory(bytes,
                              fit: BoxFit.contain, gaplessPlayback: true),
                    ),
                  ),
                ),
                if (_busy && bytes != null) const LinearProgressIndicator(),
                if (_cutoutNotice case final message?)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(message,
                        style: TextStyle(color: theme.colorScheme.error)),
                  ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(_error!,
                        style: TextStyle(color: theme.colorScheme.error)),
                  ),
                const SizedBox(height: 12),
                if (kIsWeb && !prepared)
                  FilledButton.tonalIcon(
                    onPressed:
                        _busy || _preview == null ? null : _prepareForCatalog,
                    icon: const Icon(Icons.auto_fix_high_outlined),
                    label: const Text('Preparar foto para el catálogo'),
                  ),
                if (prepared) ...[
                  Text(
                    batch == null
                        ? 'Revisa el borde de la pieza antes de guardarla.'
                        : 'Comprueba el recorte de cada foto después de aplicar el ajuste.',
                    style: theme.textTheme.bodySmall,
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      if (batch == null)
                        OutlinedButton(
                          onPressed: _busy ? null : _correctMask,
                          child: const Text('Corregir borde'),
                        ),
                      TextButton(
                        onPressed: _busy ? null : _removeMask,
                        child: const Text('Deshacer recorte'),
                      ),
                    ],
                  ),
                  _adjustmentSlider(
                    label: 'Espacio que ocupa la pieza',
                    value: _fill,
                    min: .60,
                    max: .88,
                    divisions: 14,
                    change: (value) => _fill = value,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Sombra suave'),
                    value: _shadow,
                    onChanged: _busy
                        ? null
                        : (value) {
                            setState(() => _shadow = value);
                            _render();
                          },
                  ),
                ],
                if (_preview != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _busy
                          ? null
                          : () => setState(() => _compare = !_compare),
                      icon: const Icon(Icons.compare_outlined),
                      label: Text(_compare ? 'Ver resultado' : 'Ver original'),
                    ),
                  ),
                if (batch == null) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: disabled || prepared ? null : _crop,
                        icon: const Icon(Icons.crop),
                        label: const Text('Recortar'),
                      ),
                      OutlinedButton.icon(
                        onPressed: disabled
                            ? null
                            : () {
                                setState(() => _turns = (_turns + 1) % 4);
                                _render();
                              },
                        icon: const Icon(Icons.rotate_right),
                        label: const Text('Girar 90°'),
                      ),
                      if (widget.current != null)
                        TextButton(
                            onPressed: _busy ? null : _restore,
                            child: const Text('Recuperar original')),
                    ],
                  ),
                ],
                if (!prepared)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Centrar en un marco cuadrado'),
                    value: _center,
                    onChanged: disabled
                        ? null
                        : (value) {
                            setState(() => _center = value);
                            _render();
                          },
                  ),
                if (!prepared)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Fondo blanco'),
                    subtitle: const Text('Rellena transparencias y márgenes.'),
                    value: _white,
                    onChanged: disabled
                        ? null
                        : (value) {
                            setState(() => _white = value);
                            _render();
                          },
                  ),
                const SizedBox(height: 12),
                _adjustmentSlider(
                  label: 'Iluminación',
                  value: _brightness,
                  min: .7,
                  max: 1.3,
                  divisions: 12,
                  change: (value) => _brightness = value,
                ),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text('Ajustes avanzados'),
                  children: [
                    _adjustmentSlider(
                      label: 'Contraste',
                      value: _contrast,
                      min: .8,
                      max: 1.2,
                      divisions: 8,
                      change: (value) => _contrast = value,
                    ),
                    _adjustmentSlider(
                      label: 'Nitidez',
                      value: _sharpness,
                      min: 0,
                      max: .6,
                      divisions: 12,
                      change: (value) => _sharpness = value,
                    ),
                    _adjustmentSlider(
                      label: 'Suavizar ruido',
                      value: _denoise,
                      min: 0,
                      max: .6,
                      divisions: 12,
                      change: (value) => _denoise = value,
                    ),
                  ],
                ),
                Text('Calidad JPG ${_quality.round()} %'),
                Slider(
                  value: _quality,
                  min: 55,
                  max: 95,
                  divisions: 8,
                  semanticFormatterCallback: (value) =>
                      '${value.round()} por ciento',
                  onChanged: disabled
                      ? null
                      : (value) => setState(() => _quality = value),
                  onChangeEnd: disabled ? null : (_) => _render(),
                ),
                const Text('Las transparencias se conservan en PNG.'),
              ],
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: disabled || _preview == null || _error != null
                      ? null
                      : () => _render(apply: true),
                  child: Text(batch == null
                      ? 'Usar foto editada'
                      : 'Aplicar a $batch fotos'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CatalogCropPage extends StatefulWidget {
  const _CatalogCropPage({required this.bytes});

  final Uint8List bytes;

  @override
  State<_CatalogCropPage> createState() => _CatalogCropPageState();
}

class _CatalogCropPageState extends State<_CatalogCropPage> {
  final _controller = CropController();
  bool _ready = false;
  bool _busy = true;
  String? _error;
  Uint8List? _source;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    try {
      final result = await compute(renderCatalogPhoto, (
        bytes: widget.bytes,
        adjustments: const CatalogPhotoAdjustments(),
        preview: false,
        lossless: true,
      ));
      if (mounted) setState(() => _source = result.bytes);
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo preparar el recorte.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final source = _source;
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(title: const Text('Recortar foto')),
        body: Column(
          children: [
            Expanded(
              child: source == null
                  ? Center(
                      child: _busy
                          ? const CircularProgressIndicator()
                          : Text(_error ?? ''))
                  : Crop(
                      image: source,
                      controller: _controller,
                      initialRectBuilder:
                          InitialRectBuilder.withSizeAndRatio(size: .9),
                      onStatusChanged: (status) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) {
                            setState(() => _ready = status == CropStatus.ready);
                          }
                        });
                      },
                      onCropped: (result) {
                        if (!mounted) return;
                        switch (result) {
                          case CropSuccess(:final croppedImage):
                            Navigator.of(context).pop(croppedImage);
                          case CropFailure():
                            setState(() {
                              _busy = false;
                              _error = 'No se pudo aplicar ese recorte.';
                            });
                        }
                      },
                    ),
            ),
            if (_error != null && source != null) Text(_error!),
          ],
        ),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            onPressed: !_ready || _busy
                ? null
                : () {
                    setState(() => _busy = true);
                    _controller.crop();
                  },
            child: const Text('Aplicar recorte'),
          ),
        ),
      ),
    );
  }
}
