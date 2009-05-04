require 'rake/testtask'
require 'rake/rdoctask'
namespace :class_table_inheritance do
  desc 'Default: run unit tests.'
  task :default => :test
  
  desc 'Run unit tests'
  Rake::TestTask.new(:test => 'test:rebuild_database') do |t|
    t.libs << File.dirname(__FILE__) + '/../lib'
    t.pattern = File.dirname(__FILE__) + '/../test/*_test.rb'
    t.verbose = true
  end
  
  desc 'Generate documentation for the class_table_inheritance plugin.'
  Rake::RDocTask.new(:rdoc) do |rdoc|
    rdoc.rdoc_dir = 'rdoc'
    rdoc.title    = 'Class Table Inheritance'
    rdoc.options << '--line-numbers' << '--inline-source'
    rdoc.rdoc_files.include('README')
    rdoc.rdoc_files.include('/lib/**/*.rb')
  end
  
  desc 'Generate fixture for class_table_inheritance table in test/fixtures'
  task :fixture => :environment do
    table_name = 'class_table_inheritance'
    f = File.new(File.expand_path("test/fixtures/#{table_name}.yml", RAILS_ROOT), "w+")
    f.puts(ActiveRecord::Base.connection.select_all("SELECT * FROM #{table_name}").inject({}) { |hsh, record|
                   hsh.merge({record['child_aggregate_view'] => record})
                 }.to_yaml)
    f.close
  end
  
  desc 'Generate migration to create special table for the class table inheritance plugin'
  task :install => :environment do
    raise "Task unavailable to this database (no migration support)" unless ActiveRecord::Base.connection.supports_migrations?
    require 'rails_generator'
    require 'rails_generator/scripts/generate'
    Rails::Generator::Scripts::Generate.new.run(["class_table_inheritance_migration", ENV["MIGRATION"] || "AddClassTableInheritance"])
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
end