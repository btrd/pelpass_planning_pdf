require "debug"
require "sinatra"
require_relative "lib/generator"

get "/pelpass" do
  if params[:url].nil? || params[:url].empty?
    halt 400, "Missing 'url' parameter"
  end

  filename = Planning::Generator.new(url: params[:url]).run
  send_file filename, filename: filename, type: "application/zip", disposition: "attachment"
end
