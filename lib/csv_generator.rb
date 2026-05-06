require "csv"

module Planning
  class CsvGenerator
    def initialize(missions)
      @missions = missions
    end

    def generate_all
      days = build_days_index
      days.sort_by { |day, _| day }.each_with_object({}) do |(day, volunteers), result|
        result["#{day}.csv"] = generate_csv(volunteers)
      end
    end

    private

    def build_days_index
      days = {}

      @missions.each do |mission_name, day_entries|
        day_entries.each do |entry|
          day_volunteers = days[entry[:day]] ||= {}

          entry[:grouped_by_email].each do |email, tasks|
            volunteer = day_volunteers[email] ||= {
              firstname: tasks[0][:firstname],
              lastname: tasks[0][:lastname],
              phone: tasks[0][:phone],
              email: email,
              pronom: tasks[0][:pronom],
              missions: []
            }

            mission_start = tasks.map { |t| t[:start] }.min
            mission_end = tasks.map { |t| t[:end] }.max
            range = "#{mission_start.strftime("%H:%M")}-#{mission_end.strftime("%H:%M")}"
            volunteer[:missions] << "#{mission_name} (#{range})"
          end
        end
      end

      days
    end

    def generate_csv(volunteers)
      CSV.generate do |csv|
        csv << ["prénom", "pronom", "nom", "téléphone", "email", "missions"]
        volunteers.values.sort_by { |v| v[:lastname] }.each do |v|
          csv << [v[:firstname], v[:pronom], v[:lastname], format_phone(v[:phone]), v[:email], v[:missions].join(", ")]
        end
      end
    end

    def format_phone(phone)
      phone.gsub(/(\d{2})(?=\d)/, '\1 ')
    end
  end
end
