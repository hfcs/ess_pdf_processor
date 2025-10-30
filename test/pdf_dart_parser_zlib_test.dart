import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:ess_pdf_processor/parser/pdf_dart_parser.dart';

void main() {
  test('decompressed stream...endstream yields rows via Tm/Tj tokens', () async {
    final tmp = Directory.systemTemp.createTempSync('ess_pdf_zlib_');
    final file = File('${tmp.path}/fixture.pdf');

    // Build a decompressed stream containing a Tm matrix and (text) Tj tokens
    final contentText = '''
1 0 0 1 100 200 Tm
(1 12 18.23 3.4567 10.1234 75.00 123 John Doe) Tj
1 0 0 1 100 180 Tm
(2 10 20.00 2.3456 9.8765 60.50 124 Jane Smith) Tj
''';

    // zlib-compress the contentText
    final compressed = zlib.encode(latin1.encode(contentText));

    // Construct a minimal PDF-like byte sequence with stream...endstream
    final header = latin1.encode('%PDF-1.4\n');
    final streamStart = latin1.encode('stream\n');
    final streamEnd = latin1.encode('\nendstream\n');

    final bytes = <int>[];
    bytes.addAll(header);
    bytes.addAll(streamStart);
    bytes.addAll(compressed);
    bytes.addAll(streamEnd);

    file.writeAsBytesSync(bytes, flush: true);

    // Simulate pdftotext not available so parser uses heuristic path
    Future<ProcessResult> fakeRunner(String cmd, List<String> args) async {
      return ProcessResult(1, 1, '', 'no pdftotext');
    }

    final parser = PdfDartParser(file);
    final rows = await parser.parse(processRunner: fakeRunner);

    expect(rows, isNotEmpty);
    // Should have parsed two rows with the competitor numbers we embedded
    expect(rows.map((r) => r.competitorNumber), containsAll([123, 124]));

    tmp.deleteSync(recursive: true);
  });
}
