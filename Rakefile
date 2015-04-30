# encoding: utf-8

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
  gem.name = "hyperflow-amqp-executor"
  gem.homepage = "http://github.com/kfigiela/hyperflow-amqp-executor"
  gem.license = "MIT"
  gem.summary = %Q{AMQP job executor for Hyperflow workflow engine}
  gem.description = %Q{AMQP job executor for Hyperflow workflow engine (http://github.com/dice-cyfronet/hyperflow)}
  gem.email = "kamil.figiela@gmail.com"
  gem.authors = ["Kamil Figiela"]
  gem.executables = %w{hyperflow-amqp-executor hyperflow-amqp-metric-collector}
  # dependencies defined in Gemfile
end
Jeweler::RubygemsDotOrgTasks.new

# require 'rake/testtask'
# Rake::TestTask.new(:test) do |test|
#   test.libs << 'lib' << 'test'
#   test.pattern = 'test/**/test_*.rb'
#   test.verbose = true
# end
#
#
# task :default => :test

require 'rdoc/task'
Rake::RDocTask.new do |rdoc|
  version = File.exist?('VERSION') ? File.read('VERSION') : ""

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "hyperflow-amqp-executor #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end
