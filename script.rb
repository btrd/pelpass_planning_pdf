require('roo')
require('prawn')
require('date')
require('fileutils')
require('pry')

Prawn::Fonts::AFM.hide_m17n_warning = true

# === CONFIGURATION ===
# Nom du fichier Excel en entrée
INPUT_XLSX = '5870-pelpass-festival-8---2025.xlsx'
MINUTES_PER_PIXEL = 1.5      # Échelle de temps : 1 pixel = 1 minute
ROW_HEIGHT = 20            # Hauteur de chaque ligne représentant une personne
LEFT_MARGIN = 200          # Marge gauche réservée pour le nom
TIME_STEP_MINUTES = 60     # Intervalle entre les lignes horaires
OUTPUT_DIR = 'planning'    # Dossier de sortie pour les fichiers PDF
# Couleurs utilisées pour les barres
COLORS = %w[007ACC FFC107 4CAF50 E91E63 9C27B0 FF5722 795548 3F51B5]

# === CHARGEMENT DU FICHIER XLSX ===
xlsx = Roo::Spreadsheet.open(INPUT_XLSX)
sheet = xlsx.sheet(0)
headers = sheet.row(1).map(&:to_s)  # Entêtes du tableau Excel

# Regrouper les tâches par mission
missions = Hash.new { |h, k| h[k] = [] }

(2..sheet.last_row).each do |i|
  row = Hash[[headers, sheet.row(i)].transpose]

  mission = row['Mission']
  start_time = DateTime.parse(row['Date de début'].to_s)
  end_time = DateTime.parse(row['Date de fin'].to_s)
  email = row['E-mail'].gsub("<html><u>", "").gsub("</u></html>", "")
  name = "#{row['Prénom']} #{row['Nom']}"
  phone = row['Numéro de téléphone'].gsub(" ", "")

  missions[mission] << {
    start: start_time, end: end_time, email: email, name: name, phone: phone
  }
end

# Fonction pour définir le "jour logique" (08h00 → 07h59 du lendemain) TODO ne fonctionne pas
def logical_day(datetime)
  return (datetime.hour < 8 ? (datetime.to_date - 1) : datetime.to_date)
end

# Affiche le header pour chaque page de PDF
def show_page_header(pdf, day, mission_name, day_start, day_end)
  pdf.font_size(10)
  pdf.text("#{day.strftime('%d %B')} -- #{mission_name}", size: 13, style: :bold)
  pdf.move_down(20)

  y_origin = pdf.cursor
  current_time = day_start

  # Affichage des lignes horaires verticales toutes les heures
  while (current_time <= day_end)
    # Calcul de la position horizontale du trait d'heure
    minutes_from_start = ((current_time - day_start) * 24 * 60).to_i
    x = LEFT_MARGIN + (minutes_from_start / MINUTES_PER_PIXEL)

    hour_label = current_time.strftime('%H:%M')

    pdf.stroke_color('DDDDDD')
    pdf.stroke_line([x, y_origin + 10], [x, 40])
    pdf.fill_color('000000')
    pdf.draw_text(hour_label, at: [x - 12, y_origin + 14])

    current_time += Rational(TIME_STEP_MINUTES, 24 * 60)
  end
end

# === GÉNÉRATION DES PDF PAR MISSION ET JOUR LOGIQUE ===
missions.each do |mission_name, tasks|
  next if tasks.empty?

  # Nettoyage du nom pour un nom de dossier valide
  safe_mission = mission_name.gsub(/[^\w\-]/, '_')
  mission_dir = File.join(OUTPUT_DIR, safe_mission)
  FileUtils.mkdir_p(mission_dir)

  # Extraire tous les jours logiques concernés par les tâches
  all_logical_days = tasks.flat_map do |t|
    (logical_day(t[:start])..logical_day(t[:end])).to_a
  end.uniq.sort

  all_logical_days.each do |day|
    # Sélectionner les tâches actives durant ce jour logique
    tasks_for_day = tasks.select do |t|
      (t[:end] > DateTime.new(day.year, day.month, day.day, 0, 0, 0)) &&
      (t[:start] < DateTime.new(day.year, day.month, day.day, 23, 59, 59))
    end

    next if tasks_for_day.empty?

    # Déterminer les bornes de la journée
    earliest_start = tasks_for_day.map { |t| t[:start] }.min
    latest_end = tasks_for_day.map { |t| t[:end] }.max

    # Heure de début réelle ou 8h00 (si avant, on force à 8h00)
    day_start = DateTime.new(
      day.year, day.month, day.day, earliest_start.hour, earliest_start.min,
      earliest_start.sec
    )
    if (day_start.hour < 8)
      day_start = DateTime.new(
        day.year, day.month, day.day, 8, 0, 0
      )
    end

    # Heure de fin réelle ou 07h59 du lendemain (si après, on limite)
    day_end = DateTime.new(
      latest_end.year, latest_end.month, latest_end.day, latest_end.hour,
      latest_end.min, latest_end.sec
    )
    limite_max = DateTime.new(day.year, day.month, day.day, 7, 59, 59) + 1
    if (day_end > limite_max)
      day_end = limite_max
    end

    # Filtrer à nouveau selon les bornes réelles retenues TODO pourquoi ?
    tasks_for_day = tasks.select do |t|
      (t[:end] > day_start) && (t[:start] < day_end)
    end

    next if (tasks_for_day.empty?)

    # Réduire chaque tâche aux limites du jour affiché (clip visuel)
    # Ceci permet d'afficher uniquement la portion de la tâche visible dans
    # la plage horaire du jour courant
    visible_tasks = tasks_for_day.map do |t|
      {
        start: [t[:start], day_start].max,
        end: [t[:end], day_end].min,
        email: t[:email],
        name: t[:name],
        phone: t[:phone]
      }
    end

    # On garde les créneaux séparés pour une même personne
    grouped = visible_tasks.group_by { |t| t[:email] }
    visible_tasks_grouped = grouped.flat_map do |email, intervals|
      intervals.map do |i|
        { start: i[:start], end: i[:end], name: i[:name], phone: i[:phone], email: email }
      end
    end

    email_to_color = {}  # Association email → couleur
    filename = File.join(mission_dir, "#{day}.pdf")

    # === CRÉATION DU PDF ===
    Prawn::Document.generate(
      filename, page_size: 'A4', page_layout: :landscape
    ) do |pdf|
      show_page_header(pdf, day, mission_name, day_start, day_end)

      # Groupe par personne
      grouped_by_email = visible_tasks_grouped.group_by { |t| t[:email] }

      # Cette boucle traite chaque personne individuellement pour dessiner leurs créneaux horaires.
      grouped_by_email.each_with_index do |(email, tasks), index|
        y = pdf.cursor - (index % 22 * ROW_HEIGHT)

        # Saut de page si on dépasse la zone d'affichage
        if index % 22 == 0 && index != 0
          pdf.start_new_page
          show_page_header(pdf, day, mission_name, day_start, day_end)
          y = pdf.cursor
        end

        # Affichage du nom à gauche
        pdf.text_box(
          "#{tasks[0][:phone]} - #{tasks[0][:name]}",
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
          # Calcul de la position X de la barre + largeur
          start_offset = ((task[:start] - day_start) * 24 * 60).to_i
          end_offset   = ((task[:end] - day_start) * 24 * 60).to_i
          bar_x = LEFT_MARGIN + (start_offset / MINUTES_PER_PIXEL)
          bar_width = [(end_offset - start_offset) / MINUTES_PER_PIXEL, 1].max

          # Dessiner la barre colorée
          pdf.fill_rectangle([bar_x, y], bar_width, ROW_HEIGHT)

          # Texte affichant les horaires dans la barre
          label = "#{task[:start].strftime('%H:%M')} - #{task[:end].strftime('%H:%M')}"

          pdf.fill_color('000000')
          pdf.text_box(
            label,
            at: [bar_x + 2, y],
            width: bar_width - 4,
            height: ROW_HEIGHT,
            size: 8,
            overflow: :shrink_to_fit,
            valign: :center,
            align: :center
          )

          pdf.fill_color(email_to_color[email])
        end

        # Ligne horizontale de séparation entre lignes
        pdf.stroke_color('AAAAAA')
        pdf.stroke_line([0, y - ROW_HEIGHT], [pdf.bounds.right, y - ROW_HEIGHT])
        pdf.fill_color('000000')
      end
    end

    puts("✅ PDF généré : #{filename}")
  end
end
