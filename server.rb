require 'debug'
require 'sinatra'
require_relative 'lib/generator'

get '/pelpass' do
    filename = Planning::Generator.new(params[:url]).run
    send_file filename, filename: filename, type: 'application/zip', disposition: 'attachment'
end
