require "rake/extensiontask"
require "rake/testtask"

Rake::ExtensionTask.new("rbnng") do |ext|
  ext.lib_dir = "lib/nng"
end

Rake::TestTask.new(:test) do |t|
  t.test_files = FileList["test/nng/**/*_spec.rb"]
end

task default: :test
