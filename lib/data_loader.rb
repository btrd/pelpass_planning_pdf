require "date"

module Planning
  class DataLoader
    def initialize(csv_content)
      @csv_content = csv_content
    end

    def load_missions
      missions = Hash.new { |h, k| h[k] = [] }

      @csv_content.each do |row|
        # Skip non assigned volunteers
        next unless row["Statut d'affectation"] == "Affecté"

        start_time = begin
          DateTime.parse(row["Date de début"])
        rescue ArgumentError, TypeError
          nil
        end
        end_time = begin
          DateTime.parse(row["Date de fin"])
        rescue ArgumentError, TypeError
          nil
        end
        next if start_time.nil? || end_time.nil?

        email = row["E-mail"].gsub("<html><u>", "").gsub("</u></html>", "")
        name = "#{row["Prénom"]} #{row["Nom"]}".strip
        phone = (row["Numéro de téléphone"] || "").delete(" ")
        lastname = row["Nom"]

        mission = row["Mission"]
        missions[mission] << {
          start: start_time, end: end_time, email: email, name: name,
          phone: phone, lastname: lastname
        }
      end

      processed = {}

      missions.each do |mission_name, tasks|
        next if tasks.empty?

        # Get all logical days covered by tasks
        all_logical_days = tasks.flat_map do |t|
          (logical_day(t[:start])..logical_day(t[:end])).to_a
        end.uniq.sort

        day_entries = all_logical_days.map do |day|
          jour_debut = DateTime.new(day.year, day.month, day.day, 8, 0, 0)
          jour_fin = DateTime.new(day.year, day.month, day.day, 7, 59, 59) + 1

          tasks_for_day = tasks.select { |t| (t[:end] > jour_debut) && (t[:start] < jour_fin) }
          next nil if tasks_for_day.empty?

          earliest_start = tasks_for_day.map { |t| t[:start] }.min
          latest_end = tasks_for_day.map { |t| t[:end] }.max

          day_start = [jour_debut, earliest_start].max
          day_end = [jour_fin, latest_end].min

          tasks_for_day = tasks.select { |t| (t[:end] > day_start) && (t[:start] < day_end) }
          next nil if tasks_for_day.empty?

          visible_tasks = tasks_for_day.map do |t|
            {
              start: [t[:start], day_start].max,
              end: [t[:end], day_end].min,
              email: t[:email], name: t[:name], lastname: t[:lastname], phone: t[:phone]
            }
          end

          grouped_by_email = visible_tasks
            .sort_by { |t| t[:lastname] }
            .group_by { |t| t[:email] }

          {
            day: day,
            day_start: day_start,
            day_end: day_end,
            grouped_by_email: grouped_by_email
          }
        end.compact

        processed[mission_name] = day_entries
      end

      processed
    end

    private

    # 8 AM cutoff for logical day, e.g. 2024-06-10 07:59 is logical day 2024-06-09
    def logical_day(datetime)
      (datetime.hour < 8) ? (datetime.to_date - 1) : datetime.to_date
    end
  end
end
