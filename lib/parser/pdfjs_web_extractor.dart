import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:async';
import 'dart:js_interop' as jsi;
import 'package:js/js.dart' show JS;
import 'dart:js_util' as jsu;

/// Calls the browser-side `window.extractPdfArrayBuffer` (provided by
/// `web/pdf_extract.js` and pdf.js) and returns the extracted text (joined
/// lines separated by \n).
@JS('extractPdfArrayBuffer')
external jsi.JSPromise _extractPdfArrayBuffer(Object buffer);

Future<String> extractWithPdfJsWeb(Uint8List bytes) async {
  final buffer = bytes.buffer;
  jsi.JSPromise promise;
  try {
    promise = _extractPdfArrayBuffer(buffer);
  } catch (e) {
    throw Exception('extractPdfArrayBuffer not found on window; ensure web/pdf_extract.js and pdfjs are loaded');
  }
  // Use js_util.promiseToFuture to convert the JS promise to a Dart Future.
  final result = await jsu.promiseToFuture<List>(promise);
  // Debug logging: enabled only in debug builds via assert side-effect.
  var _pdfjsDebug = false;
  assert((_pdfjsDebug = true));
  if (_pdfjsDebug) {
    try {
      html.window.console.log('pdfjs: dart received result length=' + result.length.toString());
      if (result.isNotEmpty) {
        // Log a short preview of the first item for debugging
        try {
          html.window.console.log('pdfjs: dart first item preview: ' + result.first.toString());
        } catch (_) {}
      }
    } catch (_) {}
  }
  // result may be an array of strings or an array of JS objects like
  // { type: 'row', line: '...', division: '...', stage: '...' }.
  // Normalize to a list of lines (strings) by extracting the 'line' field
  // when available, or using the string value otherwise.
  final linesList = <String>[];
  String lastDivision = '';
  String lastStage = '';
  for (final item in result) {
    try {
      // If the item is a plain string, add it directly.
      if (item is String) {
        linesList.add(item);
        continue;
      }

      // Otherwise treat it as a JS object with the expected fields. We use
      // static interop via a minimal wrapper type so we can access fields
      // without js_util.
      final jsObj = item as Object;
      // Access properties via JS interop by creating a dynamic view.
      String? t;
      try {
        t = (jsObj as dynamic).type as String?;
      } catch (_) {
        t = null;
      }

      if (t == 'meta') {
        String? metaVal;
        try {
          metaVal = (jsObj as dynamic).meta as String?;
        } catch (_) {
          metaVal = null;
        }
        if (metaVal == 'division') {
          final division = ((jsObj as dynamic).division as String?) ?? '';
          if (division.isNotEmpty) {
            lastDivision = division;
            linesList.add('$division -- Overall Stage Results');
          }
        } else if (metaVal == 'stage') {
          final stage = ((jsObj as dynamic).stage as String?) ?? '';
          if (stage.isNotEmpty) {
            final m = RegExp(r"(Stage\s*\d+)", caseSensitive: false).firstMatch(stage);
            final stageLine = m != null ? m.group(1) : stage;
            lastStage = stageLine ?? '';
            if (lastStage.isNotEmpty) linesList.add(lastStage);
          }
        }
        continue;
      }

      if (t == 'row') {
        final division = ((jsObj as dynamic).division as String?) ?? '';
        final stage = ((jsObj as dynamic).stage as String?) ?? '';
        if (division.isNotEmpty && division != lastDivision) {
          lastDivision = division;
          linesList.add('$division -- Overall Stage Results');
        }
        if (stage.isNotEmpty) {
          final m = RegExp(r"(Stage\s*\d+)", caseSensitive: false).firstMatch(stage);
          final stageLine = m != null ? m.group(1) : stage;
          if (stageLine != null && stageLine != lastStage) {
            lastStage = stageLine;
            linesList.add(stageLine);
          }
        }
        final line = ((jsObj as dynamic).line as String?);
        if (line != null) linesList.add(line.toString());
        continue;
      }
    } catch (_) {
      // fall through to toString
    }
    try {
      linesList.add(item.toString());
    } catch (_) {
      // ignore
    }
  }
  final lines = linesList.join('\n');
  return lines;
}
