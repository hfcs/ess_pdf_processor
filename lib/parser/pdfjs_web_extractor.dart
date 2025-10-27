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
  // result is a JS array of strings
  final lines = result.map((e) => e.toString()).join('\n');
  return lines;
}
