import 'dart:convert';
import 'dart:io';
// Note: intentionally avoid importing Flutter-dependent PDF text extractors.
// This parser prefers a pure-Dart heuristic extraction (best-effort). If you
// later add a pure-Dart PDF reader with a stable text API, we can wire it in.
import '../models/result_row.dart';

class PdfDartParser {
  final File file;

  PdfDartParser(this.file);

  /// Parse the PDF using the pure-Dart `pdf` package when available.
  /// If the package extraction fails, fall back to a heuristic text extraction
  /// from the raw PDF bytes (best-effort) and then apply the same layout regex.
  Future<List<ResultRow>> parse({String defaultDivision = 'UNKNOWN'}) async {
    final rows = <ResultRow>[];

    String currentDivision = defaultDivision;
    String currentStage = '';

    final rowRegex = RegExp(r"^\s*(\d+)\s+(\d+)\s+(\d+(?:\.\d{1,2})?)\s+(\d+\.\d{4})\s+(\d+\.\d{4})\s+(\d+\.\d{1,2})\s+(\d+)\s+(.+?)\s*$");
      final divisionRegex = RegExp(r"^([A-Za-z0-9 &/\-]+)\s*--\s*Overall Stage Results", caseSensitive: false);
    final stageRegex = RegExp(r"^Stage\s+(\d+)", caseSensitive: false);

    // First, if `pdftotext` is available on the system, prefer it because it
    // produces reliable layout-preserved text which our regex expects.
    try {
      final pr = await Process.run('pdftotext', ['-layout', '-enc', 'UTF-8', file.path, '-']);
      if (pr.exitCode == 0) {
        final outText = pr.stdout as String;
        final lines = outText.split(RegExp(r"\r?\n"));
        for (var line in lines) {
            line = line.trim();
          if (line.isEmpty) continue;

          final dmatch = divisionRegex.firstMatch(line);
          if (dmatch != null) {
            currentDivision = dmatch.group(1)!.trim();
            continue;
          }

          final smatch = stageRegex.firstMatch(line);
          if (smatch != null) {
            currentStage = smatch.group(1)!;
            continue;
          }

          final m = rowRegex.firstMatch(line);
          if (m != null) {
            final pts = double.tryParse(m.group(2)!) ?? 0.0;
            final time = double.tryParse(m.group(3)!) ?? 0.0;
            final hitFactor = double.tryParse(m.group(4)!) ?? 0.0;
            final stagePoints = double.tryParse(m.group(5)!) ?? 0.0;
            final stagePercent = double.tryParse(m.group(6)!) ?? 0.0;
            final compNum = int.tryParse(m.group(7)!) ?? 0;
            final name = m.group(8)!.trim();

            rows.add(ResultRow(
              competitorNumber: compNum,
              competitorName: name,
              stage: currentStage,
              division: currentDivision,
              points: pts,
              time: time,
              hitFactor: hitFactor,
              stagePoints: stagePoints,
              stagePercentage: stagePercent,
            ));
          }
        }

        if (rows.isNotEmpty) return rows;
      }
    } catch (_) {
      // ignore and fall back to heuristic extraction
    }

    // Heuristic fallback: extract literal text tokens from PDF content streams.
    final fallbackText = await _extractTextHeuristic(file);
    // Try two strategies on the fallback text:
    // 1) line-oriented (already attempted above in other branches)
    // 2) token-oriented: build a token stream and scan for numeric sequences
    //    that match the row pattern (ranking, pts, time, factor, stagePoints,
    //    stagePercent, competitor_number, competitor_name...). This allows
    //    parsing when layout/newlines are lost.
    final lines = fallbackText.split(RegExp(r"\r?\n"));
    for (var line in lines) {
        line = line.trim();
      if (line.isEmpty) continue;

      final dmatch = divisionRegex.firstMatch(line);
      if (dmatch != null) {
        currentDivision = dmatch.group(1)!.trim();
        continue;
      }

      final smatch = stageRegex.firstMatch(line);
      if (smatch != null) {
        currentStage = smatch.group(1)!;
        continue;
      }

      final m = rowRegex.firstMatch(line);
      if (m != null) {
        final pts = double.tryParse(m.group(2)!) ?? 0.0;
        final time = double.tryParse(m.group(3)!) ?? 0.0;
        final hitFactor = double.tryParse(m.group(4)!) ?? 0.0;
        final stagePoints = double.tryParse(m.group(5)!) ?? 0.0;
        final stagePercent = double.tryParse(m.group(6)!) ?? 0.0;
        final compNum = int.tryParse(m.group(7)!) ?? 0;
        final name = m.group(8)!.trim();

        rows.add(ResultRow(
          competitorNumber: compNum,
          competitorName: name,
          stage: currentStage,
          division: currentDivision,
          points: pts,
          time: time,
          hitFactor: hitFactor,
          stagePoints: stagePoints,
          stagePercentage: stagePercent,
        ));
      }
    }

    if (rows.isEmpty) {
      final tokenRows = _extractRowsFromTokens(fallbackText, currentDivision, currentStage);
      rows.addAll(tokenRows);
    }

    return rows;
  }

  /// Very small heuristic extractor: looks for text-like literal tokens inside
  /// parentheses in the PDF file and joins nearby tokens into lines. This is
  /// not a fully accurate PDF text extractor, but works reasonably on many
  /// layout-preserved PDFs where text is stored in literal strings.
  Future<String> _extractTextHeuristic(File file) async {
    final bytes = await file.readAsBytes();
  final content = latin1.decode(bytes, allowInvalid: true);
  final buffer = StringBuffer();

    // First try: find stream...endstream blocks and attempt Flate (zlib)
    final streamRe = RegExp(r"stream\s*\r?\n", multiLine: true);
    for (final m in streamRe.allMatches(content)) {
      final startIdx = m.end; // position after 'stream\n'
      final endIdx = content.indexOf('endstream', startIdx);
      if (endIdx <= startIdx) continue;

      // Map to byte indices (latin1 decode preserves byte positions)
      final startByte = content.substring(0, startIdx).length;
      final endByte = content.substring(0, endIdx).length;
      final segment = bytes.sublist(startByte, endByte);

      // Try to decompress (many content streams are Flate decoded)
      try {
        final decompressed = ZLibDecoder().convert(segment);
        final s = latin1.decode(decompressed, allowInvalid: true);
        // extract parenthesis tokens from decompressed stream
        final parenRegex = RegExp(r"\(([^)]{1,1000}?)\)");
        for (final pm in parenRegex.allMatches(s)) {
          var token = pm.group(1)!.replaceAll(RegExp(r"\s+"), ' ').trim();
          if (token.isNotEmpty) buffer.writeln(token);
        }

        // Also extract numeric-like tokens (numbers with decimals) from the
        // decompressed stream. Some PDFs don't store visible text in
        // parentheses but numeric text appears as separate tokens.
        final numRegex = RegExp(r"\d+\.?\d{0,4}");
        for (final nm in numRegex.allMatches(s)) {
          final n = nm.group(0)!.trim();
          if (n.isNotEmpty) buffer.writeln(n);
        }
      } catch (_) {
        // ignore decompression failures
      }

  // continue to next match
    }

    // Secondary pass: fall back to simple parenthesis extraction across whole file
    final parenRegex = RegExp(r"\(([^)]{1,500}?)\)");
    for (final m in parenRegex.allMatches(content)) {
      var token = m.group(1)!.replaceAll(RegExp(r"\s+"), ' ').trim();
      if (token.isEmpty) continue;
      buffer.writeln(token);
    }

    // Also extract numeric-like tokens from the raw content as a last resort.
    // This increases the chance that the token-based row scanner finds the
    // numeric sequence even if textual names are missing or split.
    final numRegex2 = RegExp(r"\d+\.?\d{0,4}");
    for (final nm in numRegex2.allMatches(content)) {
      final n = nm.group(0)!.trim();
      if (n.isNotEmpty) buffer.writeln(n);
    }

    return buffer.toString();
  }

  /// Build a token stream from the extracted text and scan for numeric
  /// sequences matching the row pattern. This recovers rows when layout is
  /// flattened and newlines are unreliable.
  List<ResultRow> _extractRowsFromTokens(String text, String defaultDivision, String defaultStage) {
    final rows = <ResultRow>[];
    final tokens = <String>[];

    // Simple tokenizer: separate by whitespace, but keep punctuation attached
    for (final part in text.split(RegExp(r"\s+"))) {
      if (part.trim().isEmpty) continue;
      tokens.add(part.trim());
    }

    // Helper regexes matching the numeric fields in order
    final intRe = RegExp(r"^\d+");
    final ptsRe = RegExp(r"^\d+");
    final timeRe = RegExp(r"^\d+\.\d{1,2}");
    final factorRe = RegExp(r"^\d+\.\d{4}");
    final stagePointsRe = RegExp(r"^\d+\.\d{4}");
    final pctRe = RegExp(r"^\d+\.\d{1,2}");

    int i = 0;
    while (i + 6 < tokens.length) {
      // Try to match the numeric sequence at tokens[i]..tokens[i+6]
      if (intRe.hasMatch(tokens[i]) &&
          ptsRe.hasMatch(tokens[i + 1]) &&
          timeRe.hasMatch(tokens[i + 2]) &&
          factorRe.hasMatch(tokens[i + 3]) &&
          stagePointsRe.hasMatch(tokens[i + 4]) &&
          pctRe.hasMatch(tokens[i + 5]) &&
          intRe.hasMatch(tokens[i + 6])) {
        try {
          final pts = double.parse(tokens[i + 1]);
          final time = double.parse(tokens[i + 2]);
          final hitFactor = double.parse(tokens[i + 3]);
          final stagePoints = double.parse(tokens[i + 4]);
          final stagePercent = double.parse(tokens[i + 5]);
          final compNum = int.parse(RegExp(r"\d+").firstMatch(tokens[i + 6])!.group(0)!);

          // competitor name: collect subsequent tokens until the next token
          // looks like a new ranking (an integer) followed by the numeric pattern
          final nameParts = <String>[];
          int j = i + 7;
          while (j < tokens.length) {
            // check if a new candidate row starts here
            if (j + 6 < tokens.length && intRe.hasMatch(tokens[j]) && ptsRe.hasMatch(tokens[j + 1])) {
              break;
            }
            nameParts.add(tokens[j]);
            j++;
          }
          final name = nameParts.join(' ').replaceAll(RegExp(r"\s+"), ' ').trim();

          rows.add(ResultRow(
            competitorNumber: compNum,
            competitorName: name,
            stage: defaultStage,
            division: defaultDivision,
            points: pts,
            time: time,
            hitFactor: hitFactor,
            stagePoints: stagePoints,
            stagePercentage: stagePercent,
          ));

          i = j; // continue after the name
          continue;
        } catch (_) {
          // On any parse error, skip ahead one token
        }
      }
      i++;
    }

    return rows;
  }
}
