import 'dart:io';

import 'package:ess_pdf_processor/scraper/ess_scraper.dart';
import 'package:ess_pdf_processor/models/result_row.dart';

Future<void> main(List<String> args) async {
  if (args.length < 2) {
    print('Usage: dart run scripts/scrape_match.dart <match_url> <output.csv>');
    exit(2);
  }
  final url = args[0];
  final out = args[1];

  final scraper = EssScraper(Uri.parse(url), rateLimit: const Duration(seconds: 2));
  print('Scraping $url ...');
  final rows = await scraper.fetchAllStages();
  print('Scraped ${rows.length} rows, writing to $out');

  final f = File(out);
  await f.create(recursive: true);
  final sink = f.openWrite();
  sink.writeln(ResultRow.csvHeader().join(','));
  for (final r in rows) sink.writeln(r.toCsvRow().join(','));
  await sink.flush();
  await sink.close();
  print('Done.');
}
