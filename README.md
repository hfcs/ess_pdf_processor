# ess_pdf_processor
Small toolkit and parser patterns for extracting IPSC "ESS" (Electronic Scoring System) PDF results into a consolidated CSV for analytics.

## PDF extraction options (Node / Browser)

This project supports two robust PDF→text extraction routes that decode embedded fonts and provide text coordinates:

- Node/pdf.js (recommended for server/CLI): uses `pdfjs-dist` via Node to extract text content with coordinates. Useful for CI and local scripts; the repo includes `scripts/extract_pdfjs.js` and `scripts/package.json` (run `cd scripts && npm install`). The CLI runner supports `--pdfjs` to prefer this path: `dart run bin/run.dart input.pdf out.csv --pdfjs`.
- Browser (recommended for Flutter web client): use PDF.js in the browser to extract `getTextContent()` per page (text items include transform matrices). We provide a small web helper (`web/pdf_extract.js`) and a Dart JS-interop wrapper (`lib/parser/pdfjs_web_extractor.dart`) so a Flutter web app can extract text client-side without uploading PDFs.

Notes and recommendations:
- For most users wanting a web-first experience, use the browser-side PDF.js extractor (privacy-preserving — files never leave the user's machine) and then parse coordinates into rows in Dart.
- For CLI or CI usage, `pdftotext` (system) and Node/pdf.js are both valid options; the CLI prefers `pdftotext` when available, and falls back to the Node/pdf.js path if `--pdfjs` is passed.
 - For CLI or CI usage, `pdftotext` (system) and Node/pdf.js are both valid options; the CLI prefers `pdftotext` when available, and falls back to the Node/pdf.js path if `--pdfjs` is passed.

Testing & forcing the heuristic fallback
--------------------------------------

The parser prefers `pdftotext` when available, but there is a robust heuristic fallback that extracts tokens from PDF content streams. For testing and for environments that don't have `pdftotext`, you can force the heuristic fallback in two ways:

- Programmatic (tests): `PdfDartParser.parse(..., forceFallback: true)` — this named parameter skips calling `pdftotext` and directly runs the heuristic extraction. The test suite uses this flag to exercise fallback logic without relying on system binaries.
- CLI: pass `--force-fallback` to the CLI to skip the `pdftotext` path and use the heuristic extraction when running the `bin/run.dart` tool. Example:

```bash
dart run bin/run.dart input.pdf out.csv --force-fallback
```

We added a unit test (`test/pdf_dart_parser_force_flag_test.dart`) demonstrating forcing the fallback while also mocking a successful `pdftotext` runner to ensure the flag is respected.

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

## CI: running parity tests headlessly

This repository includes a parity test that compares text extraction between the system `pdftotext` route and the `pdf.js` (Node) route. The project provides a GitHub Actions workflow to run these tests in a headless CI environment (see `.github/workflows/ci.yml`).

What the CI does
- Installs Node and Dart on the runner
- Installs Node dependencies in `scripts/` (pdfjs-dist)
- Installs `poppler-utils` (provides `pdftotext`) on the Ubuntu runner
- Runs `dart pub get` and then `dart test` which runs the parity tests

Local headless test (recommended steps)

1. Install Node (v18+ recommended) and npm, and ensure `flutter`/`dart` are on your PATH.
2. From repo root, install Node deps used by the Node/pdf.js extractor:

```bash
cd scripts
npm ci
cd -
```

3. Ensure `pdftotext` is available for the pdftotext extraction path. On macOS with Homebrew:

```bash
brew install poppler
```

4. Get Dart packages and run tests:

```bash
dart pub get
dart test
### Troubleshooting

If you run `flutter build web --release` from the repository root without changing directory, Flutter will look for a `lib/main.dart` in the current directory and fail with an error like:

```
Target file "lib/main.dart" not found. Please fix it
```

Why this happens: `flutter` expects to be run from inside a Flutter project directory (a folder containing `pubspec.yaml` and `lib/main.dart`). The repository root is not the Flutter project's root — the web app is nested in `web_app`.

How to fix it (pick one):

- Use the provided wrapper (recommended):

```bash
chmod +x ./build_example_web.sh
./build_example_web.sh
```


- Change into the Flutter example directory and run the build there:

```bash
cd web_app
flutter pub get
flutter build web --release
```


- Or run Flutter while telling it to change directory first (single command):

```bash
flutter -C web_app build web --release
```

All three options build the same Flutter web project (`web_app`) and will create `web_app/build/web` as output.
```

If you don't have `pdftotext` available locally, the tests still pass when run with the `--pdfjs` flag (the Node/pdf.js extractor) — see the CI workflow for how the runner installs `poppler-utils`.

## Flutter web app (example)


There is a small Flutter web app under `web_app` that demonstrates a file picker and uses the browser `pdf.js` extractor (the helper `web/pdf_extract.js` included in this repo) to extract text lines from a client-selected PDF. It's intentionally minimal and meant to be used as a starting point for integrating the extractor into a Flutter web UI.

To run the demo:

```bash
# from repo root
cd web_app
flutter pub get
flutter run -d chrome
```

Notes:
- The demo's `web/index.html` references the repo's `web/pdf_extract.js` and a CDN copy of `pdf.js`. For production you should bundle `pdfjs-dist` assets with your app or host them in a controlled location.

- The demo shows the extracted lines in a simple list and is useful for verifying that `extractPdfArrayBuffer` is callable from Dart/Flutter web via JS interop.

- Debugging the web app: the Flutter web app supports an optional local debug toggle (`window.__ESS_DEBUG__`) and a helper script in `web_app/scripts/generate_debug_js.sh` to quickly create `web/debug.js` which enables verbose logs in DevTools. See `web_app/README.md` for details.


## Building & Deploying the Flutter web app (root build)

We build the Flutter web app from the repository root so CI and local workflows use a consistent path.

Build (from repo root):

```bash
chmod +x ./build_example_web.sh
./build_example_web.sh
```

This wrapper will cd into `web_app` and run `flutter build web --release`. The produced web artifact will be placed in:

```
web_app/build/web
```

CI / Deploy notes

-- This repository now contains a root-level `firebase.json` that points `hosting.public` to `web_app/build/web`. The GitHub Actions deploy job uses the Firebase Hosting GitHub Action.
- To enable automatic deployments from CI you must add a repository secret named `FIREBASE_SERVICE_ACCOUNT` containing the Firebase service account JSON (the service account needs Hosting deploy permissions). See repository Settings → Secrets & variables → Actions.

Deploy locally (manual steps)

```bash
# build the web artifact
./build_example_web.sh

# login with firebase CLI (one-time)
npm install -g firebase-tools
firebase login

# deploy to hosting
firebase deploy --only hosting --project ess-pdf-processor
```

If you'd rather have CI produce preview deploys for PRs instead of deploying to production on main, I can update the workflow to use preview channels or to only deploy on tags.

