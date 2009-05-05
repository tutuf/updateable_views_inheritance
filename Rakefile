require 'rake/testtask'
require 'rake/rdoctask'

desc 'Run unit tests'
Rake::TestTask.new(:test => 'test:rebuild_database') do |t|
  t.libs << "#{File.dirname(__FILE__)}/lib"
  t.pattern = "#{File.dirname(__FILE__)}/test/*_test.rb"
  t.verbose = true
end

desc 'Generate documentation'
Rake::RDocTask.new(:rdoc) do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title    = 'Class Table Inheritance'
  rdoc.options << '--line-numbers' << '--inline-source'
  rdoc.rdoc_files.include('README')
  rdoc.rdoc_files.include('/lib/**/*.rb')
end

namespace :test do
  desc 'Build the plugin test database'
  task :build_database do 
    %x( createdb -U postgres class_table_inheritance_plugin_test )
  end

  desc 'Drop the plugin test database'
  task :drop_database do 
    %x( dropdb  -U postgres class_table_inheritance_plugin_test )
  end

  desc 'Rebuild the plugin test database'
  task :rebuild_database => [:drop_database, :build_database]
end