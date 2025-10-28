import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:js_util' as jsu;

/// Calls the browser-side `window.extractPdfArrayBuffer` (provided by
/// `web/pdf_extract.js` and pdf.js) and returns the extracted text (joined
/// lines separated by \n).
Future<String> extractWithPdfJsWeb(Uint8List bytes) async {
  final has = jsu.hasProperty(html.window, 'extractPdfArrayBuffer');
  if (!has) throw Exception('extractPdfArrayBuffer not found on window; ensure web/pdf_extract.js and pdfjs are loaded');
  final buffer = bytes.buffer;
  final promise = jsu.callMethod(html.window, 'extractPdfArrayBuffer', [buffer]);
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
      final t = jsu.getProperty(item, 'type');
      if (t == 'meta') {
        final meta = jsu.getProperty(item, 'meta');
        if (meta == 'division') {
          final division = jsu.getProperty(item, 'division')?.toString() ?? '';
          if (division.isNotEmpty) {
            // Emit a division header line that the Dart parser recognizes
            lastDivision = division;
            linesList.add('$division -- Overall Stage Results');
          }
        } else if (meta == 'stage') {
          final stage = jsu.getProperty(item, 'stage')?.toString() ?? '';
          if (stage.isNotEmpty) {
            // Normalize stage to 'Stage N' format if possible
            final m = RegExp(r"(Stage\s*\d+)", caseSensitive: false).firstMatch(stage);
            final stageLine = m != null ? m.group(1) : stage;
            lastStage = stageLine ?? '';
            if (lastStage.isNotEmpty) linesList.add(lastStage);
          }
        }
        continue;
      }
      if (t == 'row') {
        // Row objects may also carry division/stage fields; ensure we emit
        // header lines if they differ from the last seen values.
        final division = jsu.getProperty(item, 'division')?.toString() ?? '';
        final stage = jsu.getProperty(item, 'stage')?.toString() ?? '';
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
        final line = jsu.getProperty(item, 'line');
        if (line != null) linesList.add(line.toString());
        continue;
      }
    } catch (_) {
      // Not a JS object with properties; fall-through to toString
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
