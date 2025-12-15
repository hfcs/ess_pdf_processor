import 'package:universal_html/html.dart' as html;


import 'package:flutter/material.dart';

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
  String _lastError = '';
  final TextEditingController _baseUrlController = TextEditingController(text: 'https://hkg.as.ipscess.org/portal?match=21');
  // Progress state for web fetch
  int _totalDivisions = 0;
  int _fetchedDivisions = 0;
  String _currentDivisionLabel = '';

  

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

      // No PDF-based shooter-list mapping in web-only mode.

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
            const SizedBox(height: 0),
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
            const SizedBox(height: 0),
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

