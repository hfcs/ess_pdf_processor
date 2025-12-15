import 'package:universal_html/html.dart' as html;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:ess_pdf_processor/parser/pdfjs_web_extractor.dart';
import 'package:ess_pdf_processor/parser/text_parser.dart';
import 'package:ess_pdf_processor/parser/shooter_list_text_parser.dart';
import 'package:ess_pdf_processor/models/result_row.dart';
import 'package:ess_pdf_processor/scraper/ess_scraper.dart';
import 'package:html/parser.dart' as html_parser;
// Access window properties via dynamic interop instead of `dart:js_util`.

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
  final TextEditingController _baseUrlController = TextEditingController(text: 'https://hkg.as.ipscess.org/portal?match=21');
  // Progress state for web fetch
  int _totalDivisions = 0;
  int _fetchedDivisions = 0;
  String _currentDivisionLabel = '';

  Future<void> _pickAndExtract() async {
    // Enable debug logging for the embedded pdf.js extractor so errors and
    // progress are visible in the browser console. This helps diagnose why
    // "nothing happens" on file load in some environments.
    // Do not force-enable debug mode here. Prefer using the optional
    // `web/debug.js` helper (which sets window.__ESS_DEBUG__ = true) so
    // developers can opt-in to verbose logging in the browser.
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

        try {
          // Log a short preview of the extracted text so devtools can show
          // what pdf.js produced (helps debug parsing mismatches).
          try {
            // Only emit verbose debug logs when the page explicitly enables
            // debug mode (for example via web/debug.js which sets
            // `window.__ESS_DEBUG__ = true`). This avoids noisy console
            // output in normal usage. Access the flag via dynamic interop.
            final debugEnabled = () {
              try {
                final w = html.window as dynamic;
                return w.__ESS_DEBUG__ == true;
              } catch (_) {
                return false;
              }
            }();
            if (debugEnabled) {
              final preview = extracted.length > 400 ? extracted.substring(0, 400) + '...' : extracted;
              html.window.console.log('Demo app: extracted preview: ' + preview);
              html.window.console.log('Demo app: extracted lines=' + extracted.split(RegExp(r"\r?\n")).length.toString());
            }
          } catch (_) {}

          final parsed = parseTextToRows(extracted, defaultDivision: 'UNKNOWN');
          if (parsed.isEmpty) {
            // Make parsing issues visible in the UI so users aren't left wondering
            // why nothing appears after a successful pdf.js extraction.
            setState(() { _lastError = 'No rows parsed from extraction. See console for extracted preview.'; _resultRows = []; });
          } else {
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
            }
            try {
              html.window.console.log('Demo app: parsed rows=' + parsed.length.toString());
            } catch (_) {}
            setState(() {
              _resultRows = parsed;
              _lastError = '';
            });
          }
        } catch (e) {
          // If parseTextToRows itself throws, surface the error into the UI
          setState(() {
            _resultRows = [];
            _lastError = 'Parsing error: $e';
          });
          try { html.window.console.error('Demo app: parsing error: $e'); } catch (_) {}
        }
        // No further action here; parsing and mapping handled above.
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
    // Do not force-enable debug mode here; rely on the optional
    // web/debug.js helper when debugging in the browser.
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

  Future<void> _fetchFromWeb() async {
    final base = _baseUrlController.text.trim();
    if (base.isEmpty) return;
    setState(() {
      _loading = true;
      _lastError = '';
      _resultRows = [];
    });
    try {
      final baseUri = Uri.parse(base);
      // Fetch base page via browser HttpRequest (respects CORS)
      final resp = await html.HttpRequest.request(baseUri.toString(), method: 'GET');
      final doc = html_parser.parse(resp.responseText);
      // find division links like /portal/results/21?division=1
      final anchors = doc.querySelectorAll('a.list-group-item-action[href]');
      final divisionHrefs = <String>{};
      for (final a in anchors) {
        final href = a.attributes['href'];
        if (href == null) continue;
        if (href.contains('/portal/results/')) divisionHrefs.add(href);
      }

      final rows = <ResultRow>[];
      final hrefList = divisionHrefs.toList();
      _totalDivisions = hrefList.length;
      _fetchedDivisions = 0;
      _currentDivisionLabel = '';
      setState(() {});

      for (var i = 0; i < hrefList.length; i++) {
        final href = hrefList[i];
        // polite rate limit
        await Future.delayed(const Duration(seconds: 2));
        final resolved = baseUri.resolve(href).toString();
        final uri = resolved.contains('?') ? (resolved + '&group=stage') : (resolved + '?group=stage');
        _currentDivisionLabel = href;
        setState(() {});

        try {
          final r = await html.HttpRequest.request(uri, method: 'GET');
          final doc2 = html_parser.parse(r.responseText);
          final part = EssScraper.parseDivisionStagesFromDocument(doc2);
          rows.addAll(part);
          _fetchedDivisions = i + 1;
          setState(() {
            _resultRows = List<ResultRow>.from(rows);
          });
        } catch (e) {
          // record failure but continue
          html.window.console.error('Failed to fetch division $uri: $e');
          _fetchedDivisions = i + 1;
          setState(() {});
        }
      }

      // apply shooter-list mapping if present
      for (final r in rows) {
        if (_shooterListMap.containsKey(r.competitorNumber)) {
          final token = _shooterListMap[r.competitorNumber] ?? '';
          r.classification = (token == 'GM' || token.isEmpty) ? 'Overall' : token;
        }
      }

      setState(() {
        _resultRows = rows;
        _lastError = rows.isEmpty ? 'No rows found from web fetch' : '';
        _currentDivisionLabel = '';
        _totalDivisions = 0;
        _fetchedDivisions = 0;
      });
    } catch (e) {
      setState(() {
        _resultRows = [];
        _lastError = 'Web fetch error: $e';
      });
      try { html.window.console.error('Demo app: web fetch error: $e'); } catch (_) {}
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
            // Web fetch controls: base URL input + fetch button
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _baseUrlController,
                    decoration: const InputDecoration(
                      labelText: 'Competition URL',
                      hintText: 'https://hkg.as.ipscess.org/portal?match=21',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _loading ? null : _fetchFromWeb,
                  icon: const Icon(Icons.public),
                  label: const Text('Fetch web results'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Progress indicator for web fetch
            if (_totalDivisions > 0)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(
                    value: _totalDivisions > 0 ? (_fetchedDivisions / _totalDivisions) : null,
                  ),
                  const SizedBox(height: 6),
                  Text('Fetching divisions: ${_fetchedDivisions}/${_totalDivisions} ${_currentDivisionLabel.isNotEmpty ? "— ${_currentDivisionLabel}" : ""}'),
                ],
              ),
            if (_totalDivisions > 0) const SizedBox(height: 8),
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

