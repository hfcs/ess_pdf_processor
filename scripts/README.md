# Coverage filtering helper

This repository includes a small helper script to exclude a short range of
lines from the LCOV coverage report. Those lines are defensive parsing code
that handle extremely malformed, hand-edited PDF text. In practice they are
not produced by machine-generated PDFs and are intentionally excluded from
CI coverage so the reported metrics better reflect the testable surface.

Files
- `scripts/filter_lcov.sh` — filters `coverage/lcov.info` and writes
  `coverage/lcov.filtered.info` (removes `lib/parser/text_parser.dart` lines
  83–107 by default).

Regenerating filtered coverage (Linux / CI)

1. Run tests and collect VM coverage:

```bash
dart test --coverage=coverage
```

2. Install the coverage formatter and convert to LCOV:

```bash
dart pub global activate coverage
dart pub global run coverage:format_coverage \
  --lcov --in=coverage --out=coverage/lcov.info --packages=.packages --report-on=lib
```

3. Filter the LCOV and generate HTML (requires `genhtml` from `lcov`):

```bash
./scripts/filter_lcov.sh coverage/lcov.info coverage/lcov.filtered.info
sudo apt-get update && sudo apt-get install -y lcov
genhtml -o coverage/html_filtered coverage/lcov.filtered.info
```

On macOS you can install `lcov` using Homebrew:

```bash
brew install lcov
```

CI Integration

The GitHub Actions workflow `ci.yml` now runs these steps and uploads
`coverage/html_filtered` as an artifact named `coverage-html` so PRs and
maintainers can inspect the filtered HTML coverage report.

If you want the filter to remove a different file or line range, edit
`scripts/filter_lcov.sh` and adjust `TARGET_PATH`, `START_LINE`, and
`END_LINE` accordingly.
