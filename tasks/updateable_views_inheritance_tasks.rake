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
end