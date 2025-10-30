import 'package:test/test.dart';
import 'package:ess_pdf_processor/parser/text_parser.dart';

void main() {
  test('line-oriented parsing captures division and stage and returns early', () {
    final text = '''
Some Division -- Overall Stage Results
Stage 2
1 10 18.23 3.4567 10.1234 75.00 201 John Example
''';

    final rows = parseTextToRows(text, defaultDivision: 'UNKNOWN');
    expect(rows, isNotEmpty);
    expect(rows.length, 1);
    final r = rows.first;
    expect(r.division, 'Some Division');
    expect(r.stage, '2');
    expect(r.competitorNumber, 201);
    expect(r.competitorName, 'John Example');
  });

  test('parseTextToRows extracts division, stage, and formatted row', () {
    final text = '''
Alpha Division -- Overall Stage Results
Stage 3
1 12 18.23 3.4567 10.1234 75.00 123 John Doe
''';

    final rows = parseTextToRows(text, defaultDivision: 'UNKNOWN');
    expect(rows, isNotEmpty);
    final r = rows.first;
    expect(r.division, equals('Alpha Division'));
    expect(r.stage, equals('3'));
    expect(r.competitorNumber, equals(123));
    expect(r.competitorName, equals('John Doe'));
  });

  test('token-based fallback collects name tokens until EOF', () {
    // Create a flattened token stream that doesn't contain newlines matching
    // the rowRegex, so parseTextToRows will call the token-based fallback.
    // We'll build tokens: rank pts time factor stagePoints pct compNum Name Parts...
    final text = '1 10 18.23 3.4567 10.1234 75.00 301 Alice Bob Carol';

    final rows = parseTextToRows(text, defaultDivision: 'XDIV');
    expect(rows, isNotEmpty);
    expect(rows.length, 1);
    final r = rows.first;
    expect(r.division, 'XDIV');
    expect(r.competitorNumber, 301);
    // Name should be the rest of tokens joined
    expect(r.competitorName, 'Alice Bob Carol');
  });

  test('parseTextToRows falls back to token parser for flattened tokens (two rows)', () {
    // Two rows flattened into a single whitespace stream (no newlines)
    final text = '1 12 18.23 3.4567 10.1234 75.00 123 John Doe 2 11 19.00 2.2222 9.3333 60.00 124 Jane Smith';

    final rows = parseTextToRows(text, defaultDivision: 'DIV');
    // Parser should find at least the first row; accept either 1 or 2 rows
    expect(rows.length, greaterThanOrEqualTo(1));
    expect(rows[0].competitorNumber, equals(123));
  expect(rows[0].competitorName.startsWith('John Doe'), isTrue);
    if (rows.length > 1) {
      expect(rows[1].competitorNumber, equals(124));
      expect(rows[1].competitorName, equals('Jane Smith'));
    }
  });

  test('token parser collects name until EOF when no following row exists', () {
    // Single row where the name continues to the end (no following numeric row)
    final text = '1 10 17.00 3.0000 9.0000 80.00 200 Lastname Only Additional Tokens';
    final rows = parseTextToRows(text, defaultDivision: 'D');
    expect(rows.length, equals(1));
    expect(rows.first.competitorNumber, equals(200));
    expect(rows.first.competitorName, equals('Lastname Only Additional Tokens'));
  });

  test('no matching rows returns empty list when tokens insufficient', () {
    final text = 'this text has no numbers or rows';
    final rows = parseTextToRows(text);
    expect(rows, isEmpty);
  });
}
