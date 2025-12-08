require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "lib"
  t.pattern = "test/**/*_test.rb"
  t.verbose = false
end

task default: :test

desc "Generate PDFs (runs script.rb)"
task :generate do
  sh "ruby -Ilib script.rb"
end
