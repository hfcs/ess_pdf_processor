import 'dart:convert';
import 'dart:io';

// Convert the old demo CSV (division,stage,line) into the canonical
// CSV required by the regression script:
// competitor_number,competitor_name,stage,division,points,time,hit_factor,stage_points,stage_percentage

final outHeader = 'competitor_number,competitor_name,stage,division,points,time,hit_factor,stage_points,stage_percentage';

String unquote(String s) {
  if (s.startsWith('"') && s.endsWith('"') && s.length >= 2) {
    return s.substring(1, s.length - 1).replaceAll('""', '"');
  }
  return s;
}

Map<String, String>? parseLine(String rawLine) {
  // Try regex per copilot-instructions.md
  final re = RegExp(r"^\s*(\d+)\s+(\d+)\s+(\d+(?:\.\d{1,2})?)\s+(\d+\.\d{4})\s+(\d+\.\d{4})\s+(\d+\.\d{1,2})\s+(\d+)\s+(.+?)\s*");
  final m = re.firstMatch(rawLine);
  if (m != null) {
    // groups: ranking, pts, time, hit_factor, stage_points, stage_percentage, competitor_number, competitor_name
    final pts = m.group(2)!;
    final time = m.group(3)!;
    final hitFactor = m.group(4)!;
    final stagePoints = m.group(5)!;
    final stagePct = m.group(6)!;
    final competitorNumber = m.group(7)!;
    final competitorName = m.group(8)!.trim();
    return {
      'competitor_number': competitorNumber,
      'competitor_name': competitorName,
      'points': pts,
      'time': time,
      'hit_factor': hitFactor,
      'stage_points': stagePoints,
      'stage_percentage': stagePct,
    };
  }

  // Fallback: token-based heuristic. Find last integer token as competitor number.
  final toks = rawLine.trim().split(RegExp(r'\s+'));
    for (var i = toks.length - 1; i >= 0; i--) {
      final candidate = toks[i].replaceAll(RegExp(r'[^0-9]'), '');
      if (candidate.isEmpty) continue;
      if (RegExp(r'^\d+').hasMatch(candidate)) {
        final competitorNumber = candidate;
        final name = toks.sublist(i + 1).join(' ').trim();
        String pts = '';
        String time = '';
        if (toks.length > 1 && RegExp(r'^\d+(?:\.\d+)?$').hasMatch(toks[1])) pts = toks[1];
        if (toks.length > 2 && RegExp(r'^\d+(?:\.\d{1,2})?$').hasMatch(toks[2])) time = toks[2];
        return {
          'competitor_number': competitorNumber,
          'competitor_name': name,
          'points': pts,
          'time': time,
          'hit_factor': '',
          'stage_points': '',
          'stage_percentage': '',
        };
      }
    }
  return null;
}

String csvEscape(String s) {
  if (s.contains(',') || s.contains('"') || s.contains('\n')) {
    return '"' + s.replaceAll('"', '""') + '"';
  }
  return s;
}

Future<int> main(List<String> args) async {
  final inPath = args.isNotEmpty ? args[0] : 'out/extracted_rows.csv';
  final outPath = args.length > 1 ? args[1] : 'out/extracted_rows_converted.csv';

  final inFile = File(inPath);
  if (!await inFile.exists()) {
    stderr.writeln('Input CSV not found: $inPath');
    return 2;
  }
  final lines = await inFile.readAsLines(encoding: utf8);
  if (lines.isEmpty) {
    stderr.writeln('Input CSV is empty');
    return 2;
  }

  final outFile = File(outPath);
  final sink = outFile.openWrite(encoding: utf8);
  sink.writeln(outHeader);

  for (final raw in lines.skip(1)) {
    if (raw.trim().isEmpty) continue;
    final parts = <String>[];
    var i = 0;
    while (i < raw.length) {
      if (raw[i] == '"') {
        var j = i + 1;
        final sb = StringBuffer();
        while (j < raw.length) {
          if (raw[j] == '"') {
            if (j + 1 < raw.length && raw[j + 1] == '"') {
              sb.write('"');
              j += 2;
              continue;
            } else {
              j++;
              break;
            }
          } else {
            sb.write(raw[j]);
            j++;
          }
        }
        parts.add(sb.toString());
        if (j < raw.length && raw[j] == ',') j++;
        i = j;
      } else {
        final next = raw.indexOf(',', i);
        if (next == -1) {
          parts.add(raw.substring(i));
          break;
        } else {
          parts.add(raw.substring(i, next));
          i = next + 1;
        }
      }
    }

    String division = parts.length > 0 ? parts[0] : '';
    String stageRaw = parts.length > 1 ? parts[1] : '';
    String lineField = parts.length > 2 ? parts[2] : '';

    division = unquote(division).trim();
    stageRaw = unquote(stageRaw).trim();
    lineField = unquote(lineField).trim();

    var parsed = parseLine(lineField);

    final compNum = parsed != null ? parsed['competitor_number'] ?? '' : '';
    final compName = parsed != null ? parsed['competitor_name'] ?? '' : '';
    final points = parsed != null ? parsed['points'] ?? '' : '';
    final time = parsed != null ? parsed['time'] ?? '' : '';
    final hitFactor = parsed != null ? parsed['hit_factor'] ?? '' : '';
    final stagePoints = parsed != null ? parsed['stage_points'] ?? '' : '';
    final stagePct = parsed != null ? parsed['stage_percentage'] ?? '' : '';

    final stageMatch = RegExp(r"(\d+)").firstMatch(stageRaw);
    final stage = stageMatch != null ? stageMatch.group(1)! : '1';

    final outCols = [
      compNum,
      compName,
      stage,
      division,
      points,
      time,
      hitFactor,
      stagePoints,
      stagePct,
    ];
  sink.writeln(outCols.map((s) => csvEscape(s)).join(','));
  }

  await sink.flush();
  await sink.close();
  stdout.writeln('Converted CSV written to $outPath');
  return 0;
}
