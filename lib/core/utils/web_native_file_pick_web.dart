// ignore: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

import 'web_native_file_pick_types.dart';

/// Opens a native `<input type="file">` without `capture`.
///
/// iOS Safari blocks the picker if `capture` is set incorrectly, and also
/// if `input.click()` runs after an `await` (lost user gesture). This helper
/// clicks the input on the same call stack as the tap.
Future<WebPickedFile?> pickWebNativeFile({
  required String accept,
}) async {
  final files = await pickWebNativeFiles(accept: accept);
  return files.isEmpty ? null : files.first;
}

Future<List<WebPickedFile>> pickWebNativeFiles({
  required String accept,
  bool multiple = false,
}) {
  final completer = Completer<List<WebPickedFile>>();
  final input = html.FileUploadInputElement()
    ..accept = accept
    ..multiple = multiple;

  // Never set `capture`: Safari Mobile treats it as camera-only and often
  // refuses to open the sheet at all.
  input.style.display = 'none';
  html.document.body?.append(input);

  var settled = false;

  void finish(List<WebPickedFile> value) {
    if (settled) return;
    settled = true;
    input.remove();
    if (!completer.isCompleted) completer.complete(value);
  }

  input.onChange.listen((_) async {
    final htmlFiles = input.files;
    if (htmlFiles == null || htmlFiles.isEmpty) {
      finish(const []);
      return;
    }
    final out = <WebPickedFile>[];
    for (final file in htmlFiles) {
      final bytes = await _readFileBytes(file);
      if (bytes == null || bytes.isEmpty) continue;
      final name = file.name.trim().isEmpty ? 'archivo' : file.name;
      out.add(WebPickedFile(bytes: bytes, fileName: name));
    }
    finish(out);
  });

  // iOS often skips `change` if the user cancels. `focus` after the sheet
  // closes, then check files — do not complete early while the camera is open.
  html.window.onFocus.listen((_) {
    Future<void>.delayed(const Duration(milliseconds: 1200), () {
      if (settled) return;
      final htmlFiles = input.files;
      if (htmlFiles == null || htmlFiles.isEmpty) {
        finish(const []);
      }
    });
  });

  input.click();
  return completer.future;
}

Future<Uint8List?> _readFileBytes(html.File file) {
  final reader = html.FileReader();
  final done = Completer<Uint8List?>();
  reader.onLoad.listen((_) {
    final result = reader.result;
    if (result is ByteBuffer) {
      done.complete(Uint8List.view(result));
    } else if (result is Uint8List) {
      done.complete(result);
    } else {
      done.complete(null);
    }
  });
  reader.onError.listen((_) {
    if (!done.isCompleted) done.complete(null);
  });
  reader.readAsArrayBuffer(file);
  return done.future;
}
