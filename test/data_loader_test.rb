require "minitest/autorun"
require "date"
require_relative "../lib/planning/data_loader"

class PlanningDataLoaderTest < Minitest::Test
  def setup
    # headers (ASCII-friendly)
    @headers = [
      "Mission", "Prenom", "Nom", "E-mail", "Numero de telephone",
      "Date de debut", "Date de fin", "Categorie", "Statut d affectation"
    ]

    @valid_row = [
      "Accueil", "Jean", "Dupont", "jean@example.com", "0123456789",
      "2025-06-01 09:00", "2025-06-01 11:00", "", "Affecte"
    ]

    @referent_row = [
      "Accueil", "Ref", "Person", "ref@example.com", "",
      "2025-06-01 10:00", "2025-06-01 12:00", "9 Referents", "Affecte"
    ]
  end

  def test_load_missions_returns_processed_day_entries_and_groups
    require "tempfile"
    tmp = Tempfile.new(["data_loader_test", ".csv"])
    begin
      File.open(tmp.path, "w") do |f|
        f.puts @headers.join(",")
        f.puts @valid_row.join(",")
        f.puts @referent_row.join(",")
      end

      loader = Planning::DataLoader.new(tmp.path)
      processed = loader.load_missions
    ensure
      tmp.unlink
    end

    assert processed.key?("Accueil")

    entries = processed["Accueil"]
    assert_equal 1, entries.size

    entry = entries.first
    assert_equal Date.new(2025, 6, 1), entry[:day]

    grouped = entry[:grouped_by_email]
    assert grouped.key?("jean@example.com")

    tasks = grouped["jean@example.com"]
    assert_equal 1, tasks.size

    task = tasks.first
    assert_instance_of DateTime, task[:start]
    assert_instance_of DateTime, task[:end]
    assert_equal "Jean Dupont", task[:name]
    assert_equal "0123456789", task[:phone]
  end
end
