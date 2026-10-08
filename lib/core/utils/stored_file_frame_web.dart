// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';

Widget? buildStoredFileFrame(String url) => _StoredFileFrame(url: url);

class _StoredFileFrame extends StatefulWidget {
  const _StoredFileFrame({required this.url});

  final String url;

  @override
  State<_StoredFileFrame> createState() => _StoredFileFrameState();
}

class _StoredFileFrameState extends State<_StoredFileFrame> {
  late final String _viewType = 'stored-file-${identityHashCode(this)}';

  @override
  void initState() {
    super.initState();
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      return html.IFrameElement()
        ..src = widget.url
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..setAttribute('title', 'Archivo');
    });
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}
