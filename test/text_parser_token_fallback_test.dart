import 'package:test/test.dart';
import 'package:ess_pdf_processor/parser/text_parser.dart';

void main() {
  test('text_parser token-based fallback reconstructs row from newline-separated tokens', () {
    // Each token is on its own line so the line-oriented regex won't match;
    // parseTextToRows should call the token-based fallback and reconstruct the row.
    final tokens = [
      '1', // rank
      '10', // pts
      '18.23', // time
      '3.4567', // hitFactor (4 decimals)
      '10.1234', // stagePoints (4 decimals)
      '75.00', // stagePercent (2 decimals)
      '601', // competitor number
      'First',
      'Last'
    ];

    final text = tokens.join('\n');

    final rows = parseTextToRows(text, defaultDivision: 'FALLBACK');
    expect(rows, isNotEmpty);
    expect(rows.first.competitorNumber, equals(601));
    expect(rows.first.competitorName, contains('First'));
  });
}
