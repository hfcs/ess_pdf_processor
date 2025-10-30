import 'dart:io';

import 'package:test/test.dart';
import 'package:ess_pdf_processor/parser/pdf_dart_parser.dart';

void main() {
  test('fallback parenthesis pass produces rows when pdftotext missing', () async {
    final tmp = Directory.systemTemp.createTempSync('ess_pdf_test_');
    final file = File('${tmp.path}/fixture.pdf');

    // Put parenthesis-wrapped lines that match the rowRegex used by parser
    // Format: rank pts time hitFactor stagePoints stagePercent compNum name
    final content = '''
(1 12 18.23 3.4567 10.1234 75.00 123 John Doe)
(2 10 20.00 2.3456 9.8765 60.50 124 Jane Smith)
''';
    file.writeAsStringSync(content, flush: true);

    // Simulate pdftotext not available by returning non-zero exit code
    Future<ProcessResult> fakeRunner(String cmd, List<String> args) async {
      return ProcessResult(42, 1, '', 'not found');
    }

    final parser = PdfDartParser(file);
    final rows = await parser.parse(processRunner: fakeRunner);
    expect(rows, isNotEmpty);
    expect(rows.length, equals(2));
    expect(rows.first.competitorNumber, equals(123));
    expect(rows.first.competitorName, contains('John Doe'));

    tmp.deleteSync(recursive: true);
  });

  test('pdftotext success path returns parsed rows', () async {
    final tmp = Directory.systemTemp.createTempSync('ess_pdf_test_');
    final file = File('${tmp.path}/fixture.pdf');
    file.writeAsStringSync('ignored content', flush: true);

    // Simulate pdftotext producing layout-preserved text that parseTextToRows can handle
    final pdftotextOutput = '''
1 12 18.23 3.4567 10.1234 75.00 123 John Doe
2 10 20.00 2.3456 9.8765 60.50 124 Jane Smith
''';

    Future<ProcessResult> fakeRunner(String cmd, List<String> args) async {
      return ProcessResult(99, 0, pdftotextOutput, '');
    }

    final parser = PdfDartParser(file);
    final rows = await parser.parse(processRunner: fakeRunner);
    expect(rows, isNotEmpty);
    expect(rows.length, equals(2));
    expect(rows.last.competitorNumber, equals(124));
    expect(rows.last.competitorName, contains('Jane Smith'));

    tmp.deleteSync(recursive: true);
  });
}
