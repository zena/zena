class ActiveRecord::ConnectionAdapters::MysqlAdapter
  NATIVE_DATABASE_TYPES[:primary_key] = "int(11) auto_increment PRIMARY KEY"
  alias :connect_no_sql_mode :connect
  def connect
    connect_no_sql_mode
    execute("SET sql_mode = ''")
  end
end