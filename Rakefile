require 'rubygems'
require 'bundler'
begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end

require 'rake'

require 'jeweler'
Jeweler::Tasks.new do |gem|
  # gem is a Gem::Specification... see http://docs.rubygems.org/read/chapter/20 for more options
  gem.name = "cyme"
  gem.version = File.read("VERSION").chomp
  gem.license = "BSD (3 Clause)"
  gem.summary = %Q{Celery Instance Manager client for Ruby}
  gem.description = %Q{
Celery Instance Manager client for Ruby.
}
  gem.email = "ask@celeryproject.org"
  gem.authors = ["Ask Solem"]
  gem.files = FileList["**/*"].exclude("*~")
  gem.executables = FileList["bin/*"].pathmap("%f")
end
Jeweler::RubygemsDotOrgTasks.new

require 'spec/rake/spectask'

desc "Run all tests"
Spec::Rake::SpecTask.new(:test) do |t|
  t.spec_opts = ["-cfs"]
  t.spec_files = FileList["#{File.expand_path(File.dirname(__FILE__))}/spec/**/*_spec.rb"].sort
end

desc "Run all tests with code coverage"
Spec::Rake::SpecTask.new(:coverage) do |t|
  t.spec_opts = ["-cfs"]
  t.spec_files = FileList["#{File.expand_path(File.dirname(__FILE__))}/spec/**/*_spec.rb"].sort
  t.rcov = true
  # Exclude gems used
  t.rcov_opts = ['--exclude', '^/']
  t.rcov_dir = ENV['RCOV_DIR'] || 'coverage'
end

task :default => :test
