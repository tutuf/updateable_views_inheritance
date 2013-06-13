class UviAdapterNotCompatibleError < StandardError; end

require 'instantiate_with_uvi_support'
if ActiveRecord::Base.connection.is_a?(ActiveRecord::ConnectionAdapters::PostgreSQLAdapter)
  require 'postgresql_adapter'
else
  raise UviAdapterNotCompatibleError.new("uvi currently supports only PostgreSQL")
end

