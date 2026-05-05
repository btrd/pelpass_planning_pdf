require "sinatra"
require_relative "lib/generator"

ALLOWED_HOST_SUFFIX = ".weezevent.com"

get "/pelpass" do
  if params[:url].nil? || params[:url].empty?
    halt 400, "Missing 'url' parameter"
  end

  uri = URI.parse(params[:url])
  unless uri.is_a?(URI::HTTPS) && uri.host&.end_with?(ALLOWED_HOST_SUFFIX)
    halt 400, "URL must be HTTPS and from #{ALLOWED_HOST_SUFFIX}"
  end

  filename = Planning::Generator.new(url: params[:url]).run
  send_file filename, filename: filename, type: "application/zip", disposition: "attachment"
end
