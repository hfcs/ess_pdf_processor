# AI Coding Agent Instructions - ess_pdf_processor

High-value guidance for working on the ESS PDF processor (current state: features, tests and CI added).

## What's changed (current state)
- The CSV now includes a `class` column immediately after `competitor_name`.
- A web-safe, shared shooter-list text parser was added: `lib/parser/shooter_list_text_parser.dart`.
  - This function `parseShooterListFromText(String)` is reused by the CLI. The CLI still supports loading a shooter-list PDF via its `--shooter-list` option and will apply the mapping (competitor number → class) to parsed rows.
  - Note: the Flutter example app (`web_app`) no longer supports uploading PDFs. It now provides a client-side HTML fetcher that requests public ESS results pages, parses stage tables from the returned HTML, and exports consolidated CSV matching the project's `ResultRow` schema.
- Unit tests were added for the shooter-list text parser: `test/shooter_list_text_parser_test.dart`.
- CI additions:
  - `shooter_list_tests` job runs the parser unit tests.
  - A `deploy_web` job builds the Flutter web app and deploys to Firebase Hosting using the Firebase GitHub Action (expects `FIREBASE_SERVICE_ACCOUNT` secret).
- A top-level helper script `build_example_web.sh` was added so maintainers can run a single command from repo root to build the nested Flutter example.

## Quick developer notes (how to work with changes)

- Parsing heuristics and results format
  - The shared parser extracts competitor-number → raw class token (one of C,B,A,M,GM or blank).
  - The CLI (`bin/run.dart`) supports an optional `--shooter-list <file.pdf>` parameter; when supplied the CLI will parse the shooter-list (preferring `pdftotext` then pdf.js) and apply classification to rows by competitor number.
  - The `ResultRow` model includes `classification` and the CSV header contains `class`.

- Running locally
  - Run unit tests:
    dart test -r expanded
  - Build the Flutter web app from the repository root:
    chmod +x ./build_example_web.sh
    ./build_example_web.sh
    (this will cd into `web_app` and run `flutter build web --release`)

- CI / Deployment
  - The workflow uses `FirebaseExtended/action-hosting-deploy@v0` and expects a repository secret named `FIREBASE_SERVICE_ACCOUNT_ESS_WEB_EXTRACTOR` containing the service account JSON for deployment.
  - To enable automatic deploys: create a Firebase service account with Hosting permissions, add its JSON as the `FIREBASE_SERVICE_ACCOUNT_ESS_WEB_EXTRACTOR` secret in repository Settings → Secrets & variables → Actions.

## Architecture & Data Flow (summary)
- Input: `TableBlock(stage, division, rows: List<Map<String,String?>>)` — normalized cell keys (lowercase, trimmed, collapsed spaces).
- Output: `ResultRow` with columns: `competitor_number, competitor_name, class, stage, division, points, time, hit_factor, stage_points, stage_percentage`.
- Pipeline: extractor → text parser → TableBlock(s) → consolidate → ResultRow list → CSV export.

## Parsing heuristics (reminder)
- The original text-layout regex still applies for pdftotext-extracted text but the shared parser normalizes common variations and extracts the class token heuristically near line ends. Prefer `pdftotext -layout` for CLI processing when available; the pdf.js route is used as a fallback or in-browser.

## Tests and quality
- Unit tests for parser: `test/shooter_list_text_parser_test.dart`.
- Integration parity tests remain in `test/` to compare pdftotext vs pdf.js outputs.

If you want, I can:
- Add more fixtures from real shooter-list PDFs to `test/fixtures/` and extend unit tests.
- Add a CI preview deploy (preview channel) instead of production deploys for PRs.
- Migrate `lib/parser/pdfjs_web_extractor.dart` away from deprecated `dart:js_util` toward `dart:js_interop` to silence analyzer infos and improve Wasm compatibility.
