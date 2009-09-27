require 'active_record/connection_adapters/mysql_adapter'

# ArMysqlFullText
module ActiveRecord
  class SchemaDumper #:nodoc:
      # modifies index support for MySQL full text indexes
      def indexes(table, stream)
        indexes = @connection.indexes(table)
        indexes.each do |index|
          if index.kind_of?(ActiveRecord::ConnectionAdapters::MySQLIndexDefinition) && index.index_type == 'FULLTEXT'
            stream.puts <<RUBY
  if Zena::Db.adapter == 'mysql'
    execute "ALTER TABLE #{index.table} ENGINE = MyISAM"
    execute "CREATE #{index.index_type} INDEX #{index.name} ON #{index.table} (#{index.columns.join(',')})"
  end
RUBY
          else
            stream.print "  add_index #{index.table.inspect}, #{index.columns.inspect}, :name => #{index.name.inspect}"
            stream.print ", :unique => true" if index.unique
            stream.puts
          end
        end
        stream.puts unless indexes.empty?
      end
  end
end

# addition to support the normal 'add_index' syntax
module ActiveRecord
  module ConnectionAdapters

    class MySQLIndexDefinition < Struct.new(:table, :name, :unique, :columns, :index_type) #:nodoc:
    end
    class MysqlAdapter
      # Now you can write
      # add_index(:posts, :text, :index_type=>'FULLTEXT')
      def add_index(table_name, column_name, options = {})
        column_names = Array(column_name)
        index_name   = index_name(table_name, :column => column_names)

        if Hash === options # legacy support, since this param was a string
          index_type = options[:unique] ? "UNIQUE" : (options[:index_type] || "")
          index_name = options[:name] || index_name
        else
          index_type = options
        end
        quoted_column_names = column_names.map { |e| quote_column_name(e) }.join(", ")
        execute "CREATE #{index_type} INDEX #{quote_column_name(index_name)} ON #{table_name} (#{quoted_column_names})"
      end

      def indexes(table_name, name = nil)#:nodoc:
        indexes = []
        current_index = nil
        execute("SHOW KEYS FROM #{table_name}", name).each do |row|
          if current_index != row[2]
            next if row[2] == "PRIMARY" # skip the primary key
            current_index = row[2]
            index_type = row[10]
            index_type = '' if index_type == 'BTREE'
            indexes << MySQLIndexDefinition.new(row[0], row[2], row[1] == "0", [], index_type)
          end

          indexes.last.columns << row[4]
        end
        indexes
      end
    end
  end
end