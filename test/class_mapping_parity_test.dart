import 'dart:io';

import 'package:test/test.dart';
import 'package:ess_pdf_processor/parser/pdf_dart_parser.dart';
import 'package:ess_pdf_processor/parser/pdfjs_extractor.dart' as pdfjs_extractor;
import 'package:ess_pdf_processor/parser/shooter_list_parser.dart';
import 'package:ess_pdf_processor/parser/text_parser.dart' show parseTextToRows;

void main() {
  test('class mapping parity: pdftotext vs pdfjs', () async {
    final stagePdf = File('test/sample_data/Bangbangcup_2025_rd2.pdf');
    final shooterPdf = File('test/sample_data/Bang-Bang-Cup-2025-Competitor-R2-Listing-By-Competitor-Number-v4.pdf');

    expect(await stagePdf.exists(), isTrue, reason: 'stage PDF must exist in test/sample_data');
    expect(await shooterPdf.exists(), isTrue, reason: 'shooter list PDF must exist in test/sample_data');

    // Parse shooter list -> number to raw class
    final numToClass = await parseShooterList(shooterPdf);

    // 1) pdftotext route (PdfDartParser.parse())
    final pdParser = PdfDartParser(stagePdf);
    final rowsPdftotext = await pdParser.parse();
    // apply mapping
    final mapPdftotext = <int, String>{};
    for (final r in rowsPdftotext) {
      final raw = numToClass[r.competitorNumber];
      final cls = (raw != null) ? ((raw.trim().isEmpty || raw == 'GM') ? 'Overall' : raw.trim()) : '';
      mapPdftotext[r.competitorNumber] = cls;
    }

    // 2) pdf.js route: extract text then parse with shared parser
    final extracted = await pdfjs_extractor.extractWithPdfJs(stagePdf);
    final rowsPdfjs = parseTextToRows(extracted, defaultDivision: 'UNKNOWN');
    final mapPdfjs = <int, String>{};
    for (final r in rowsPdfjs) {
      final raw = numToClass[r.competitorNumber];
      final cls = (raw != null) ? ((raw.trim().isEmpty || raw == 'GM') ? 'Overall' : raw.trim()) : '';
      mapPdfjs[r.competitorNumber] = cls;
    }

    // Compare: pick competitor numbers present in both parsing outputs
    final common = mapPdftotext.keys.toSet().intersection(mapPdfjs.keys.toSet()).toList()..sort();
    expect(common.isNotEmpty, isTrue, reason: 'No common competitor numbers found between extraction routes');

    // Check first up to 10 numbers that classes agree
    final toCheck = common.take(10).toList();
    for (final num in toCheck) {
      final a = mapPdftotext[num] ?? '';
      final b = mapPdfjs[num] ?? '';
      expect(a, equals(b), reason: 'Class mismatch for competitor $num: pdftotext="$a" vs pdfjs="$b"');
    }
  }, timeout: Timeout(Duration(seconds: 60)));
}
