import 'package:universal_html/html.dart' as html;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:ess_pdf_processor/parser/pdfjs_web_extractor.dart';
import 'package:ess_pdf_processor/parser/text_parser.dart';
import 'package:ess_pdf_processor/parser/shooter_list_text_parser.dart';
import 'package:ess_pdf_processor/models/result_row.dart';
import 'dart:js_util' as jsu;

void main() {
  runApp(const DemoApp());
}

class DemoApp extends StatelessWidget {
  const DemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ESS PDF to CSV converter',
      home: const DemoHome(),
    );
  }
}

class DemoHome extends StatefulWidget {
  const DemoHome({super.key});

  @override
  State<DemoHome> createState() => _DemoHomeState();
}

class _DemoHomeState extends State<DemoHome> {
  List<ResultRow> _resultRows = [];
  bool _loading = false;
  Map<int, String> _shooterListMap = {};
  String _lastError = '';

  Future<void> _pickAndExtract() async {
    // Enable debug logging for the embedded pdf.js extractor so errors and
    // progress are visible in the browser console. This helps diagnose why
    // "nothing happens" on file load in some environments.
    try {
      jsu.setProperty(html.window, '__ESS_DEBUG__', true);
    } catch (_) {}
    final input = html.FileUploadInputElement();
    input.accept = '.pdf';
    input.click();

    await input.onChange.first;
    final files = input.files;
    if (files == null || files.isEmpty) return;
    final file = files.first;

    final reader = html.FileReader();
    reader.readAsArrayBuffer(file);
    setState(() => _loading = true);

    // Wait for load or error; avoid waiting forever if the reader fails.
    try {
      final loadOrError = await Future.any([
        reader.onLoad.first.then((_) => true),
        reader.onError.first.then((_) => throw Exception('FileReader error while reading file')),
      ]);

      if (loadOrError != true) throw Exception('Failed to read file');

      final result = reader.result;
      // FileReader.result can be a ByteBuffer or a Uint8List depending on
      // the browser/runtime. Handle both to avoid type errors on web builds.
      Uint8List bytes;
      if (result is ByteBuffer) {
        bytes = result.asUint8List();
      } else if (result is Uint8List) {
        bytes = result;
      } else if (result is List) {
        // Some environments may produce a JS List of ints.
        bytes = Uint8List.fromList(List<int>.from(result));
      } else {
        throw Exception('Unsupported FileReader.result type: ${result.runtimeType}');
      }

        try {
          // Add a timeout around the JS/pdf.js extraction so the UI doesn't hang
          // if the promise never resolves for some reason (network blocked, pdf.js error).
          final extracted = await extractWithPdfJsWeb(bytes).timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw Exception('PDF extraction timed out (30s) - check console for pdf.js errors'),
          );

        final parsed = parseTextToRows(extracted, defaultDivision: 'UNKNOWN');
        // Apply shooter-list mapping only when we have an explicit mapping
        for (final r in parsed) {
          if (_shooterListMap.containsKey(r.competitorNumber)) {
            final token = _shooterListMap[r.competitorNumber] ?? '';
            if (token == 'GM' || token.isEmpty) {
              r.classification = 'Overall';
            } else {
              r.classification = token;
            }
          }
          // If we don't have an entry for this competitor, leave the
          // classification as-is (so loading a shooter-list later won't
          // incorrectly overwrite it with 'Overall').
        }
        setState(() => _resultRows = parsed);
        } catch (e) {
          setState(() {
            _resultRows = [];
            _lastError = 'Extraction error: $e';
          });
          try { html.window.console.error('Demo app: extraction error: $e'); } catch (_) {}
        }
    } catch (e) {
      // File read failed or timed out
      setState(() {
        _resultRows = [];
        _lastError = 'File read error: $e';
      });
      try { html.window.console.error('Demo app: file read error: $e'); } catch (_) {}
    } finally {
      setState(() => _loading = false);
    }
  }

  void _exportCsv() {
    if (_resultRows.isEmpty) return;
    final buffer = StringBuffer();
    buffer.writeln(ResultRow.csvHeader().join(','));
    for (final r in _resultRows) {
      buffer.writeln(r.toCsvRow().join(','));
    }
    final blob = html.Blob([buffer.toString()], 'text/csv');
    final url = html.Url.createObjectUrlFromBlob(blob);
    // Create an anchor and click it to trigger download. Keep this inline
    // to avoid an unused-local-variable analyzer warning.
    html.AnchorElement(href: url)
      ..setAttribute('download', 'extracted_rows.csv')
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  Future<void> _pickAndLoadShooterList() async {
    try {
      jsu.setProperty(html.window, '__ESS_DEBUG__', true);
    } catch (_) {}
    final input = html.FileUploadInputElement();
    input.accept = '.pdf';
    input.click();

    await input.onChange.first;
    final files = input.files;
    if (files == null || files.isEmpty) return;
    final file = files.first;

    final reader = html.FileReader();
    reader.readAsArrayBuffer(file);
    setState(() => _loading = true);

    try {
      final loadOrError = await Future.any([
        reader.onLoad.first.then((_) => true),
        reader.onError.first.then((_) => throw Exception('FileReader error while reading shooter-list file')),
      ]);

      if (loadOrError != true) throw Exception('Failed to read shooter-list file');

      final result = reader.result;
      Uint8List bytes;
      if (result is ByteBuffer) {
        bytes = result.asUint8List();
      } else if (result is Uint8List) {
        bytes = result;
      } else if (result is List) {
        bytes = Uint8List.fromList(List<int>.from(result));
      } else {
        throw Exception('Unsupported FileReader.result type: ${result.runtimeType}');
      }

      try {
        final extracted = await extractWithPdfJsWeb(bytes).timeout(
          const Duration(seconds: 30),
          onTimeout: () => throw Exception('PDF extraction timed out (30s) - check console for pdf.js errors'),
        );

        final map = parseShooterListFromText(extracted);
        // Update shooter-list map and apply to any already-loaded results.
        setState(() {
          _shooterListMap = map;
          _lastError = '';
          // Apply mapping to already-loaded rows when we have explicit entries
          for (final r in _resultRows) {
            if (_shooterListMap.containsKey(r.competitorNumber)) {
              final token = _shooterListMap[r.competitorNumber] ?? '';
              if (token == 'GM' || token.isEmpty) {
                r.classification = 'Overall';
              } else {
                r.classification = token;
              }
            }
          }
        });
      } catch (e) {
        setState(() {
          _shooterListMap = {};
          _lastError = 'Shooter-list extraction error: $e';
        });
        try { html.window.console.error('Demo app: shooter-list extraction error: $e'); } catch (_) {}
      }
    } catch (e) {
      setState(() => _shooterListMap = {});
      try { html.window.console.error('Demo app: shooter-list file read error: $e'); } catch (_) {}
    } finally {
      setState(() => _loading = false);
    }
  }

  // Use the shared, web-safe shooter-list text parser.
  // parseShooterListFromText is imported from
  // `package:ess_pdf_processor/parser/shooter_list_text_parser.dart`.

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ESS PDF to CSV converter')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : _pickAndExtract,
                    icon: const Icon(Icons.upload_file),
                    label: Text(_loading ? 'Loading…' : 'Pick ESS stage result PDF'),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _loading ? null : _pickAndLoadShooterList,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Pick shooter-list PDF'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Shooter-list load indicator
            Row(
              children: _shooterListMap.isNotEmpty
                  ? [
                      const Icon(Icons.check_circle, color: Colors.green, size: 18),
                      const SizedBox(width: 6),
                      Text('Shooter list loaded: ${_shooterListMap.length} entries',
                          key: const Key('shooter_list_loaded')),
                    ]
                  : [
                      const Icon(Icons.info_outline, color: Colors.grey, size: 18),
                      const SizedBox(width: 6),
                      const Text(
                        'No shooter list loaded — class column for competitors will be blank',
                        key: Key('shooter_list_none'),
                      ),
                    ],
            ),
            const SizedBox(height: 8),
            // Show last error (if any) so users see problems in the UI.
            if (_lastError.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                child: Text(_lastError, style: TextStyle(color: Colors.red.shade700)),
              ),
            ElevatedButton.icon(
              onPressed: _resultRows.isEmpty ? null : _exportCsv,
              icon: const Icon(Icons.download),
              label: const Text('Export CSV'),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: _resultRows.isEmpty
                    ? const Center(child: Text('No extracted rows yet'))
                    : ListView.builder(
                        itemCount: _resultRows.length,
                        itemBuilder: (context, i) {
                          final r = _resultRows[i];
                          return Text('${r.competitorNumber} | ${r.competitorName} | ${r.classification} | ${r.division} | Stage ${r.stage} | ${r.points.toStringAsFixed(2)} pts');
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

