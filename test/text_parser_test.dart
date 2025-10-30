import 'package:test/test.dart';
import 'package:ess_pdf_processor/parser/text_parser.dart';
// result_row import not needed directly; parser returns ResultRow objects.

void main() {
  group('parseTextToRows', () {
    test('parses rows using line regex with division and stage', () {
      final input = '''
Division X -- Overall Stage Results
Stage 1
1 10 12.34 9.8765 8.1234 7.50 101 John Doe
2 20 15.00 10.0000 9.0000 8.00 102 Jane Smith
''';
      final rows = parseTextToRows(input, defaultDivision: 'DEF');
      expect(rows.length, equals(2));
      expect(rows[0].competitorNumber, equals(101));
      expect(rows[0].competitorName, contains('John Doe'));
      expect(rows[0].division, equals('Division X'));
      expect(rows[0].stage, equals('1'));
    });

    test('falls back to token extraction when line regex fails', () {
      // intentionally malformed lines that token parser should handle
      final input = '101 10 12.34 9.8765 8.1234 7.50 201 Alice\n202 20 15.00 10.0000 9.0000 8.00 102 Bob';
      final rows = parseTextToRows(input, defaultDivision: 'D', );
      // The fallback should detect at least one row
      expect(rows.isNotEmpty, isTrue);
      // Ensure competitor numbers were parsed
      expect(rows.any((r) => r.competitorNumber == 201), isTrue);
      expect(rows.any((r) => r.competitorNumber == 102 || r.competitorNumber == 202), isTrue);
    });

    test('ignores empty input and returns empty list', () {
      final rows = parseTextToRows('', defaultDivision: 'X');
      expect(rows, isEmpty);
    });
  });
}
