import 'dart:typed_data';
import 'dart:async';
import 'package:js/js.dart';

/// Bind the browser-side `window.extractPdfArrayBuffer` function defined in
/// `web/pdf_extract.js`/pdf.js, returning a JavaScript Promise. We convert the
/// Promise to a Dart Future below using a Completer and `allowInterop`.
@JS('window.extractPdfArrayBuffer')
external Object? _extractPdfArrayBuffer(Object buffer);

/// Calls the browser-side `window.extractPdfArrayBuffer` (provided by
/// `web/pdf_extract.js` and pdf.js) and returns the extracted text (joined
/// lines separated by \n).
Future<String> extractWithPdfJsWeb(Uint8List bytes) async {
  final buffer = bytes.buffer;
  final promise = _extractPdfArrayBuffer(buffer);
  if (promise == null) throw Exception('extractPdfArrayBuffer not found on window; ensure web/pdf_extract.js and pdfjs are loaded');

  // Convert the JS Promise to a Dart Future<List> by wiring its `then`/`catch`.
  final completer = Completer<List>();
  try {
    // The JS Promise exposes a `then` method; call it with Dart functions
    // wrapped via `allowInterop` so V8 can invoke them.
    final p = promise as dynamic;
    p.then(allowInterop((res) {
      try {
        // Ensure result is converted to a Dart List if possible.
        completer.complete(List.from(res));
      } catch (_) {
        completer.complete(res as List);
      }
    }), allowInterop((err) {
      completer.completeError(err ?? 'Promise rejected');
    }));
  } catch (e) {
    throw Exception('Error while awaiting extractPdfArrayBuffer promise: $e');
  }

  final result = await completer.future;
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
      final jsObj = item as dynamic;

      String? t;
      try {
        final tp = jsObj.type;
        if (tp != null) t = tp.toString();
      } catch (_) {
        t = null;
      }

      if (t == 'meta') {
        String? metaVal;
        try {
          final mv = jsObj.meta;
          if (mv != null) metaVal = mv.toString();
        } catch (_) {
          metaVal = null;
        }
        if (metaVal == 'division') {
          final division = () {
            try {
              final d = jsObj.division;
              return d?.toString() ?? '';
            } catch (_) {
              return '';
            }
          }();
          if (division.isNotEmpty) {
            lastDivision = division;
            linesList.add('$division -- Overall Stage Results');
          }
        } else if (metaVal == 'stage') {
          final stage = () {
            try {
              final s = jsObj.stage;
              return s?.toString() ?? '';
            } catch (_) {
              return '';
            }
          }();
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
        final division = () {
          try {
            final d = jsObj.division;
            return d?.toString() ?? '';
          } catch (_) {
            return '';
          }
        }();
        final stage = () {
          try {
            final s = jsObj.stage;
            return s?.toString() ?? '';
          } catch (_) {
            return '';
          }
        }();
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
        final line = () {
          try {
            final l = jsObj.line;
            return l?.toString();
          } catch (_) {
            return null;
          }
        }();
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
