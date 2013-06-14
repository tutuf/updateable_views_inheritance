namespace :updateable_views_inheritance do
  desc 'Generate fixture for updateable_views_inheritance table in test/fixtures'
  task :fixture => :environment do
    table_name = 'updateable_views_inheritance'
    f = File.new(File.expand_path("test/fixtures/#{table_name}.yml", Rails.root), "w+")
    f.puts(ActiveRecord::Base.connection.select_all("SELECT * FROM #{table_name}").inject({}) { |hsh, record|
                   hsh.merge({record['child_aggregate_view'] => record})
                 }.to_yaml)
    f.close
  end
  
  desc 'Generate migration to create special table for the updateable_views_inheritance gem'
  task :setup => :environment do
    raise "Task unavailable to this database (no migration support)" unless ActiveRecord::Base.connection.supports_migrations?
    require 'rails_generator'
    require 'rails_generator/scripts/generate'
    Rails::Generator::Scripts::Generate.new.run(["updateable_views_inheritance_migration", ENV["MIGRATION"] || "AddUpdatebleViewsInheritance"])
  end
end