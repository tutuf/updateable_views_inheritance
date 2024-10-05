require "rails/generators"
require "rails/generators/migration"
require "rails/generators/active_record"

module UpdateableViewsInheritance
  module Generators
    class InstallGenerator < Rails::Generators::Base
      include Rails::Generators::Migration

      desc "Creates a migration for a special table used by the updateable_views_inheritance gem"
      source_root File.expand_path("../templates", __FILE__)

      # Implement the required interface for Rails::Generators::Migration
      def self.next_migration_number(dirname)
        ActiveRecord::Generators::Base.next_migration_number(dirname)
      end

      def install
        migration_file = "create_updateable_views_inheritance.rb"
        migration_template migration_file, "db/migrate/#{migration_file}"
      end
    end
  end
end
