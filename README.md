# ess_pdf_processor
Small toolkit and parser patterns for extracting IPSC "ESS" (Electronic Scoring System) PDF results into a consolidated CSV for analytics.

Sample PDF
 - `test/sample_data/Bangbangcup_2025_rd2.pdf` is included as a representative example used during development.

Parsing notes (from the sample PDF)
 - Tables are grouped by division (e.g., `STANDARD`, `OPEN`, `PRODUCTION`) and stage. Headers repeat on each page and tables can span multiple pages.
 - Canonical row fields (left→right): ranking, PTS, TIME, HIT FACTOR, STAGE POINTS, STAGE PERCENT, competitor #, competitor name.
 - Numeric formats observed with range annotated:
	 - PTS (Stage points): integer. Range: 0 - 160 points
	 - TIME: decimal with 2 fractional digits (XX.XX). Range: 0 - 3600 seconds
	 - HIT FACTOR: decimal with 4 fractional digits (XX.XXXX). Range 0 - 100.0000
	 - STAGE POINTS: decimal with 4 fractional digits (XX.XXXX). Range 0 - 160 points
	 - STAGE PERCENT: decimal with 2 fractional digits (XX.XX). Range 0 - 100.00

Quick extraction (layout-preserving)
1. Use `pdftotext -layout` to get a text version that preserves column spacing. This is the fastest route for a first-pass parser.

2. A robust row regex for layout-preserved text (tweak spacing if necessary):

```
^\s*(\d+)\s+(\d+)\s+(\d+(?:\.\d{1,2})?)\s+(\d+\.\d{4})\s+(\d+\.\d{4})\s+(\d+\.\d{1,2})\s+(\d+)\s+(.+?)\s*$
```

Fields captured: ranking, pts, time, hit_factor, stage_points, stage_percentage, competitor_number, competitor_name

Next steps
 - Implement a parser that either (A) consumes `pdftotext -layout` output using the regex above, or (B) uses coordinate-based extraction from a Dart PDF library for higher robustness (recommended for wrapped names and inconsistent spacing).

If you'd like, I can scaffold a pure-Dart parser or a Flutter app (file picker + drag/drop + preview + CSV export). Tell me which you prefer and I'll generate the initial project files.
