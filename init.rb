class ClassTableInheritanceAdapterNotCompatibleError < StandardError; end

require 'instantiate_with_clti_support'

unless defined?(ActiveRecord::ConnectionAdapters::PostgreSQLAdapter)
  raise ClassTableInheritanceAdapterNotCompatibleError.new("Only PostgreSQL is currently supported by the class table inheritance plugin.")
end

require 'postgresql_adapter'