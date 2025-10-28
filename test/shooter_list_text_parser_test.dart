import 'package:test/test.dart';
import 'package:ess_pdf_processor/parser/shooter_list_text_parser.dart';

void main() {
  group('parseShooterListFromText', () {
    test('extracts class tokens and blank for missing token', () {
      final text = '''
101 John Doe A
102 Jane Smith GM
103 Bob NoClass
''';

      final map = parseShooterListFromText(text);
      expect(map[101], 'A');
      expect(map[102], 'GM');
      expect(map[103], '');
    });

    test('prefers first occurrence unless first is blank then later non-empty', () {
      final text = '''
200 First Blank
200 First A
201 First B
201 Second
''';
      final map = parseShooterListFromText(text);
      // 200: first was blank, later A -> should pick A
      expect(map[200], 'A');
      // 201: first was B, later blank -> should keep B
      expect(map[201], 'B');
    });

    test('ignores malformed lines without leading number', () {
      final text = '''
Alice No Number A
  
300 Valid C
''';
      final map = parseShooterListFromText(text);
      expect(map.containsKey(300), isTrue);
      expect(map.containsKey(0), isFalse);
      expect(map.containsKey(999), isFalse);
    });
  });
}
