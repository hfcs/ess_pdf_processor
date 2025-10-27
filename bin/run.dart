import 'dart:io';

import 'package:ess_pdf_processor/parser/pdf_dart_parser.dart';
import 'package:ess_pdf_processor/models/result_row.dart';

Future<void> main(List<String> args) async {
  if (args.length < 2) {
    print('Usage: dart run bin/run.dart <input.pdf> <output.csv>');
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
  final rows = await parser.parse();
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
