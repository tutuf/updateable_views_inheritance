require 'rake/testtask'
require 'rdoc/task'
require 'rake/contrib/rubyforgepublisher'

desc 'Run unit tests'
Rake::TestTask.new(:test => 'test:rebuild_database') do |t|
  t.libs << "#{File.dirname(__FILE__)}/lib"
  t.pattern = "#{File.dirname(__FILE__)}/test/*_test.rb"
  t.verbose = true
end

desc 'Generate documentation'
Rake::RDocTask.new(:rdoc) do |rdoc|
  rdoc.rdoc_dir = 'html'
  rdoc.title    = 'Class Table Inheritance for Rails'
  rdoc.options << '--line-numbers' << '--inline-source'
  rdoc.template = ENV['template'] ? "#{ENV['template']}.rb" : './doc/template/horo'
  rdoc.rdoc_files.include('README.rdoc')
  rdoc.rdoc_files.include('./lib/**/*.rb')
end


desc 'Push to repo and publish docs'
task :push => :rdoc do
  `git push`
  Rake::RubyForgePublisher.new('clti', 'sava_chankov').upload
end

namespace :test do
  desc 'Build the test database'
  task :create_database do
    %x( createdb -U postgres uvi_test )
  end

  desc 'Drop the test database'
  task :drop_database do 
    %x( dropdb  -U postgres uvi_test )
  end

  desc 'Rebuild the test database'
  task :rebuild_database => [:drop_database, :create_database]
end