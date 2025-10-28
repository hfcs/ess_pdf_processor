import '../models/result_row.dart';

/// Parse extracted text (layout-preserved or heuristic) into a list of
/// [ResultRow]. This function is platform-neutral and can be used by both
/// the CLI and the web demo (where text comes from pdf.js).
List<ResultRow> parseTextToRows(String text, {String defaultDivision = 'UNKNOWN'}) {
  final rows = <ResultRow>[];
  var currentDivision = defaultDivision;
  var currentStage = '';

  final rowRegex = RegExp(r"^\s*(\d+)\s+(\d+)\s+(\d+(?:\.\d{1,2})?)\s+(\d+\.\d{4})\s+(\d+\.\d{4})\s+(\d+(?:\.\d{1,2})?)\s+(\d+)\s+(.+?)\s*$");
  final divisionRegex = RegExp(r"^([A-Za-z0-9 &/\-]+)\s*--\s*Overall Stage Results", caseSensitive: false);
  final stageRegex = RegExp(r"^Stage\s+(\d+)", caseSensitive: false);

  final lines = text.split(RegExp(r"\r?\n"));
  for (var raw in lines) {
    var line = raw.trim();
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

  // If no rows were found using line-oriented regex, try a token-based
  // approach similar to the CLI fallback.
  rows.addAll(_extractRowsFromTokens(text, defaultDivision, ''));
  return rows;
}

List<ResultRow> _extractRowsFromTokens(String text, String defaultDivision, String defaultStage) {
  final rows = <ResultRow>[];
  final tokens = <String>[];

  for (final part in text.split(RegExp(r"\s+"))) {
    if (part.trim().isEmpty) continue;
    tokens.add(part.trim());
  }

  final intRe = RegExp(r"^\d+");
  final ptsRe = RegExp(r"^\d+");
  final timeRe = RegExp(r"^\d+\.\d{1,2}");
  final factorRe = RegExp(r"^\d+\.\d{4}");
  final stagePointsRe = RegExp(r"^\d+\.\d{4}");
  final pctRe = RegExp(r"^\d+\.\d{1,2}");

  int i = 0;
  while (i + 6 < tokens.length) {
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

        final nameParts = <String>[];
        int j = i + 7;
        while (j < tokens.length) {
          if (j + 6 < tokens.length && intRe.hasMatch(tokens[j]) && ptsRe.hasMatch(tokens[j + 1])) break;
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

        i = j;
        continue;
      } catch (_) {
        // skip on parse error
      }
    }
    i++;
  }

  return rows;
}
