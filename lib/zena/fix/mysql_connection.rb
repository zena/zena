# Dummy
module Zena
  module Fix
    module MysqlConnection
    end
  end
end

# Fixes #98
ActiveRecord::ConnectionAdapters::MysqlAdapter.class_eval do
  def configure_connection_with_timezone
    configure_connection_without_timezone
    tz = ActiveRecord::Base.default_timezone == :utc ? "+0:0" : "SYSTEM"
    execute("SET time_zone = '#{tz}'")
  end
  alias_method_chain :configure_connection, :timezone
end