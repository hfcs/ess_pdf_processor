import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:ess_pdf_processor/parser/pdf_dart_parser.dart';

void main() {
  test('token-based fallback in PdfDartParser is invoked when lines fail', () async {
    final tmp = Directory.systemTemp.createTempSync('ess_pdf_token_fallback_');
    final file = File('${tmp.path}/fixture_token.pdf');

    // Build decompressed content that produces many small tokens on separate
    // lines (so the line-oriented rowRegex will not match any single line),
    // but the token-based scanner should be able to reassemble rows.
    // We'll place each token on its own line by wrapping them in parentheses.

    // Tokens for a single row, but on separate lines:
    final tokens = [
      '(1)', // rank
      '(10)', // pts
      '(18.23)', // time
      '(3.4567)', // hitFactor
      '(10.1234)', // stagePoints
      '(75.00)', // stagePercent
      '(401)', // competitor number
      '(TokenFirst)',
      '(TokenLast)'
    ];

    final contentText = tokens.join('\n');

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
      // simulate pdftotext missing
      return ProcessResult(1, 1, '', 'no pdftotext');
    }

    final parser = PdfDartParser(file);
    final rows = await parser.parse(processRunner: fakeRunner);

    // token-based fallback should reconstruct the one row with competitor 401
    expect(rows, isNotEmpty);
    expect(rows.map((r) => r.competitorNumber), contains(401));

    tmp.deleteSync(recursive: true);
  });
}
