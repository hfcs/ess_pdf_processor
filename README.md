# ess_pdf_processor
Small toolkit and parser patterns for extracting IPSC "ESS" (Electronic Scoring System) PDF results into a consolidated CSV for analytics.

## PDF extraction options (Node / Browser)

This project supports two robust PDF→text extraction routes that decode embedded fonts and provide text coordinates:

- Node/pdf.js (recommended for server/CLI): uses `pdfjs-dist` via Node to extract text content with coordinates. Useful for CI and local scripts; the repo includes `scripts/extract_pdfjs.js` and `scripts/package.json` (run `cd scripts && npm install`). The CLI runner supports `--pdfjs` to prefer this path: `dart run bin/run.dart input.pdf out.csv --pdfjs`.
- Browser (recommended for Flutter web client): use PDF.js in the browser to extract `getTextContent()` per page (text items include transform matrices). We provide a small web helper (`web/pdf_extract.js`) and a Dart JS-interop wrapper (`lib/parser/pdfjs_web_extractor.dart`) so a Flutter web app can extract text client-side without uploading PDFs.

Notes and recommendations:
- For most users wanting a web-first experience, use the browser-side PDF.js extractor (privacy-preserving — files never leave the user's machine) and then parse coordinates into rows in Dart.
- For CLI or CI usage, `pdftotext` (system) and Node/pdf.js are both valid options; the CLI prefers `pdftotext` when available, and falls back to the Node/pdf.js path if `--pdfjs` is passed.

See the `web/` folder and `scripts/` for example extractors and the `test/pdfjs_vs_pdftotext_test.dart` parity test.


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
