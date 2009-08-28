class ClassTableInheritanceAdapterNotCompatibleError < StandardError; end

require 'instantiate_with_clti_support'
if ActiveRecord::Base.connected? && ActiveRecord::Base.connection.is_a?(ActiveRecord::ConnectionAdapters::PostgreSQLAdapter)
  require 'postgresql_adapter'
elsif ActiveRecord::Base.connected?
  raise ClassTableInheritanceAdapterNotCompatibleError.new("Only PostgreSQL is currently supported by the class table inheritance plugin.")
end

