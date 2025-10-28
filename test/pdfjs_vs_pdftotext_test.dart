import 'dart:io';
import 'package:test/test.dart';

void main() {
  test('pdfjs vs pdftotext extraction parity', () async {
    final pdf = 'test/sample_data/Bangbangcup_2025_rd2.pdf';
    final outPdftotext = 'out/results_poc_test.csv';
    final outPdfjs = 'out/results_pdfjs_test.csv';

    // Run pdftotext path
    var pr = await Process.run('dart', ['run', 'bin/run.dart', pdf, outPdftotext]);
    if (pr.exitCode != 0) {
      fail('pdftotext-run failed: ${pr.stdout}\n${pr.stderr}');
    }

    // Run pdfjs path
    pr = await Process.run('dart', ['run', 'bin/run.dart', pdf, outPdfjs, '--pdfjs']);
    if (pr.exitCode != 0) {
      fail('pdfjs-run failed: ${pr.stdout}\n${pr.stderr}');
    }

    final p1 = File(outPdftotext);
    final p2 = File(outPdfjs);
    expect(await p1.exists(), isTrue);
    expect(await p2.exists(), isTrue);

    final lines1 = await p1.readAsLines();
    final lines2 = await p2.readAsLines();

    // both should have same row count
    expect(lines1.length, lines2.length,
        reason: 'pdftotext rows=${lines1.length}, pdfjs rows=${lines2.length}');
  }, timeout: Timeout(Duration(seconds: 120)));
}
