require "minitest/autorun"
require_relative "../lib/pdf_generator"

class PdfGeneratorSanitizeNameTest < Minitest::Test
  def sanitize(name)
    Planning::PdfGenerator.new({}, "").send(:sanitize_name, name)
  end

  def test_ascii_passthrough
    assert_equal "accueil", sanitize("Accueil")
  end

  def test_french_accents
    assert_equal "etape_cle", sanitize("Étape clé")
  end

  def test_cedilla
    assert_equal "francais", sanitize("Français")
  end

  def test_ligatures
    assert_equal "oeuvre_avec_ae", sanitize("Œuvre avec Æ")
  end

  def test_special_chars_replaced_with_underscore
    assert_equal "hello_world", sanitize("Hello / World!")
  end

  def test_no_leading_or_trailing_underscore
    assert_equal "mission", sanitize("  mission  ")
  end

  def test_no_consecutive_underscores
    assert_equal "a_b", sanitize("a   b")
  end

  def test_german_eszett
    assert_equal "strasse", sanitize("Straße")
  end
end
