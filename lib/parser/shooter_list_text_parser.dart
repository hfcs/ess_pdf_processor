/// Pure-Dart, web-safe shooter-list text parser utilities.
///
/// Provides parsing heuristics to extract competitor-number -> class token
/// mappings from layout-preserved PDF-to-text output. This file intentionally
/// avoids any `dart:io` or platform-specific APIs so it can be reused in the
/// web app and CLI code.

Map<int, String> parseShooterListFromText(String text) {
  final map = <int, String>{};
  final lines = text.split(RegExp(r"\r?\n"));
  for (var raw in lines) {
    final line = raw.trim();
    if (line.isEmpty) continue;

    final numMatch = RegExp(r"^(\d+)").firstMatch(line);
    if (numMatch == null) continue;
    final num = int.tryParse(numMatch.group(1)!) ?? -1;
    if (num <= 0) continue;

    String cls = '';
    final endMatch = RegExp(r"\b(GM|C|B|A|M)\b").firstMatch(line);
    if (endMatch != null) {
      cls = endMatch.group(1)!.trim();
    } else {
      cls = '';
    }

    if (map.containsKey(num)) {
      if ((map[num] ?? '').isEmpty && cls.isNotEmpty) map[num] = cls;
    } else {
      map[num] = cls;
    }
  }
  return map;
}
