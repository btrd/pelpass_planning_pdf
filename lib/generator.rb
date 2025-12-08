require "open-uri"
require "csv"
require "debug"
require "fileutils"
require_relative "data_loader"
require_relative "pdf_generator"
require_relative "zip_file_generator"

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
      output_dir = "planning_#{Time.now.strftime("%Y-%m-%d_%H-%M-%S")}"

      puts "Generating PDFs into #{output_dir}/"
      Planning::PdfGenerator.new(@missions, output_dir).generate_all

      puts "Generating ZIP file #{output_dir}.zip"
      Planning::ZipFileGenerator.new(output_dir, "#{output_dir}.zip").write

      "#{output_dir}.zip"
    ensure
      puts "Cleaning up temporary folder #{output_dir}/"
      FileUtils.rm_rf(output_dir)
    end
  end
end
