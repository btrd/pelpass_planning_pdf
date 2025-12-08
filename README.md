# Planning PDF Generator

A small Ruby tool that converts a CSV of volunteer assignments into per-mission, per-day PDF schedules.
CSV file come from WeezCrew platform export feature, URL looks like `https://api.weezevent.com/crew/export/organization/{org_id}/event/{event_id}/assignments` (more info [on the weezevent documentation page](https://support.weezevent.com/fr/exporter-les-donnees-de-mes-missions)).

## Entry points

- `server.rb` Sinatra-based HTTP server exposing `/pelpass` that generates a ZIP per request.
- `lib/generator.rb` Take an CSV url, create PDFs, zip the folder, and return the path
- `lib/data_loader.rb` Load CSV, filter the data and return an Hash
- `lib/pdf_generator.rb` Generate PDF using an Hash
- `lib/zip_file_generator.rb` Generate a zip from a folder

## Run in development

Install dependancies:

```bash
bundle install
```

Start the server:

```zsh
ruby server.rb
```

Generate zip file from CSV path:

```ruby
Planning::Generator.new(path: "7074-paye-ton-noel-19---2025.csv").run
```

## Run in production

The application is launched using a `systemd` service file located in `pelpass.service`, on the dedicated server behind a nginx reverse proxy.

```bash
# Start the service
systemctl --user enable --now pelpass.service
# Check the service status
systemctl --user status pelpass.service
# Follow the service logs
journalctl --user -u pelpass.service -f
```