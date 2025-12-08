require 'open-uri'
require 'csv'
require 'debug'
require 'fileutils'
require_relative "data_loader"
require_relative "pdf_generator"
require_relative 'zip_file_generator'

module Planning
  class Generator
    def initialize(csv_url)
      csv_text = URI.open(csv_url).read
      csv = CSV.parse(csv_text, headers: true, encoding: 'utf-8')
      # path = "/Users/jean/workspaces/pelpass_planning_pdf/7074-paye-ton-noel-19---2025.csv"
      # csv = CSV.read(path, headers: true, encoding: 'utf-8')
      @missions = Planning::DataLoader.new(csv).load_missions
    end

    def run
      output_dir = "planning_#{Time.now.strftime('%Y-%m-%d_%H-%M-%S')}"
      Planning::PdfGenerator.new(@missions, output_dir).generate_all
      Planning::ZipFileGenerator.new(output_dir, "#{output_dir}.zip").write

      return "#{output_dir}.zip"
    ensure
      FileUtils.rm_rf(output_dir)
    end
  end
end
