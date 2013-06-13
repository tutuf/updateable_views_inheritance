namespace :uvi do
  desc 'Generate fixture for uvi table in test/fixtures'
  task :fixture => :environment do
    table_name = 'uvi'
    f = File.new(File.expand_path("test/fixtures/#{table_name}.yml", Rails.root), "w+")
    f.puts(ActiveRecord::Base.connection.select_all("SELECT * FROM #{table_name}").inject({}) { |hsh, record|
                   hsh.merge({record['child_aggregate_view'] => record})
                 }.to_yaml)
    f.close
  end
  
  desc 'Generate migration to create special table for the uvi gem'
  task :setup => :environment do
    raise "Task unavailable to this database (no migration support)" unless ActiveRecord::Base.connection.supports_migrations?
    require 'rails_generator'
    require 'rails_generator/scripts/generate'
    Rails::Generator::Scripts::Generate.new.run(["uvi_migration", ENV["MIGRATION"] || "AddUpdatebleViewsInheritance"])
  end
end