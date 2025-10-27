# AI Coding Agent Instructions - ess_pdf_processor

Short, high-value guidance for AI coding agents working on this IPSC Electronic Scoring System PDF processor.

## Project Overview
Flutter/Dart application that extracts IPSC Electronic Scoring System PDF results into normalized tabular data for analytics. Transforms per-stage/division tables into consolidated CSV exports.

## Architecture & Data Flow
### Core Models
- **Input**: `TableBlock(stage, division, rows: List<Map<String,String?>>)`
  - Normalized cell keys: lowercase, trimmed, spaces collapsed
  - Required keys: `ranking`, `points`, `time`, `hit_factor`, `stage_points`, `stage_percentage`, `competitor_number`, `competitor_name`
- **Output**: `ResultRow` reflecting CSV export format
  - Column order: `competitor number`, `competitor name`, `stage`, `division`, `points`, `time`, `hit factor`, `stage points`, `stage percentage`

### Processing Pipeline
1. PDF extractor → `List<TableBlock>` (one per stage+division combination)
2. `ResultProcessor.consolidate(blocks)` → `List<ResultRow>`
   - Drops `ranking` field (per-division rankings irrelevant in consolidated output)
   - Adds `stage` and `division` fields from TableBlock metadata
3. Export `List<ResultRow>` to CSV

## Development Setup
- **Platform**: Flutter/Dart targeting web, desktop, and mobile
- **PDF Parsing**: Use `pdf` package (pure Dart, client-side) - best cross-platform support for table extraction
- **File Handling**: `file_picker` for all platforms, `desktop_drop` for drag-and-drop on desktop/web
- **CSV Export**: `csv` package for data serialization

### Recommended Dependencies
```yaml
dependencies:
  pdf: ^3.10.7          # Pure Dart PDF parsing
  file_picker: ^6.1.1   # Cross-platform file selection
  desktop_drop: ^1.4.0  # Drag-and-drop support
  csv: ^5.0.2           # CSV export functionality
```

## Platform-Specific UI Patterns
- **File Input**: Primary UI shows file picker button, secondary drag-and-drop zone (desktop/web only)
- **Error Handling**: Toast/snackbar notifications for malformed PDFs with clear user messaging
- **Responsive Design**: Adapt layout for mobile (single column) vs desktop (side-by-side panels)

## Key Patterns
- **Data normalization**: Always normalize table cell keys (lowercase, trim, collapse spaces) before processing
- **Field consolidation**: Remove ranking during consolidation as it's division-specific, not globally relevant
- **Error handling**: For malformed PDFs, display user-friendly error messages (e.g., "Unable to parse PDF - file may be corrupted or not an IPSC ESS report")
- **PDF table detection**: Use `pdf` package's text positioning to identify table structures by coordinate analysis

## File Structure Expectations
- `/lib/models/` - TableBlock, ResultRow data classes
- `/lib/processors/` - PDF extraction and result consolidation logic
- `/lib/exporters/` - CSV export functionality  
- `/lib/ui/` - Cross-platform UI components (file picker, drag-drop, results display)
- `/lib/services/` - Platform-specific file handling services
- `/test/` - Unit tests for data transformation pipeline

## Development Workflow
1. **PDF Processing**: Use `pdf.PdfDocument.openData()` for client-side parsing
2. **Table Extraction**: Parse text elements by coordinates to reconstruct table structure
3. **File Handling**: Implement platform detection for drag-drop capability
4. **Error States**: Catch `PdfException` and display user-friendly error messages
5. **Testing**: Include sample IPSC ESS PDFs in `/test/fixtures/` for validation

## Sample PDF analysis (Bangbangcup_2025_rd2.pdf)
This project includes a representative IPSC ESS PDF: `test/sample_data/Bangbangcup_2025_rd2.pdf`.
I extracted the PDF with `pdftotext -layout` and observed the following consistent structure you can rely on when writing parsers:

- Section / division headings
  - Format: `<<DIVISION>> -- Overall Stage Results` (e.g. `STANDARD -- Overall Stage Results`)
  - Immediately followed by the event title and `Stage N -- Stage N` header.

- Column header (two visual rows in the PDF; layout-preserving extraction produces a single header block):
  - Logical columns (left→right): `ranking`, `PTS`, `TIME`, `FACTOR` (hit factor), `POINTS` (stage points), `PERCENT` (stage percentage), `#` (competitor number), `Name`
  - Example header text found in the file:
    `PTS     TIME     FACTOR      POINTS     PERCENT      # Name`

- Row format (layout-preserved plain text)
  - Example extracted row:
    `1    71       8.27      8.5852    75.0000      100.00   118   Wan, Chun Yin`
  - Field types and typical formatting:
    - ranking: integer
    - PTS: integer (no decimals)
    - TIME: decimal with 2 fractional digits (XX.XX)
    - HIT FACTOR: decimal with 4 fractional digits (XX.XXXX)
    - STAGE POINTS: decimal with 4 fractional digits (XX.XXXX)
    - STAGE PERCENT: decimal with 2 fractional digits (XX.XX)
    - competitor number: integer
    - competitor name: everything after competitor number (may contain commas/accents)

- Pagination & continuation
  - Tables span multiple pages. The division + stage header and the column header repeat at the top of each page.
  - Continue parsing rows across page boundaries until a new division or stage header appears.

Recommended row regex (text-layout approach)
- A resilient regex to capture each row when using layout-preserving text (tweak spaces as needed):

  ^\s*(\d+)\s+(\d+)\s+(\d+(?:\.\d{1,2})?)\s+(\d+\.\d{4})\s+(\d+\.\d{4})\s+(\d+\.\d{1,2})\s+(\d+)\s+(.+?)\s*$

  Captures: ranking, pts, time, hit_factor, stage_points, stage_percentage, competitor_number, competitor_name

Validation rules to apply when parsing
- Verify `hit_factor ≈ PTS / TIME` within a small tolerance (e.g., relative error < 0.5%) to detect parsing drift.
- Ensure `competitor_number` is integer and `competitor_name` is non-empty.
- Normalize header tokens (lowercase, trim) when mapping columns.

When to prefer coordinate-based parsing
- Use the Dart `pdf` package or any parser that exposes text items with coordinates if you need stronger reliability (recommended when names wrap lines or column spacing is inconsistent).
- Strategy: detect header text positions to infer x-anchors for columns, then assign text items to nearest anchors and group by y-coordinate rows.

Notes and next steps
- The text-layout approach (pdftotext -layout or equivalent) is fast to implement and works well for the provided sample PDF; coordinate-based parsing is more robust for edge cases and should be the long-term goal.
- If you want, I can now implement a parser using the text-layout regex above and unit tests against `test/sample_data/Bangbangcup_2025_rd2.pdf`'s extracted text, then iterate to a coordinate-based parser.