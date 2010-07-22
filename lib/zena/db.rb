# FIXME: we should patch the connection adapters instead of having 'case, when' evaluated each time
# For example:
# module ActiveRecord
#   module ConnectionAdapters
#     class MysqlAdapter
#       include Zena::Db::MysqlAdditions
#     end
#   end
# end


module Zena
  module Db
    extend self

    # constants
    case ActiveRecord::Base.configurations[RAILS_ENV]['adapter']
    when 'mysql'
      NOW         = 'now()'
      TRUE        = '1'
      TRUE_RESULT = '1'
      FALSE       = '0'

    when 'postgresql'
      NOW         = 'now()'
      TRUE        = 'true'
      TRUE_RESULT = 't'
      FALSE       = 'false'

    when 'sqlite3'
      NOW         = "datetime('now')"
      TRUE        = '1'
      TRUE_RESULT = 't'
      FALSE       = '0'

    end

    def set_attribute(obj, key, value)
      obj.send("#{key}=", value)
      execute "UPDATE #{obj.class.table_name} SET #{key}=#{quote(value)} WHERE id=#{obj[:id]}"
      obj.send(:changed_attributes).delete(key.to_s)
    end

    def quote(value)
      connection.quote(value)
    end

    def insensitive_find(klass, count, attributes)
      case adapter
      when 'postgresql'
        cond = [[]]
        attributes.each do |attribute, value|
          cond[0] << (value.kind_of?(String) ? "#{attribute} ILIKE ?" : "#{attribute} = ?")
          cond << value
        end
        cond[0] = cond[0].join(' AND ')
        klass.find(count, :conditions => cond)
      when 'sqlite3'
        cond = [[]]
        attributes.each do |attribute, value|
          if value.kind_of?(String)
            cond[0] << "lower(#{attribute}) = ?"
            cond << value.downcase
          else
            cond[0] << "#{attribute} = ?"
            cond << value
          end
        end
        cond[0] = cond[0].join(' AND ')
        klass.find(count, :conditions => cond)
      else
        klass.find(count, :conditions => attributes)
      end
    end

    def quote_date(date)
      if date.kind_of?(Time)
        case adapter
        when 'mysql'
          date.strftime('%Y%m%d%H%M%S')
        when 'postgresql', 'sqlite3'
          "'#{date.strftime('%Y-%m-%d %H:%M:%S')}'"
        end
      else
        "''"
      end
    end

    def adapter
      # Loads the wrong adaper when running rake tasks: ActiveRecord::Base.configurations[RAILS_ENV]['adapter']
      @adapter ||= ActiveRecord::Base.connection.class.name.split('::').last[/(.+)Adapter/,1].downcase
    end

    def execute(*args)
      ActiveRecord::Base.connection.execute(*args)
    end

    def update(*args)
      ActiveRecord::Base.connection.update(*args)
    end

    def connection
      ActiveRecord::Base.connection
    end

    def quote_column_name(column_name)
      connection.quote_column_name(column_name)
    end

    def table_options
      case adapter
      when 'mysql'
        'type=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci'
      else
        ''
      end
    end

    def update_value(name, opts)
      tbl1, fld1 = name.split('.')
      tbl2, fld2 = opts[:from].split('.')
      case adapter
      when 'mysql'
        execute "UPDATE #{tbl1},#{tbl2} SET #{tbl1}.#{fld1}=#{tbl2}.#{fld2} WHERE #{opts[:where]}"
      when 'postgresql'
        execute "UPDATE #{tbl1} SET #{fld1}=#{tbl2}.#{fld2} FROM #{tbl2} WHERE #{opts[:where]}"
      when 'sqlite3'
        execute "UPDATE #{tbl1} SET #{fld1} = (SELECT #{fld2} FROM #{tbl2} WHERE #{opts[:where]})"
      else
        raise Exception.new("Database Adapter #{adapter.inspect} not supported yet (you can probably fix this).")
      end
    end

    def change_engine(table, engine)
      case adapter
      when 'mysql'
        execute "ALTER TABLE #{table} ENGINE = #{engine}"
      else
        # do nothing
      end
    end

    def add_unique_key(table, keys)
      case adapter
      when 'mysql'
        execute "ALTER IGNORE TABLE #{table} ADD UNIQUE KEY(#{keys.join(', ')})"
      when 'postgresql'
        execute "ALTER TABLE #{table} ADD CONSTRAINT #{keys.join('_')} UNIQUE (#{keys.join(', ')})"
      when 'sqlite3'
        execute "CREATE UNIQUE INDEX IF NOT EXISTS #{([table] + keys).join('_').gsub(/[^\w]/,'')} ON #{table} (#{keys.join(', ')})"
      else
        raise Exception.new("Database Adapter #{adapter.inspect} not supported yet (you can probably fix this).")
      end
    end

    # 'DELETE' depending on a two table query.
    def delete(table, opts)
      tbl1, tbl2 = opts[:from]
      fld1, fld2 = opts[:fields]
      case adapter
      when 'mysql'
        execute "DELETE #{table} FROM #{opts[:from].join(',')} WHERE #{tbl1}.#{fld1} = #{tbl2}.#{fld2} AND #{opts[:where]}"
      when 'postgresql'
        using = opts[:from].reject {|t| t == table}
        execute "DELETE FROM #{table} USING #{using.join(', ')} WHERE #{tbl1}.#{fld1} = #{tbl2}.#{fld2} AND #{opts[:where]}"
      when 'sqlite3'
        execute "DELETE FROM #{table} WHERE #{fld1} = (SELECT #{fld2} FROM #{tbl2} WHERE #{opts[:where]})"
      else
        raise Exception.new("Database Adapter #{adapter.inspect} not supported yet (you can probably fix this).")
      end
    end

    # Insert a list of values (multicolumn insert). The values should be properly escaped before
    # being passed to this method.
    def insert_many(table, columns, values)
      values = values.compact.uniq.map do |list|
        list.map {|e| quote(e)}
      end

      columns = columns.map{|c| quote_column_name(c)}.join(',')

      case adapter
      when 'sqlite3'
        pre_query = "INSERT INTO #{table} (#{columns}) VALUES "
        values.each do |value|
          execute pre_query + "(#{value.join(',')})"
        end
      else
        values = values.map {|value| "(#{value.join(',')})"}.join(', ')
        execute "INSERT INTO #{table} (#{columns}) VALUES #{values}"
      end
    end

    # Fetch a single row of raw data from db
    def fetch_attribute(sql)
      case adapter
      when 'sqlite3'
        res = execute(sql)
        res.empty? ? nil : res.first[0]
      when 'mysql'
        res = execute(sql).fetch_row
        res ? res.first : nil
      when 'postgresql'
        res = connection.select_rows(sql)
        res.empty? ? nil : res.first.first
      else
        raise Exception.new("Database Adapter #{adapter.inspect} not supported yet (you can probably fix this).")
      end
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
      case adapter
      when 'mysql'
        res = update "UPDATE zips SET zip=@zip:=zip+1 WHERE site_id = '#{site_id}'"
        if res == 0
          # error
          raise Zena::BadConfiguration, "no zip entry for (#{site_id})"
        end
        rows = execute "SELECT @zip"
        rows.fetch_row[0].to_i
      when 'postgresql'
        res = execute("UPDATE zips SET zip=zip+1 WHERE site_id = #{site_id} RETURNING zip").first
        if res.nil?
          # error
          raise Zena::BadConfiguration, "no zip entry for (#{site_id})"
        end
        res['zip'].to_i
      when 'sqlite3'
        # FIXME: is there a way to make this thread safe and atomic (like it is with mysql) ?
        res = update "UPDATE zips SET zip=zip+1 WHERE site_id = '#{site_id}'"
        if res == 0
          # error
          raise Zena::BadConfiguration, "no zip entry for (#{site_id})"
        end
        fetch_attribute("SELECT zip FROM zips WHERE site_id = '#{site_id}'").to_i
      else
        raise Exception.new("Database Adapter #{adapter.inspect} not supported yet (you can probably fix this).")
      end
    end

    # Return a string matching the pseudo sql function.
    def sql_function(function, key)
      return key unless function
      res = case adapter
      when 'mysql'
        case function
        when 'year'
          "year(#{key})"
        when 'month'
          "date_format(#{key},'%Y-%m')"
        when 'week'
          "date_format(#{key},'%Y-%v')"
        when 'day'
          "DATE(#{key})"
        when 'random'
          'RAND()'
        end
      when 'sqlite3'
        case function
        when 'year'
          # we multiply by '1' to force a cast to INTEGER so that comparaison against
          # numbers works.
          "strftime('%Y', #{key})*1"
        when 'month'
          "strftime('%Y-%m', #{key})"
        when 'week'
          "strftime('%Y-%W', #{key})"
        when 'day'
          "DATE(#{key})"
        when 'random'
          'random()'
        end
      end
      raise Exception.new("Database Adapter #{adapter.inspect} does not support function #{function.inspect}.") unless res
      res
    end

    # This is used by zafu and it's a mess.
    # ref_date can be a string ('2005-05-03') or ruby ('Time.now'). It should not come uncleaned from evil web.
    def date_condition(date_cond, field, ref_date)
      case adapter
      when 'mysql'
        case date_cond
        when 'today', 'current', 'same'
          "DATE(#{field}) = DATE(#{ref_date})"
        when 'week'
          "date_format(#{ref_date},'%Y-%v') = date_format(#{field}, '%Y-%v')"
        when 'month'
          "date_format(#{ref_date},'%Y-%m') = date_format(#{field}, '%Y-%m')"
        when 'year'
          "date_format(#{ref_date},'%Y') = date_format(#{field}, '%Y')"
        when 'upcoming'
          "#{field} >= #{ref_date}"
        else
          # '2008-01-31 23:50' + INTERVAL 1 hour
          if date_cond =~ /^(\+|-|)\s*(\d+)\s*(second|minute|hour|day|week|month|year)/
            count = $2.to_i
            if $1 == ''
              # +/-
              "#{field} > #{ref_date} - INTERVAL #{count} #{$3.upcase} AND #{field} < #{ref_date} + INTERVAL #{count} #{$3.upcase}"
            elsif $1 == '+'
              # x upcoming days
              "#{field} > #{ref_date} AND #{field} < #{ref_date} + INTERVAL #{count} #{$3.upcase}"
            else
              # x days in the past
              "#{field} < #{ref_date} AND #{field} > #{ref_date} - INTERVAL #{count} #{$3.upcase}"
            end
          end
        end
      when 'sqlite3'
        case date_cond
        when 'today', 'current', 'same'
          "DATE(#{field}) = DATE(#{ref_date})"
        when 'week'
          "strftime('%Y-%W', #{ref_date}) = strftime('%Y-%W', #{field})"
        when 'month'
          "strftime('%Y-%m', #{ref_date}) = strftime('%Y-%m', #{field})"
        when 'year'
          # we multiply by '1' to force a cast to INTEGER so that comparaison against
          # numbers works.
          "strftime('%Y', #{ref_date}) = strftime('%Y', #{field})"
        when 'upcoming'
          "#{field} >= #{ref_date}"
        else
          # date('2008-01-31 23:50','+1 hour')
          if date_cond =~ /^(\+|-|)\s*(\d+)\s*(second|minute|hour|day|week|month|year)/
            count = $2.to_i
            if $1 == ''
              # +/-
              "#{field} > DATE(#{ref_date}, '-#{count} #{$3.upcase}') AND #{field} < DATE(#{ref_date}, '+#{count} #{$3.upcase}')"
            elsif $1 == '+'
              # x upcoming days
              "#{field} > #{ref_date} AND #{field} < DATE(#{ref_date}, '+#{count} #{$3.upcase}')"
            else
              # x days in the past
              "#{field} < #{ref_date} AND #{field} > DATE(#{ref_date}, '-#{count} #{$3.upcase}')"
            end
          end
        end
      else
        raise Exception.new("Database Adapter #{adapter.inspect} not supported yet (you can probably fix this).")
      end

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

    # Return true if we can load models because the database has the basic tables.
    def migrated_once?
      connection.tables.include?('nodes')
    end
  end # Db
end # Zena