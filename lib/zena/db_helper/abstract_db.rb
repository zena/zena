module Zena
  module DbHelper
    module AbstractDb
      def add_column(*args)
        connection.add_column(*args)
      end

      def change_column(*args)
        connection.change_column(*args)
      end

      # Set a single attribute directly in the database.
      def set_attribute(obj, key, value)
        obj.send("#{key}=", value)
        execute "UPDATE #{obj.class.table_name} SET #{key}=#{quote(value)} WHERE id=#{obj[:id]}"
        obj.send(:changed_attributes).delete(key.to_s)
      end

      # Quote value in SQL.
      def quote(value)
        connection.quote(value)
      end

      # Case insensitive find.
      def insensitive_find(klass, count, attributes)
        klass.find(count, :conditions => attributes)
      end

      def quote_date(date)
        if date.kind_of?(Time)
          "'#{date.strftime('%Y-%m-%d %H:%M:%S')}'"
        else
          "''"
        end
      end

      def adapter
        self.class.to_s.downcase
      end

      def execute(*args)
        connection.execute(*args)
      end

      def update(*args)
        connection.update(*args)
      end

      def connection
        ActiveRecord::Base.connection
      end

      def quote_column_name(column_name)
        connection.quote_column_name(column_name)
      end

      def table_options
        ''
      end

      def update_value(name, opts)
        raise Exception.new("Database Adapter #{adapter.inspect} not supported yet (you can probably fix this).")
      end

      def change_engine(table, engine)
        # do nothing
      end

      def add_unique_key(table, keys)
        raise Exception.new("Database Adapter #{adapter.inspect} not supported yet (you can probably fix this).")
      end

      # 'DELETE' depending on a two table query.
      def delete(table, opts)
        raise Exception.new("Database Adapter #{adapter.inspect} not supported yet (you can probably fix this).")
      end

      # Insert a list of values (multicolumn insert). The values should be properly escaped before
      # being passed to this method.
      def insert_many(table, columns, values)
        values = values.compact.uniq.map do |list|
          list.map {|e| quote(e)}
        end

        columns = columns.map{|c| quote_column_name(c)}.join(',')

        values = values.map {|value| "(#{value.join(',')})"}.join(', ')
        execute "INSERT INTO #{table} (#{columns}) VALUES #{values}"
      end

      # Fetch a single row of raw data from db
      def fetch_attribute(sql)
        raise Exception.new("Database Adapter #{adapter.inspect} not supported yet (you can probably fix this).")
      end

      def fetch_ids(sql, attr_name='id')
        connection.select_all(sql, "#{name} Load").map! do |record|
          record[attr_name].to_i
        end
      end

      def fetch_attributes(attributes, table_name, sql)
        sql = "SELECT #{attributes.map{|a| connection.quote_column_name(a)}.join(',')} FROM #{table_name} WHERE #{sql}"
        connection.select_all(sql)
      end

      def select_all(sql_or_array)
        if sql_or_array.kind_of?(String)
          connection.select_all(sql_or_array)
        else
          connection.select_all(Node.send(:sanitize_sql, sql_or_array))
        end
      end

      def next_zip(site_id)
        raise Exception.new("Database Adapter #{adapter.inspect} not supported yet (you can probably fix this).")
      end

      # Return a string matching the pseudo sql function.
      def sql_function(function, key)
        raise Exception.new("Database Adapter #{adapter.inspect} does not support function #{function.inspect}.")
      end

      # This is used by zafu and it's a mess.
      # ref_date can be a string ('2005-05-03') or ruby ('Time.now'). It should not come uncleaned from evil web.
      def date_condition(date_cond, field, ref_date)
        raise Exception.new("Database Adapter #{adapter.inspect} not supported yet (you can probably fix this).")
      end # date_condition

      # Insert a dummy (empty) link to use when mixing queries (QueryNode) with links and without.
      def insert_dummy_ids
        tables = []
        connection.tables.each do |table|
          if table =~ /^idx_/ || table == 'links'
            if table =~ /^idx_nodes/
              next if fetch_attribute("SELECT node_id FROM #{table} WHERE node_id = 0")
            else
              next if fetch_attribute("SELECT id FROM #{table} WHERE id = 0")
            end

            # index table
            klass = Class.new(ActiveRecord::Base) do
              set_table_name table
            end

            dummy_hash = {}
            klass.columns.each do |col|
              if !col.null
                if col.name =~ /_id$/
                  dummy_hash[col.name] = 0
                elsif col.name != 'id'
                  dummy_hash[col.name] = ''
                end
              end
            end

            if dummy = klass.create(dummy_hash)
              tables << table
              if klass.column_names.include?('id')
                connection.execute "UPDATE #{table} SET id = 0 WHERE id = #{dummy.id}"
              end
            else
              raise "Could not create dummy record for table #{table}"
            end
          else
            next
          end
        end

        tables
      end

      # Fixes #98
      def prepare_connection_for_timezone
        # do nothing by default ?
      end

      # Return true if we can load models because the database has the basic tables.
      def migrated_once?
        connection.tables.include?('nodes')
      end
    end # AbstractDb
  end # DbHelper
end # Zena