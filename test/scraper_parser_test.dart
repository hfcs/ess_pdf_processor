import 'dart:io';

import 'package:ess_pdf_processor/scraper/ess_scraper.dart';
import 'package:test/test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart';

Document importHtml(String s) => html_parser.parse(s);

void main() {
  test('parseDivisionStagesFromDocument parses stage table rows', () async {
    final fixture = File('test/fixtures/stage_page.html').readAsStringSync();
    final doc = importHtml(fixture);
    final docRows = EssScraper.parseDivisionStagesFromDocument(doc);
    expect(docRows.length, 2);
    final first = docRows[0];
    expect(first.competitorNumber, 194);
    expect(first.competitorName, contains('Wu, Chun Ki'));
    expect(first.stage, contains('Stage 01'));
    expect(first.stagePoints, equals(112.0));
    expect(first.time, closeTo(13.74, 0.001));
  });
}
