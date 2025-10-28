import 'dart:io';

import 'pdfjs_extractor.dart' as pdfjs_extractor;

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

  final map = <int, String>{};

  final lines = text.split(RegExp(r"\r?\n"));
  for (var raw in lines) {
    final line = raw.trim();
    if (line.isEmpty) continue;

    // Attempt to find a leading competitor number
    final numMatch = RegExp(r"^(\d+)").firstMatch(line);
    if (numMatch == null) continue;
    final num = int.tryParse(numMatch.group(1)!) ?? -1;
    if (num <= 0) continue;

    // Heuristic: look for a class token near end of line (GM or single letter)
    String cls = '';
    final endMatch = RegExp(r"\b(GM|C|B|A|M)\b").firstMatch(line);
    if (endMatch != null) {
      cls = endMatch.group(1)!.trim();
    } else {
      // No explicit class token found; leave as empty string
      cls = '';
    }

    // If duplicate, keep first occurrence but prefer non-empty class
    if (map.containsKey(num)) {
      if ((map[num] ?? '').isEmpty && cls.isNotEmpty) {
        map[num] = cls;
      }
    } else {
      map[num] = cls;
    }
  }

  return map;
}
