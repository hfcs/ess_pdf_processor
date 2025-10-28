import 'dart:convert';
import 'dart:io';

// Simple regression/integration check for exported CSV format and content.
// Usage: dart run scripts/regression_check.dart [path/to/csv]

const expectedHeader = 'competitor_number,competitor_name,stage,division,points,time,hit_factor,stage_points,stage_percentage';

List<String> parseCsvLine(String line) {
  // Very small CSV parser that handles double-quote escaping.
  final out = <String>[];
  var i = 0;
  while (i < line.length) {
    if (line[i] == '"') {
      var j = i + 1;
      final sb = StringBuffer();
      while (j < line.length) {
        if (line[j] == '"') {
          if (j + 1 < line.length && line[j + 1] == '"') {
            sb.write('"');
            j += 2;
            continue;
          } else {
            j++; // consume closing quote
            break;
          }
        } else {
          sb.write(line[j]);
          j++;
        }
      }
      out.add(sb.toString());
      // skip optional comma
      if (j < line.length && line[j] == ',') j++;
      i = j;
    } else {
      final next = line.indexOf(',', i);
      if (next == -1) {
        out.add(line.substring(i));
        break;
      } else {
        out.add(line.substring(i, next));
        i = next + 1;
      }
    }
  }
  // If the original line ends with a comma, the loop above can miss the final
  // empty field; append one empty string in that case.
  if (line.isNotEmpty && line.endsWith(',')) {
    out.add('');
  }
  return out;
}


bool looksHeaderLike(String s) {
  final t = s.toLowerCase();
  if (t.contains('printed')) return true;
  if (t.contains('[ess]')) return true;
  if (t.contains('page')) return true;
  if (RegExp(r'\bpts\b|\btime\b|\bfactor\b|\bpoints\b|\bpercent\b|#\s*name').hasMatch(t)) return true;
  return false;
}

Future<int> main(List<String> args) async {
  final path = args.isNotEmpty ? args[0] : 'out/extracted_rows.csv';
  final f = File(path);
  if (!await f.exists()) {
    stderr.writeln('CSV not found at $path');
    return 2;
  }
  final lines = await f.readAsLines(encoding: utf8);
  if (lines.isEmpty) {
    stderr.writeln('CSV is empty');
    return 2;
  }
  final header = lines.first.trim();
  if (header != expectedHeader) {
    stderr.writeln('Header mismatch. Expected:\n$expectedHeader\nGot:\n$header');
    return 2;
  }

  final rows = lines.skip(1).where((l) => l.trim().isNotEmpty).toList();
  if (rows.isEmpty) {
    stderr.writeln('No data rows found');
    return 2;
  }

  var badHeaderLike = 0;
  var shortNames = 0;
  for (final l in rows) {
    final cols = parseCsvLine(l);
    if (cols.length < 9) {
      stderr.writeln('Malformed row (wrong column count): $l');
      return 2;
    }
    final name = cols[1].trim();
    if (looksHeaderLike(name)) badHeaderLike++;
    if (name.length <= 1) shortNames++;
  }

  final shortPct = (shortNames / rows.length) * 100;
  if (badHeaderLike > 0) {
    stderr.writeln('Found $badHeaderLike rows with header-like text in competitor_name');
    return 2;
  }
  if (shortPct > 10) {
    stderr.writeln('Too many short competitor_name values: $shortNames / ${rows.length} (${shortPct.toStringAsFixed(1)}%)');
    return 2;
  }

  stdout.writeln('CSV checks passed. Rows: ${rows.length}. Short names: $shortNames.');
  return 0;
}
