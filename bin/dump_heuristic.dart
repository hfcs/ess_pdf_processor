import 'dart:io';

import 'package:ess_pdf_processor/parser/pdf_dart_parser.dart';

Future<void> main(List<String> args) async {
  if (args.length < 2) {
    print('Usage: dart run bin/dump_heuristic.dart <input.pdf> <output.txt>');
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
  final txt = await parser.extractFallbackText();
  final out = File(output);
  await out.create(recursive: true);
  await out.writeAsString(txt);
  print('Wrote heuristic text to $output');
}
