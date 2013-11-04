require 'active_record/connection_adapters/mysql_adapter'

# ArMysqlFullText
module ActiveRecord
  class SchemaDumper #:nodoc:
      # modifies index support for MySQL full text indexes
      def indexes(table, stream)
        if (indexes = @connection.indexes(table)).any?
          add_index_statements = indexes.map do |index|
            if index.kind_of?(ActiveRecord::ConnectionAdapters::MySQLIndexDefinition) && index.index_type == 'FULLTEXT'
              %Q{
    if Zena::Db.adapter == 'mysql'
      execute "ALTER TABLE #{index.table} ENGINE = MyISAM"
      execute "CREATE #{index.index_type} INDEX #{index.name} ON #{index.table} (#{index.columns.join(',')})"
    end
  }
            else
              statment_parts = [ ('add_index ' + index.table.inspect) ]
              statment_parts << index.columns.inspect
              statment_parts << (':name => ' + index.name.inspect)
              statment_parts << ':unique => true' if index.unique

              index_lengths = index.lengths.compact if index.lengths.is_a?(Array)
              statment_parts << (':length => ' + Hash[*index.columns.zip(index.lengths).flatten].inspect) if index_lengths.present?

              '  ' + statment_parts.join(', ')
            end
          end
          stream.puts add_index_statements.sort.join("\n")
          stream.puts
        end
      end
  end
end

# addition to support the normal 'add_index' syntax
module ActiveRecord
  module ConnectionAdapters

    class MySQLIndexDefinition < Struct.new(:table, :name, :unique, :columns, :lengths, :index_type) #:nodoc:
    end
    class MysqlAdapter
      # Now you can write
      alias o_add_index add_index
      # add_index(:posts, :text, :index_type=>'FULLTEXT')
      def add_index(table_name, column_name, options = {})
        if options[:index_type]
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
        else
          o_add_index(table_name, column_name, options)
        end
      end

      def indexes(table_name, name = nil)#:nodoc:
        indexes = []
        current_index = nil
        execute("SHOW KEYS FROM #{quote_table_name(table_name)}", name).each do |row|
          if current_index != row[2]
            next if row[2] == "PRIMARY" # skip the primary key
            current_index = row[2]
            index_type = row[10]
            index_type = '' if index_type == 'BTREE'
            indexes << MySQLIndexDefinition.new(row[0], row[2], row[1] == "0", [], [], index_type)
          end

          indexes.last.columns << row[4]
          indexes.last.lengths << row[7]
        end
        indexes
      end
    end
  end
end