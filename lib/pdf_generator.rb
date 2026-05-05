require "prawn"

# Suppress Prawn font warning
Prawn::Fonts::AFM.hide_m17n_warning = true

module Planning
  class PdfGenerator
    MINUTES_PER_PIXEL = 1.7
    ROW_HEIGHT = 20
    LEFT_MARGIN = 200
    TIME_STEP_MINUTES = 60
    MAX_BY_PAGE = 22
    COLORS = %w[007ACC FFC107 4CAF50 E91E63 9C27B0 FF5722 795548 3F51B5].freeze

    def initialize(missions)
      @missions = missions
    end

    def generate_all
      result = {}
      @missions.each do |mission_name, day_entries|
        next if day_entries.nil? || day_entries.empty?

        safe_mission = sanitize_name(mission_name)
        day_entries.each do |entry|
          pdf_path = File.join(safe_mission, "#{entry[:day]}.pdf")
          result[pdf_path] = generate_for_day(mission_name, entry)
        end
      end
      result
    end

    private

    TRANSLITERATIONS = {
      "à" => "a", "â" => "a", "ä" => "a", "á" => "a", "ã" => "a", "å" => "a", "æ" => "ae",
      "ç" => "c",
      "è" => "e", "é" => "e", "ê" => "e", "ë" => "e",
      "î" => "i", "ï" => "i", "í" => "i", "ì" => "i",
      "ñ" => "n",
      "ô" => "o", "ö" => "o", "ó" => "o", "ò" => "o", "õ" => "o", "ø" => "o", "œ" => "oe",
      "ù" => "u", "û" => "u", "ü" => "u", "ú" => "u",
      "ÿ" => "y",
      "ß" => "ss"
    }.freeze

    def safe_text(str)
      str.to_s.encode("Windows-1252", invalid: :replace, undef: :replace, replace: "").encode("UTF-8")
    end

    def sanitize_name(name)
      name.to_s.downcase
        .gsub(/[^\x00-\x7F]/) { |c| TRANSLITERATIONS[c] || "" }
        .gsub(/[^a-z0-9-]+/, "_").squeeze("_")
        .gsub(/^_|_$/, "")
    end

    def show_page_header(pdf, day, mission_name, day_start, day_end)
      pdf.font_size(10)
      pdf.text(safe_text("#{day.strftime("%d %B")} -- #{mission_name}"), size: 13, style: :bold)
      pdf.move_down(20)

      y_origin = pdf.cursor
      current_time = day_start

      while current_time <= day_end
        minutes_from_start = ((current_time - day_start) * 24 * 60).to_i
        x = LEFT_MARGIN + (minutes_from_start / MINUTES_PER_PIXEL)

        hour_label = current_time.strftime("%H:%M")

        pdf.stroke_color("DDDDDD")
        pdf.stroke_line([x, y_origin + 10], [x, 40])
        pdf.fill_color("000000")
        pdf.draw_text(hour_label, at: [x - 12, y_origin + 14])

        current_time += Rational(TIME_STEP_MINUTES, 24 * 60)
      end
    end

    def generate_for_day(mission_name, entry)
      day = entry[:day]
      day_start = entry[:day_start]
      day_end = entry[:day_end]
      grouped_by_email = entry[:grouped_by_email]

      email_to_color = {}

      pdf = Prawn::Document.new(page_size: "A4", page_layout: :landscape)
      show_page_header(pdf, day, mission_name, day_start, day_end)

      grouped_by_email.each_with_index do |(email, tasks), index|
        y = pdf.cursor - (index % MAX_BY_PAGE * ROW_HEIGHT)

        if index % MAX_BY_PAGE == 0 && index != 0
          pdf.start_new_page
          show_page_header(pdf, day, mission_name, day_start, day_end)
          y = pdf.cursor
        end

        pdf.text_box(
          safe_text("#{tasks[0][:phone]} - #{tasks[0][:name]}"),
          at: [0, y],
          width: LEFT_MARGIN - 10,
          height: ROW_HEIGHT,
          valign: :center,
          align: :left,
          size: 10
        )

        email_to_color[email] ||= COLORS[email_to_color.size % COLORS.size]
        pdf.fill_color(email_to_color[email])

        tasks.each do |task|
          start_offset = ((task[:start] - day_start) * 24 * 60).to_i
          end_offset = ((task[:end] - day_start) * 24 * 60).to_i
          bar_x = LEFT_MARGIN + (start_offset / MINUTES_PER_PIXEL)
          bar_width = [(end_offset - start_offset) / MINUTES_PER_PIXEL, 1].max

          pdf.fill_rectangle([bar_x, y], bar_width, ROW_HEIGHT)

          label = "#{task[:start].strftime("%H:%M")} - #{task[:end].strftime("%H:%M")}"
          pdf.fill_color("000000")
          pdf.text_box(
            label, at: [bar_x + 2, y], width: bar_width - 4, height: ROW_HEIGHT,
            size: 8, overflow: :shrink_to_fit, valign: :center, align: :center
          )

          pdf.fill_color(email_to_color[email])
        end

        pdf.stroke_color("AAAAAA")
        pdf.stroke_line([0, y - ROW_HEIGHT], [pdf.bounds.right, y - ROW_HEIGHT])
        pdf.fill_color("000000")
      end

      pdf.render
    end
  end
end
