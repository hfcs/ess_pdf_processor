import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:async';
// Note: we avoid heavy use of dart:js_interop here and use js_util for
// promise conversion and property access for broader compatibility.
import 'dart:js_util' as jsu;

/// Calls the browser-side `window.extractPdfArrayBuffer` (provided by
/// `web/pdf_extract.js` and pdf.js) and returns the extracted text (joined
/// lines separated by \n).
Future<String> extractWithPdfJsWeb(Uint8List bytes) async {
  final buffer = bytes.buffer;
  final has = jsu.hasProperty(html.window, 'extractPdfArrayBuffer');
  if (!has) throw Exception('extractPdfArrayBuffer not found on window; ensure web/pdf_extract.js and pdfjs are loaded');
  final promise = jsu.callMethod(html.window, 'extractPdfArrayBuffer', [buffer]);
  final result = await jsu.promiseToFuture<List>(promise);
  // Debug logging: enabled only in debug builds via assert side-effect.
  var _pdfjsDebug = false;
  assert((_pdfjsDebug = true));
  if (_pdfjsDebug) {
    try {
      // Use print so logging works across platforms and test runners.
      print('pdfjs: dart received result length=' + result.length.toString());
      if (result.isNotEmpty) {
        try {
          print('pdfjs: dart first item preview: ' + result.first.toString());
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

      // Otherwise treat it as a JS object with the expected fields.
      final jsObj = item as Object;

      String? t;
      try {
        if (jsu.hasProperty(jsObj, 'type')) {
          final tp = jsu.getProperty(jsObj, 'type');
          if (tp != null) t = tp.toString();
        }
      } catch (_) {
        t = null;
      }

      if (t == 'meta') {
        String? metaVal;
        try {
          if (jsu.hasProperty(jsObj, 'meta')) {
            final mv = jsu.getProperty(jsObj, 'meta');
            if (mv != null) metaVal = mv.toString();
          }
        } catch (_) {
          metaVal = null;
        }
        if (metaVal == 'division') {
          final division = jsu.hasProperty(jsObj, 'division') ? (jsu.getProperty(jsObj, 'division')?.toString() ?? '') : '';
          if (division.isNotEmpty) {
            lastDivision = division;
            linesList.add('$division -- Overall Stage Results');
          }
        } else if (metaVal == 'stage') {
          final stage = jsu.hasProperty(jsObj, 'stage') ? (jsu.getProperty(jsObj, 'stage')?.toString() ?? '') : '';
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
        final division = jsu.hasProperty(jsObj, 'division') ? (jsu.getProperty(jsObj, 'division')?.toString() ?? '') : '';
        final stage = jsu.hasProperty(jsObj, 'stage') ? (jsu.getProperty(jsObj, 'stage')?.toString() ?? '') : '';
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
        final line = jsu.hasProperty(jsObj, 'line') ? (jsu.getProperty(jsObj, 'line')?.toString()) : null;
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
