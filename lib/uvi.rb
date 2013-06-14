require "uvi/version"

module Uvi
end

class UviAdapterNotCompatibleError < StandardError; end

require "uvi/active_record"
if ActiveRecord::Base.connection.is_a?(ActiveRecord::ConnectionAdapters::PostgreSQLAdapter)
  require 'uvi/postgresql_adapter'
else
  raise UviAdapterNotCompatibleError.new("uvi currently supports only PostgreSQL")
end