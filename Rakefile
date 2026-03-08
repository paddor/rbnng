require "rake/extensiontask"
require "rake/testtask"

Rake::ExtensionTask.new("rbnng") do |ext|
  ext.lib_dir = "lib/nng"
end

Rake::TestTask.new(:spec) do |t|
  t.test_files = FileList["spec/**/*_spec.rb"]
end

task default: :spec
