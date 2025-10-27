import 'dart:io';

import 'package:ess_pdf_processor/parser/pdf_dart_parser.dart';
import 'package:ess_pdf_processor/models/result_row.dart';
import 'package:ess_pdf_processor/parser/pdfjs_extractor.dart' as pdfjs_extractor;

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

  // Optionally prefer pdf.js Node extractor when --pdfjs flag is provided.
  final usePdfJs = args.contains('--pdfjs');
  List<ResultRow> rows;
  if (usePdfJs) {
    print('Using Node/pdf.js extractor (requires node + pdfjs-dist)');
    try {
      final extracted = await pdfjs_extractor.extractWithPdfJs(file);
      // feed the extracted lines into the existing parser by simulating
      // pdftotext output: write to a temp file and call parse on it.
  await File('${output}_pdfjs_tmp.txt').writeAsString(extracted);
      // the parser currently reads the PDF file directly; to reuse parsing
      // logic, we'll instantiate a temporary PdfDartParser on the same PDF
      // but call its internal fallback extractor. For simplicity, call
      // parser.parse() but with heuristic text via a small trick: replace
      // the _extractTextHeuristic call isn't public; instead, we'll write
      // a small loop that parses lines similarly to the pdftotext branch.
      // For now, parse the extracted text by reusing parser.parse fallback
      // path: create a new parser and call parse(); If parse() finds rows
      // via pdftotext it will return them; otherwise, we will attempt to
      // parse extracted text directly below.
      rows = await parser.parse();
      if (rows.isEmpty) {
        // fallback: parse lines directly
        rows = [];
        final lines = extracted.split(RegExp(r"\r?\n"));
        String currentDivision = 'UNKNOWN';
        String currentStage = '';
        final rowRegex = RegExp(r"^\s*(\d+)\s+(\d+)\s+(\d+(?:\.\d{1,2})?)\s+(\d+\.\d{4})\s+(\d+\.\d{4})\s+(\d+\.\d{1,2})\s+(\d+)\s+(.+?)\s*$");
        final divisionRegex = RegExp(r"^([A-Za-z0-9 &/\-]+)\s*--\s*Overall Stage Results", caseSensitive: false);
        final stageRegex = RegExp(r"^Stage\s+(\d+)", caseSensitive: false);
        for (var line in lines) {
          line = line.trim();
          if (line.isEmpty) continue;
          final dmatch = divisionRegex.firstMatch(line);
          if (dmatch != null) { currentDivision = dmatch.group(1)!.trim(); continue; }
          final smatch = stageRegex.firstMatch(line);
          if (smatch != null) { currentStage = smatch.group(1)!; continue; }
          final m = rowRegex.firstMatch(line);
          if (m != null) {
            final pts = double.tryParse(m.group(2)!) ?? 0.0;
            final time = double.tryParse(m.group(3)!) ?? 0.0;
            final hitFactor = double.tryParse(m.group(4)!) ?? 0.0;
            final stagePoints = double.tryParse(m.group(5)!) ?? 0.0;
            final stagePercent = double.tryParse(m.group(6)!) ?? 0.0;
            final compNum = int.tryParse(m.group(7)!) ?? 0;
            final name = m.group(8)!.trim();
            rows.add(ResultRow(
              competitorNumber: compNum,
              competitorName: name,
              stage: currentStage,
              division: currentDivision,
              points: pts,
              time: time,
              hitFactor: hitFactor,
              stagePoints: stagePoints,
              stagePercentage: stagePercent,
            ));
          }
        }
      }
    } catch (e) {
      print('pdf.js extraction failed: $e');
      rows = await parser.parse();
    }
  } else {
    rows = await parser.parse();
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
