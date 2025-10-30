import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:ess_pdf_processor/parser/pdf_dart_parser.dart';

void main() {
  test('TJ array operator in compressed stream is parsed', () async {
    final tmp = Directory.systemTemp.createTempSync('ess_pdf_zlib_');
    final file = File('${tmp.path}/fixture_tj.pdf');

    final contentText = '''
1 0 0 1 120 220 Tm
[(1 15 17.50 3.1111 11.0000 90.00 126 Bob)] TJ
''';

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

    Future<ProcessResult> fakeRunner(String cmd, List<String> args) async {
      return ProcessResult(1, 1, '', 'no pdftotext');
    }

    final parser = PdfDartParser(file);
    final rows = await parser.parse(processRunner: fakeRunner);

    expect(rows, isNotEmpty);
    expect(rows.map((r) => r.competitorNumber), contains(126));

    tmp.deleteSync(recursive: true);
  });

  test('uncompressed stream with parentheses falls back to parenthesis extraction', () async {
    final tmp = Directory.systemTemp.createTempSync('ess_pdf_plain_');
    final file = File('${tmp.path}/fixture_plain.pdf');

    // Build a stream that is NOT compressed so the ZLibDecoder will throw
    // and the secondary pass (parenthesis extraction) will be used.
    final contentText = '''
(1 20 19.99 4.0000 12.0000 95.00 127 Alice Wonderland)\n
''';

    final header = latin1.encode('%PDF-1.4\n');
    final streamStart = latin1.encode('stream\n');
    final streamEnd = latin1.encode('\nendstream\n');

    final bytes = <int>[];
    bytes.addAll(header);
    bytes.addAll(streamStart);
    bytes.addAll(latin1.encode(contentText));
    bytes.addAll(streamEnd);

    file.writeAsBytesSync(bytes, flush: true);

    Future<ProcessResult> fakeRunner(String cmd, List<String> args) async {
      return ProcessResult(1, 1, '', 'no pdftotext');
    }

    final parser = PdfDartParser(file);
    final rows = await parser.parse(processRunner: fakeRunner);

    expect(rows, isNotEmpty);
    expect(rows.map((r) => r.competitorNumber), contains(127));

    tmp.deleteSync(recursive: true);
  });

  test('combined Tj and TJ variations are both captured', () async {
    final tmp = Directory.systemTemp.createTempSync('ess_pdf_zlib_combo_');
    final file = File('${tmp.path}/fixture_combo.pdf');

    final contentText = '''
1 0 0 1 130 230 Tm
(1 11 18.00 3.5000 10.0000 85.00 128 Charlie) Tj
1 0 0 1 130 210 Tm
[(2 9 21.00 2.7500 8.2500 70.00 129 Delta)] TJ
''';

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

    Future<ProcessResult> fakeRunner(String cmd, List<String> args) async {
      return ProcessResult(1, 1, '', 'no pdftotext');
    }

    final parser = PdfDartParser(file);
    final rows = await parser.parse(processRunner: fakeRunner);

    expect(rows, isNotEmpty);
    final nums = rows.map((r) => r.competitorNumber).toSet();
    expect(nums, containsAll([128, 129]));

    tmp.deleteSync(recursive: true);
  });
}
