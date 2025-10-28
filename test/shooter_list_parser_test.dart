import 'dart:io';

import 'package:test/test.dart';
import 'package:ess_pdf_processor/parser/shooter_list_parser.dart';

void main() {
  test('parse shooter list returns valid mapping', () async {
    final file = File('test/sample_data/Bang-Bang-Cup-2025-Competitor-R2-Listing-By-Competitor-Number-v4.pdf');
    expect(await file.exists(), isTrue, reason: 'shooter list PDF must be present in test/sample_data');

    final map = await parseShooterList(file);
    expect(map, isNotEmpty);

    // All class tokens must be either blank or one of the allowed tokens
    final allowed = {'', 'C', 'B', 'A', 'M', 'GM'};
    for (final v in map.values) {
      expect(allowed.contains(v), isTrue, reason: 'unexpected class token: $v');
    }
  }, timeout: Timeout(Duration(seconds: 30)));
}
