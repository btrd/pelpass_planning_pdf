require "open-uri"
require "csv"
require "zip"
require_relative "data_loader"
require_relative "pdf_generator"
require_relative "csv_generator"

module Planning
  class Generator
    def initialize(url: nil, path: nil)
      if url
        puts "Loading CSV from #{url}"
        csv_text = URI.parse(url).open.read

        puts "CSV loaded, parsing"
        csv = CSV.parse(csv_text, headers: true, encoding: "utf-8")
      elsif path
        puts "Loading CSV from #{path}"
        csv = CSV.read(path, headers: true, encoding: "utf-8")
      else
        raise ArgumentError, "Either url or path must be provided"
      end

      puts "CSV parsed, loading missions"
      @missions = Planning::DataLoader.new(csv).load_missions
    end

    def run
      zip_path = "planning_#{Time.now.strftime("%Y-%m-%d_%H-%M-%S")}.zip"

      puts "Generating PDFs and CSVs, writing ZIP to #{zip_path}"
      pdfs = Planning::PdfGenerator.new(@missions).generate_all
      csvs = Planning::CsvGenerator.new(@missions).generate_all

      Zip::OutputStream.open(zip_path) do |zip|
        pdfs.merge(csvs).each do |path, content|
          zip.put_next_entry(path)
          zip.write(content)
        end
      end

      zip_path
    end
  end
end
