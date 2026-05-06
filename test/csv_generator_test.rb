require "minitest/autorun"
require "csv"
require_relative "../lib/data_loader"
require_relative "../lib/csv_generator"

class CsvGeneratorTest < Minitest::Test
  def make_missions(rows)
    headers = ["Statut d'affectation", "Date de début", "Date de fin", "E-mail", "Prénom", "Nom", "Numéro de téléphone", "Mission", "Quel est le pronom utilisé (il / elle / iel ....) ?"]
    csv = CSV.parse([headers.join(","), *rows.map { |r| r.join(",") }].join("\n"), headers: true)
    Planning::DataLoader.new(csv).load_missions
  end

  def test_produces_one_csv_per_day
    missions = make_missions([
      ["Affecté", "2024-06-10 09:00:00", "2024-06-10 17:00:00", "a@ex.com", "Alice", "Smith", "0600000001", "Accueil"],
      ["Affecté", "2024-06-11 09:00:00", "2024-06-11 17:00:00", "b@ex.com", "Bob", "Jones", "0600000002", "Accueil"]
    ])
    result = Planning::CsvGenerator.new(missions).generate_all
    assert_equal ["2024-06-10.csv", "2024-06-11.csv"], result.keys.map(&:to_s).sort
  end

  def test_volunteer_appears_once_per_day_across_missions
    missions = make_missions([
      ["Affecté", "2024-06-10 09:00:00", "2024-06-10 12:00:00", "a@ex.com", "Alice", "Smith", "0600000001", "Accueil"],
      ["Affecté", "2024-06-10 14:00:00", "2024-06-10 18:00:00", "a@ex.com", "Alice", "Smith", "0600000001", "Buvette"]
    ])
    result = Planning::CsvGenerator.new(missions).generate_all
    rows = CSV.parse(result["2024-06-10.csv"], headers: true)
    assert_equal 1, rows.size
  end

  def test_missions_column_includes_name_and_time_range
    missions = make_missions([
      ["Affecté", "2024-06-10 09:00:00", "2024-06-10 12:00:00", "a@ex.com", "Alice", "Smith", "0600000001", "Accueil"],
      ["Affecté", "2024-06-10 14:00:00", "2024-06-10 18:00:00", "a@ex.com", "Alice", "Smith", "0600000001", "Buvette"]
    ])
    result = Planning::CsvGenerator.new(missions).generate_all
    rows = CSV.parse(result["2024-06-10.csv"], headers: true)
    assert_includes rows[0]["missions"], "Accueil (09:00-12:00)"
    assert_includes rows[0]["missions"], "Buvette (14:00-18:00)"
  end

  def test_multiple_slots_in_same_mission_collapsed_to_min_max
    missions = make_missions([
      ["Affecté", "2024-06-10 09:00:00", "2024-06-10 12:00:00", "a@ex.com", "Alice", "Smith", "0600000001", "Accueil"],
      ["Affecté", "2024-06-10 13:00:00", "2024-06-10 17:00:00", "a@ex.com", "Alice", "Smith", "0600000001", "Accueil"]
    ])
    result = Planning::CsvGenerator.new(missions).generate_all
    rows = CSV.parse(result["2024-06-10.csv"], headers: true)
    assert_includes rows[0]["missions"], "Accueil (09:00-17:00)"
  end

  def test_rows_sorted_by_lastname
    missions = make_missions([
      ["Affecté", "2024-06-10 09:00:00", "2024-06-10 17:00:00", "z@ex.com", "Zoe", "Zimmermann", "0600000001", "Accueil"],
      ["Affecté", "2024-06-10 09:00:00", "2024-06-10 17:00:00", "a@ex.com", "Alice", "Aaronson", "0600000002", "Accueil"]
    ])
    result = Planning::CsvGenerator.new(missions).generate_all
    rows = CSV.parse(result["2024-06-10.csv"], headers: true)
    assert_equal "Aaronson", rows[0]["nom"]
    assert_equal "Zimmermann", rows[1]["nom"]
  end

  def test_french_headers_and_formatted_phone
    missions = make_missions([
      ["Affecté", "2024-06-10 09:00:00", "2024-06-10 17:00:00", "a@ex.com", "Alice", "Smith", "0600000001", "Accueil"]
    ])
    result = Planning::CsvGenerator.new(missions).generate_all
    rows = CSV.parse(result["2024-06-10.csv"], headers: true)
    assert_equal "Alice", rows[0]["prénom"]
    assert_equal "Smith", rows[0]["nom"]
    assert_equal "06 00 00 00 01", rows[0]["téléphone"]
    assert_equal "a@ex.com", rows[0]["email"]
  end

  def test_pronom_column_present_in_csv
    missions = make_missions([
      ["Affecté", "2024-06-10 09:00:00", "2024-06-10 17:00:00", "a@ex.com", "Alice", "Smith", "0600000001", "Accueil", "elle"]
    ])
    result = Planning::CsvGenerator.new(missions).generate_all
    rows = CSV.parse(result["2024-06-10.csv"], headers: true)
    assert_equal "elle", rows[0]["pronom"]
  end

  def test_empty_missions_returns_no_csvs
    result = Planning::CsvGenerator.new({}).generate_all
    assert_empty result
  end
end
