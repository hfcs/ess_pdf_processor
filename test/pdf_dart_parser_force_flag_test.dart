import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:ess_pdf_processor/parser/pdf_dart_parser.dart';

void main() {
  test('forceFallback flag forces heuristic path even if pdftotext exists', () async {
    final tmp = Directory.systemTemp.createTempSync('ess_pdf_force_');
    final file = File('${tmp.path}/fixture_force.pdf');

    // Create a minimal parenthesis token that would parse via heuristic
    final contentText = '(1 10 18.23 3.4567 10.1234 75.00 501 Forced Fallback)\n';
    final compressed = zlib.encode(latin1.encode(contentText));

    final header = latin1.encode('%PDF-1.4\n');
    final streamStart = latin1.encode('stream\n');
    final streamEnd = latin1.encode('\nendstream\n');

    final bytes = <int>[];
    bytes.addAll(header);
    bytes.addAll(streamStart);
    bytes.addAll(compressed);
    bytes.addAll(streamEnd);

    file.writeAsBytesSync(bytes, flush: true);

    // Provide a fake runner that would normally succeed (simulate pdftotext),
    // but because we set forceFallback=true, parser should skip calling it.
    Future<ProcessResult> fakeRunner(String cmd, List<String> args) async {
      return ProcessResult(0, 0, '1 10 18.23 3.4567 10.1234 75.00 999 ShouldNotUse\n', '');
    }

    final parser = PdfDartParser(file);
    final rows = await parser.parse(processRunner: fakeRunner, forceFallback: true);

    expect(rows, isNotEmpty);
    expect(rows.map((r) => r.competitorNumber), contains(501));

    tmp.deleteSync(recursive: true);
  });
}
