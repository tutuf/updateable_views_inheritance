require 'rails/generators'
require 'rails/generators/migration'
require 'rails/generators/active_record'

module UpdateableViewsInheritance
  module Generators
    class InstallGenerator < Rails::Generators::Base
      include Rails::Generators::Migration
      extend ActiveRecord::Generators::Migration
      
      desc "Creates a migration that creates a special table used by the updateable_views_inheritance gem."
      source_root File.expand_path('../templates', __FILE__)
      
      def create_migration
        migration_file = "create_updateable_views_inheritance.rb"
        migration_template migration_file, "db/migrate/#{migration_file}"
      end
    end
  end
end