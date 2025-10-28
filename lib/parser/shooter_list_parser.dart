import 'dart:io';

import 'pdfjs_extractor.dart' as pdfjs_extractor;
import 'shooter_list_text_parser.dart' as text_parser;

/// Parse a shooter-list PDF where each row contains competitor number,
/// competitor name and a class token (C,B,A,M,GM or blank). Returns a map
/// from competitor number -> raw class token (empty string when blank).
Future<Map<int, String>> parseShooterList(File file) async {
  String text = '';
  // Try pdftotext first for layout-preserved text
  try {
    final pr = await Process.run('pdftotext', ['-layout', '-enc', 'UTF-8', file.path, '-']);
    if (pr.exitCode == 0) {
      text = pr.stdout as String;
    } else {
      // fallback to pdf.js extractor
      text = await pdfjs_extractor.extractWithPdfJs(file);
    }
  } catch (_) {
    // If pdftotext not available, use pdf.js path
    text = await pdfjs_extractor.extractWithPdfJs(file);
  }

  // Delegate text parsing heuristics to the shared, web-safe parser.
  return text_parser.parseShooterListFromText(text);
}
