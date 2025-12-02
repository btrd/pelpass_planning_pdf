# Planning PDF Generator

A Ruby script that generates visual PDF schedules from an Excel file containing volunteer assignments. The script creates one PDF per mission and day, with timeline visualizations showing when each person is scheduled to work.

## Prerequisites

- Ruby (tested with recent versions)
- Required gems:
  ```bash
  gem install roo prawn
  ```

## Configuration

Edit the following constants at the top of `script.rb` to customize behavior:

| Constant | Default | Description |
|----------|---------|-------------|
| `INPUT_XLSX` | `'5870-pelpass-festival-8---2025.xlsx'` | Input Excel file name |
| `MINUTES_PER_PIXEL` | `1.7` | Time scale (pixels per minute) |
| `ROW_HEIGHT` | `20` | Height of each person's row in pixels |
| `LEFT_MARGIN` | `200` | Space reserved for names/contact info |
| `TIME_STEP_MINUTES` | `60` | Interval between hour markers |
| `OUTPUT_DIR` | `'planning'` | Output directory for PDFs |
| `COLORS` | `[array]` | Color palette for volunteer assignments |

## Input File Format

The script expects an Excel file (`.xlsx`) with the following structure:

### Required Columns (Row 2 - headers):
- **Mission**: Mission/task name
- **Prénom**: First name
- **Nom**: Last name
- **E-mail**: Email address (used as unique identifier)
- **Numéro de téléphone**: Phone number
- **Date de début**: Start date/time
- **Date de fin**: End date/time
- **Catégorie**: Category (rows with "9. Référents" are skipped)
- **Statut d'affectation**: Assignment status

### Data Structure:
- Row 1: (Ignored)
- Row 2: Column headers
- Row 3+: Assignment data

### Filters Applied:
The script excludes:
- Assignments with category "9. Référents"
- Status "N'est pas applicable"
- Status "En attente d'affectation"

## How It Works

### 1. Data Processing
- Reads Excel file using `roo` gem
- Groups assignments by mission
- Calculates "logical days" (8:00 AM to 7:59 AM next day)
- Filters and validates assignment data

### 2. PDF Generation
For each mission and logical day:
- Creates a landscape A4 PDF
- Draws timeline with hourly markers
- Plots each person's shifts as colored bars
- Displays contact information on the left
- Handles multi-page layouts (22 people per page)

### 3. Output Structure
```
planning/
├── mission_name_1/
│   ├── 2025-06-01.pdf
│   ├── 2025-06-02.pdf
│   └── ...
├── mission_name_2/
│   ├── 2025-06-01.pdf
│   └── ...
└── ...
```

Mission names are sanitized (lowercased, special characters removed) for folder names.

## Usage

1. Place your Excel file in the same directory as `script.rb`
2. Update `INPUT_XLSX` constant if your file has a different name
3. Run the script:
   ```bash
   ruby script.rb
   ```
4. Find generated PDFs in the `planning/` directory

## Features

### Logical Days
The script uses 8 AM to 8 AM "logical days" rather than midnight-to-midnight. This is practical for events that run late into the night.

### Time Clipping
If a shift spans multiple days, only the portion within each logical day is shown on that day's PDF.

### Multi-page Support
When a mission has more than 22 volunteers on a single day, the script automatically creates additional pages with repeated headers.

## Customization

### Adjusting Time Scale
To make the timeline more/less compressed, modify `MINUTES_PER_PIXEL`:
- Lower values = more compressed (more time fits on page)
- Higher values = more expanded (easier to read short shifts)

### Filtering Different Days
Currently, the script has a debug filter on line 166:
```ruby
next unless day.to_s == "2025-06-01"
```
Remove or modify this line to generate PDFs for all days or different specific days.

## Troubleshooting

### "Cannot parse date" errors
Ensure all date fields in Excel are properly formatted as dates/times, not text.

### Missing PDFs
Check that:
- Assignments exist for the mission/day combination
- Status fields don't filter out all assignments
- The debug filter on line 166 isn't blocking output

### Overlapping text
If volunteer names are too long, increase `LEFT_MARGIN` to provide more space.
