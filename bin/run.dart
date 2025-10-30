import 'dart:io';

import 'package:ess_pdf_processor/parser/pdf_dart_parser.dart';
import 'package:ess_pdf_processor/models/result_row.dart';
import 'package:ess_pdf_processor/parser/pdfjs_extractor.dart' as pdfjs_extractor;
import 'package:ess_pdf_processor/parser/shooter_list_parser.dart' as shooter_list_parser;
import 'package:ess_pdf_processor/parser/text_parser.dart' show parseTextToRows;

Future<void> main(List<String> args) async {
  if (args.length < 2) {
    print('Usage: dart run bin/run.dart <input.pdf> <output.csv> [--pdfjs] [--shooter-list <file>] [--force-fallback]');
    exit(2);
  }

  final input = args[0];
  final output = args[1];

  final file = File(input);
  if (!await file.exists()) {
    stderr.writeln('Input file not found: $input');
    exit(2);
  }

  final parser = PdfDartParser(file);
  print('Parsing PDF: $input');

  // Optionally prefer pdf.js Node extractor when --pdfjs flag is provided.
  final usePdfJs = args.contains('--pdfjs');
  String? shooterListPath;
  final forceFallback = args.contains('--force-fallback');
  if (args.contains('--shooter-list')) {
    final idx = args.indexOf('--shooter-list');
    if (idx >= 0 && idx + 1 < args.length) shooterListPath = args[idx + 1];
  }
  List<ResultRow> rows;
  if (usePdfJs) {
    print('Using Node/pdf.js extractor (requires node + pdfjs-dist)');
    try {
      final extracted = await pdfjs_extractor.extractWithPdfJs(file);
      // parse extracted text using shared text parser for consistency
      await File('${output}_pdfjs_tmp.txt').writeAsString(extracted);
      rows = parseTextToRows(extracted, defaultDivision: 'UNKNOWN');
    } catch (e) {
      print('pdf.js extraction failed: $e');
      rows = await parser.parse();
    }
    } else {
    rows = await parser.parse(forceFallback: forceFallback);
  }
  // If a shooter list was provided via CLI, parse and apply mapping
  if (shooterListPath != null) {
    final sfile = File(shooterListPath);
    if (await sfile.exists()) {
      try {
        final map = await shooter_list_parser.parseShooterList(sfile);
        for (final r in rows) {
          final raw = map[r.competitorNumber];
          if (raw != null) {
            final value = raw.trim();
            r.classification = (value.isEmpty || value == 'GM') ? 'Overall' : value;
          }
        }
      } catch (e) {
        print('Failed to parse shooter list: $e');
      }
    } else {
      print('Shooter list file not found: $shooterListPath');
    }
  }

  print('Parsed ${rows.length} rows. Writing to $output');

  final outFile = File(output);
  await outFile.create(recursive: true);

  final sink = outFile.openWrite();
  sink.writeln(ResultRow.csvHeader().join(','));
  for (final r in rows) {
    sink.writeln(r.toCsvRow().join(','));
  }
  await sink.flush();
  await sink.close();

  print('Done.');
}
