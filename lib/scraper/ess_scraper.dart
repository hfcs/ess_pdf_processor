import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart';

import 'package:ess_pdf_processor/models/result_row.dart';

class EssScraper {
  final Uri baseUri;
  final Duration rateLimit;

  EssScraper(this.baseUri, {this.rateLimit = const Duration(seconds: 2)});

  Future<List<ResultRow>> fetchAllStages() async {
    // Fetch the competition root page (e.g. /portal?match=21) to discover divisions
    final resp = await http.get(baseUri);
    if (resp.statusCode != 200) throw Exception('Failed to fetch ${baseUri} (${resp.statusCode})');
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
    final resp = await http.get(uri);
    if (resp.statusCode != 200) throw Exception('Failed to fetch $uri (${resp.statusCode})');
    final doc = html_parser.parse(utf8.decode(resp.bodyBytes));

    final results = <ResultRow>[];

    // Find all headings (h3) and the following table
    final headings = doc.querySelectorAll('h3');
    for (final h in headings) {
      final headingText = h.text.trim();
      // Expect formats like "Open - Stage 01" or "<Division> - Stage NN"
      final parts = headingText.split('-').map((s) => s.trim()).toList();
      String division = parts.isNotEmpty ? parts[0] : '';
      String stage = parts.length > 1 ? parts[1] : '';

      // Next sibling table
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
        if (tds.length < 8) continue; // unexpected
        try {
          final competitorNumber = int.tryParse(tds[1].text.trim()) ?? 0;
          final competitorName = tds[2].text.trim();
          final classification = tds.length > 4 ? tds[4].text.trim() : '';
          // Stage points, time, hit factor, total score, score % appear near the end
          double parseDouble(String s) => double.tryParse(s.trim().replaceAll(',', '')) ?? 0.0;
          final stagePoints = parseDouble(tds[7].text);
          double time = 0.0;
          double hitFactor = 0.0;
          double totalScore = 0.0;
          double scorePct = 0.0;
          // Some pages have Points, Time, Hit Factor, Total Score, Score % ordering
          if (tds.length >= 12) {
            // columns: Place, #, Shooter, Category, Class, Factor, Region, Points, Time, Hit Factor, Total Score, Score %
            final pointsCol = tds[7].text;
            final timeCol = tds[8].text;
            final hfCol = tds[9].text;
            final totalCol = tds[10].text;
            final pctCol = tds[11].text;
            final sp = parseDouble(pointsCol);
            time = parseDouble(timeCol);
            hitFactor = parseDouble(hfCol);
            totalScore = parseDouble(totalCol);
            scorePct = parseDouble(pctCol);
            // Use totalScore as `points` and sp as stagePoints
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
            // Fallback mapping: try to map what we can
            final totalCol = tds.last.text;
            totalScore = parseDouble(totalCol);
            results.add(ResultRow(
              competitorNumber: competitorNumber,
              competitorName: competitorName,
              classification: classification,
              stage: stage,
              division: division,
              points: totalScore,
              time: 0.0,
              hitFactor: 0.0,
              stagePoints: stagePoints.toDouble(),
              stagePercentage: 0.0,
            ));
          }
        } catch (e) {
          // ignore row parse errors
          continue;
        }
      }
    }

    return results;
  }
}
