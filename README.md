# Planning PDF Generator

A small Ruby tool that converts a CSV of volunteer assignments into per-mission, per-day PDF schedules.

This README reflects the refactor: input is CSV, parsing is handled by `Planning::DataLoader`, rendering by `Planning::PdfGenerator`, and `script.rb` orchestrates both.

**Prerequisites**

- Ruby (3.x recommended)

```bash
bundle install
```

**Entry points**

- `script.rb` — orchestration: loads data with `Planning::DataLoader` and calls `Planning::PdfGenerator` to write PDFs (and optionally creates a ZIP).
- `lib/planning/data_loader.rb` — CSV parsing and per-day grouping.
- `lib/planning/pdf_generator.rb` — PDF rendering using Prawn.
- `Rakefile` — includes `rake test` and `rake generate` (runs `script.rb`).

**How to run**

Run tests:

```bash
bundle exec rake test
```

Generate PDFs:

```bash
bundle exec rake generate
```

**CSV format (exact headers required)**

The loader expects a CSV with a header row using these exact column names (no normalization):

- `Mission` — mission/task identifier
- `Prenom` — first name
- `Nom` — last name
- `E-mail` — email (used as unique identifier)
- `Numero de telephone` — phone number
- `Date de debut` — start date/time (ISO or DateTime-parseable)
- `Date de fin` — end date/time
- `Categorie` — category (rows with "9 Referents" or similar are skipped)
- `Statut d affectation` — assignment status

Ensure your CSV uses these exact header strings. If your source uses accented headers (e.g., `Prénom`), update the CSV or the loader to match.

**Filters applied by the loader**

- Skips rows where `Categorie` contains referent information (e.g. "9 Referents").
- Skips statuses like `N'est pas applicable` or `En attente d affectation`.

**Output layout**

Generated files are placed under `planning/` with sanitized mission names:

```
planning/
├── accueil/
│   └── 2025-06-01.pdf
└── autres-missions/
    └── 2025-06-01.pdf
```

Each PDF is a landscape A4 page with an hourly timeline and colored bars per-assignment. When many people are present, additional pages are created.

**Configuration**

Most configuration values (time scale, margins, output directory) are defined near the top of `script.rb`. Edit those constants to tune layout:

- `INPUT_CSV` — path to CSV file
- `OUTPUT_DIR` — where PDFs are written (default: `planning`)
- `MINUTES_PER_PIXEL`, `ROW_HEIGHT`, `LEFT_MARGIN`, `TIME_STEP_MINUTES` — layout tuning
