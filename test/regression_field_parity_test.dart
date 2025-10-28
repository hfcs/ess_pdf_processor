import 'dart:io';
import 'package:test/test.dart';
import 'package:ess_pdf_processor/parser/pdfjs_extractor.dart' as pdfjs_extractor;

List<String> _splitCsvLine(String line) {
  final parts = <String>[];
  final sb = StringBuffer();
  var inQuotes = false;
  for (var i = 0; i < line.length; i++) {
    final c = line[i];
    if (c == '"') {
      if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
        // escaped quote
        sb.write('"');
        i++;
        continue;
      }
      inQuotes = !inQuotes;
      continue;
    }
    if (c == ',' && !inQuotes) {
      parts.add(sb.toString());
      sb.clear();
      continue;
    }
    sb.write(c);
  }
  parts.add(sb.toString());
  return parts;
}

void main() {
  test('regression: pdftotext vs pdfjs field parity', () async {
    final pdf = 'test/sample_data/Bangbangcup_2025_rd2.pdf';
    final outPdftotext = 'out/results_poc_fields.csv';
    final outPdfjs = 'out/results_pdfjs_fields.csv';

    // Run pdftotext path (CLI default prefers pdftotext when available)
    var pr = await Process.run('dart', ['run', 'bin/run.dart', pdf, outPdftotext]);
    if (pr.exitCode != 0) {
      fail('pdftotext-run failed: ${pr.stdout}\n${pr.stderr}');
    }

    // Run pdfjs path
    pr = await Process.run('dart', ['run', 'bin/run.dart', pdf, outPdfjs, '--pdfjs']);
    if (pr.exitCode != 0) {
      fail('pdfjs-run failed: ${pr.stdout}\n${pr.stderr}');
    }

    final f1 = File(outPdftotext);
    final f2 = File(outPdfjs);
    expect(await f1.exists(), isTrue);
    expect(await f2.exists(), isTrue);

    final lines1 = await f1.readAsLines();
    final lines2 = await f2.readAsLines();
    expect(lines1.length, lines2.length, reason: 'row count mismatch');

    // compare header
    expect(lines1.first, lines2.first, reason: 'header mismatch');

    for (var i = 1; i < lines1.length; i++) {
      final a = _splitCsvLine(lines1[i]);
      final b = _splitCsvLine(lines2[i]);
      expect(a.length, b.length, reason: 'column count mismatch on row $i');
      for (var j = 0; j < a.length; j++) {
        if (a[j] != b[j]) {
          fail('Mismatch on row $i col $j:\n  pdftotext=${a[j]}\n  pdfjs   =${b[j]}');
        }
      }
    }

    // Additionally, compare raw Node extractor output to the Dart Node-wrapper
  final nodePr = await Process.run('node', ['scripts/extract_pdfjs.js', pdf]);
    if (nodePr.exitCode != 0) {
      fail('node extractor failed: ${nodePr.stderr}');
    }
    final nodeOut = (nodePr.stdout as String).trim();

    // The Dart wrapper should call the same node script; call it directly and compare.
    final dartWrapperOut = await pdfjs_extractor.extractWithPdfJs(File(pdf));
    expect(dartWrapperOut.trim(), nodeOut, reason: 'raw node extractor != dart wrapper output');
  }, timeout: Timeout(Duration(seconds: 180)));
}
