require "minitest/autorun"
require "csv"
require_relative "../lib/data_loader"

class DataLoaderTest < Minitest::Test
  def make_csv(rows)
    headers = ["Statut d'affectation", "Date de début", "Date de fin", "E-mail", "Prénom", "Nom", "Numéro de téléphone", "Mission"]
    CSV.parse([headers.join(","), *rows.map { |r| r.join(",") }].join("\n"), headers: true)
  end

  def test_skips_non_assigned_volunteers
    csv = make_csv([
      ["Non affecté", "2024-06-10 09:00:00", "2024-06-10 17:00:00", "a@example.com", "Alice", "Smith", "0600000000", "Accueil"],
      ["Affecté", "2024-06-10 09:00:00", "2024-06-10 17:00:00", "b@example.com", "Bob", "Jones", "0611111111", "Accueil"]
    ])
    missions = Planning::DataLoader.new(csv).load_missions
    volunteer_names = missions["Accueil"].flat_map { |e| e[:grouped_by_email].values.flatten.map { |t| t[:name] } }
    assert_includes volunteer_names, "Bob Jones"
    refute_includes volunteer_names, "Alice Smith"
  end

  def test_skips_rows_with_invalid_dates
    csv = make_csv([
      ["Affecté", "not-a-date", "2024-06-10 17:00:00", "a@example.com", "Alice", "Smith", "0600000000", "Accueil"],
      ["Affecté", "2024-06-10 09:00:00", "2024-06-10 17:00:00", "b@example.com", "Bob", "Jones", "0611111111", "Accueil"]
    ])
    missions = Planning::DataLoader.new(csv).load_missions
    volunteer_names = missions["Accueil"].flat_map { |e| e[:grouped_by_email].values.flatten.map { |t| t[:name] } }
    refute_includes volunteer_names, "Alice Smith"
    assert_includes volunteer_names, "Bob Jones"
  end

  def test_strips_html_from_email
    csv = make_csv([
      ["Affecté", "2024-06-10 09:00:00", "2024-06-10 17:00:00", "<html><u>clean@example.com</u></html>", "Alice", "Smith", "0600000000", "Accueil"]
    ])
    missions = Planning::DataLoader.new(csv).load_missions
    emails = missions["Accueil"].flat_map { |e| e[:grouped_by_email].keys }
    assert_includes emails, "clean@example.com"
  end

  def test_logical_day_cutoff_before_8am
    # A task ending at 07:30 on the 11th belongs to the logical day of the 10th
    csv = make_csv([
      ["Affecté", "2024-06-10 22:00:00", "2024-06-11 07:30:00", "a@example.com", "Alice", "Smith", "0600000000", "Nuit"]
    ])
    missions = Planning::DataLoader.new(csv).load_missions
    days = missions["Nuit"].map { |e| e[:day].to_s }
    assert_includes days, "2024-06-10"
  end

  def test_groups_tasks_by_email
    csv = make_csv([
      ["Affecté", "2024-06-10 09:00:00", "2024-06-10 12:00:00", "a@example.com", "Alice", "Smith", "0600000000", "Accueil"],
      ["Affecté", "2024-06-10 13:00:00", "2024-06-10 17:00:00", "a@example.com", "Alice", "Smith", "0600000000", "Accueil"]
    ])
    missions = Planning::DataLoader.new(csv).load_missions
    day_entry = missions["Accueil"].first
    assert_equal 2, day_entry[:grouped_by_email]["a@example.com"].size
  end

  def test_empty_csv_returns_empty_missions
    csv = make_csv([])
    missions = Planning::DataLoader.new(csv).load_missions
    assert_empty missions
  end

  def test_phone_number_spaces_stripped
    csv = make_csv([
      ["Affecté", "2024-06-10 09:00:00", "2024-06-10 17:00:00", "a@example.com", "Alice", "Smith", "06 00 00 00 00", "Accueil"]
    ])
    missions = Planning::DataLoader.new(csv).load_missions
    phones = missions["Accueil"].flat_map { |e| e[:grouped_by_email].values.flatten.map { |t| t[:phone] } }
    assert_includes phones, "0600000000"
  end
end
