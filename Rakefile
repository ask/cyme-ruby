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
require File.expand_path('../lib/cyme/meta', __FILE__)
require 'rake/rdoctask'


meta = Cyme::Meta.new()

Jeweler::Tasks.new do |gem|
  meta.contribute_to_spec(gem)
end
Jeweler::RubygemsDotOrgTasks.new

require 'spec/rake/spectask'

desc 'Run unit tests'
Spec::Rake::SpecTask.new(:test) do |t|
  t.spec_opts = ['--format', 'specdoc', '--colour']
  t.spec_files = FileList['spec/**/*_spec.rb']
end

desc 'Run all tests with code coverage'
Spec::Rake::SpecTask.new(:coverage) do |t|
  t.spec_opts = ['--format', 'specdoc', '--colour']
  t.spec_files = FileList['spec/**/*_spec.rb']
  t.rcov = true
  # Exclude gems used
  t.rcov_opts = ['--exclude', '^/']
  t.rcov_dir = ENV['RCOV_DIR'] || 'coverage'
end

task :default => :test
