require_relative "lib/planning/data_loader"
require_relative "lib/planning/pdf_generator"

# === CONFIGURATION ===
INPUT_CSV = "7074-paye-ton-noel-19---2025.csv"
OUTPUT_DIR = "planning"
MINUTES_PER_PIXEL = 1.7
ROW_HEIGHT = 20
LEFT_MARGIN = 200
TIME_STEP_MINUTES = 60
COLORS = %w[007ACC FFC107 4CAF50 E91E63 9C27B0 FF5722 795548 3F51B5]

puts "Loading data from #{INPUT_CSV}..."
missions = Planning::DataLoader.new(INPUT_CSV).load_missions

puts "Generating PDFs into #{OUTPUT_DIR}..."
Planning::PdfGenerator.new(
  missions: missions,
  output_dir: OUTPUT_DIR,
  minutes_per_pixel: MINUTES_PER_PIXEL,
  row_height: ROW_HEIGHT,
  left_margin: LEFT_MARGIN,
  time_step_minutes: TIME_STEP_MINUTES,
  colors: COLORS
).generate_all

puts "All done."
