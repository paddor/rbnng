require "rake/extensiontask"
require "rake/testtask"

Rake::ExtensionTask.new("rbnng") do |ext|
  ext.lib_dir = "lib/nng"
end

Rake::TestTask.new(:test) do |t|
  t.test_files = FileList["test/nng/**/*_spec.rb"]
  t.ruby_opts = ["-W:no-experimental"]
end

Rake::TestTask.new(:patterns) do |t|
  t.test_files = FileList["examples/zguide/*.rb"]
end

task default: :test
