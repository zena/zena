# Fixes #98
if ActiveRecord::Base.configurations[RAILS_ENV]['adapter'] == 'postgresql'
  # Fixes timezone to "+0:0"
  ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.class_eval do
    def configure_connection_with_timezone
      configure_connection_without_timezone
      tz = ActiveRecord::Base.default_timezone == :utc ? "UTC" : "SYSTEM"
      execute("SET TIMEZONE = '#{tz}'")
    end
    alias_method_chain :configure_connection, :timezone
  end
end