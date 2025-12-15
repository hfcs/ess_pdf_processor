import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart';

import 'package:ess_pdf_processor/models/result_row.dart';

class EssScraper {
  final Uri baseUri;
  final Duration rateLimit;
  final Duration timeout;
  final int maxRetries;
  final bool headless;

  EssScraper(
    this.baseUri, {
    this.rateLimit = const Duration(seconds: 2),
    this.timeout = const Duration(seconds: 30),
    this.maxRetries = 3,
    this.headless = false,
  });

  Future<List<ResultRow>> fetchAllStages() async {
    // Fetch the competition root page (e.g. /portal?match=21) to discover divisions
    final resp = await _getWithRetries(baseUri);
    final doc = html_parser.parse(utf8.decode(resp.bodyBytes));

    // Find division links like /portal/results/21?division=1
    final anchors = doc.querySelectorAll('a.list-group-item-action[href]');
    final divisionHrefs = <String>{};
    for (final a in anchors) {
      final href = a.attributes['href'];
      if (href == null) continue;
      if (href.contains('/portal/results/')) divisionHrefs.add(href);
    }

    final rows = <ResultRow>[];
    for (final href in divisionHrefs) {
      // Respect rate limit
      await Future.delayed(rateLimit);
      final uri = baseUri.resolve(href.contains('?') ? ('$href&group=stage') : href);
      try {
        final part = await _fetchDivisionStages(uri);
        rows.addAll(part);
      } catch (e) {
        // continue on errors but report
        print('Warning: failed to fetch $uri: $e');
      }
    }

    return rows;
  }

  Future<List<ResultRow>> _fetchDivisionStages(Uri uri) async {
    // If headless requested, a headless fetch can be implemented here.
    // Currently we still attempt normal HTTP fetch; headless is left as
    // an opt-in hookup for a future implementation.
    final resp = await _getWithRetries(uri);
    final doc = html_parser.parse(utf8.decode(resp.bodyBytes));
    return parseDivisionStagesFromDocument(doc);
  }

  // Exposed for unit testing: parse a Document into ResultRows
  static List<ResultRow> parseDivisionStagesFromDocument(Document doc) {
    final results = <ResultRow>[];
    final headings = doc.querySelectorAll('h3');
    for (final h in headings) {
      final headingText = h.text.trim();
      final parts = headingText.split('-').map((s) => s.trim()).toList();
      String division = parts.isNotEmpty ? parts[0] : '';
      String stage = parts.length > 1 ? parts[1] : '';

      Element? table;
      Element? e = h.nextElementSibling;
      while (e != null) {
        if (e.localName == 'table') {
          table = e;
          break;
        }
        e = e.nextElementSibling;
      }
      if (table == null) continue;

      final trs = table.querySelectorAll('tbody tr');
      for (final tr in trs) {
        final tds = tr.querySelectorAll('td');
        if (tds.length < 3) continue; // minimal
        try {
          final competitorNumber = int.tryParse(tds[1].text.trim()) ?? 0;
          final competitorName = tds[2].text.trim();
          final classification = tds.length > 4 ? tds[4].text.trim() : '';
          double parseDouble(String s) => double.tryParse(s.trim().replaceAll(',', '')) ?? 0.0;

          if (tds.length >= 12) {
            final pointsCol = tds[7].text;
            final timeCol = tds[8].text;
            final hfCol = tds[9].text;
            final totalCol = tds[10].text;
            final pctCol = tds[11].text;
            final sp = parseDouble(pointsCol);
            final time = parseDouble(timeCol);
            final hitFactor = parseDouble(hfCol);
            final totalScore = parseDouble(totalCol);
            final scorePct = parseDouble(pctCol);
            results.add(ResultRow(
              competitorNumber: competitorNumber,
              competitorName: competitorName,
              classification: classification,
              stage: stage,
              division: division,
              points: totalScore,
              time: time,
              hitFactor: hitFactor,
              stagePoints: sp,
              stagePercentage: scorePct,
            ));
          } else {
            final totalCol = tds.last.text;
            final totalScore = parseDouble(totalCol);
            results.add(ResultRow(
              competitorNumber: competitorNumber,
              competitorName: competitorName,
              classification: classification,
              stage: stage,
              division: division,
              points: totalScore,
              time: 0.0,
              hitFactor: 0.0,
              stagePoints: 0.0,
              stagePercentage: 0.0,
            ));
          }
        } catch (_) {
          continue;
        }
      }
    }
    return results;
  }

  Future<http.Response> _getWithRetries(Uri uri) async {
    int attempt = 0;
    while (true) {
      attempt++;
      try {
        final resp = await http.get(uri).timeout(timeout);
        if (resp.statusCode >= 500 && attempt <= maxRetries) {
          final backoff = Duration(milliseconds: 500 * (1 << (attempt - 1)));
          await Future.delayed(backoff);
          continue;
        }
        if (resp.statusCode != 200) throw Exception('Failed to fetch $uri (${resp.statusCode})');
        return resp;
      } catch (e) {
        if (attempt >= maxRetries) rethrow;
        final backoff = Duration(milliseconds: 500 * (1 << (attempt - 1)));
        await Future.delayed(backoff);
      }
    }
  }
}
