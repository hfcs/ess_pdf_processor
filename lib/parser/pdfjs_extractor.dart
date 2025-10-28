import 'dart:io';

/// Run the Node/pdf.js extractor script (scripts/extract_pdfjs.js) and return
/// the extracted plain text (lines separated by \n). Requires `node` and
/// `pdfjs-dist` to be available (install via `npm install pdfjs-dist`).
Future<String> extractWithPdfJs(File file) async {
  final script = 'scripts/extract_pdfjs.js';
  final proc = await Process.start('node', [script, file.path], workingDirectory: Directory.current.path);
  final out = StringBuffer();
  final err = StringBuffer();
  await for (final data in proc.stdout.transform(SystemEncoding().decoder)) {
    out.write(data);
  }
  await for (final data in proc.stderr.transform(SystemEncoding().decoder)) {
    err.write(data);
  }
  final exitCode = await proc.exitCode;
  if (exitCode != 0) {
    throw Exception('pdfjs extractor failed: ${err.toString()}');
  }
  return out.toString();
}
