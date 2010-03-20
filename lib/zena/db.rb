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
      NOW = 'now()'
    when 'sqlite3'
      NOW = "datetime('now')"
    end

    def set_attribute(obj, key, value)
      obj.send("#{key}=", value)
      execute "UPDATE #{obj.class.table_name} SET #{key}=#{quote(value)} WHERE id=#{obj[:id]}"
      obj.send(:changed_attributes).delete(key)
    end

    def quote(value)
      connection.quote(value)
    end

    def adapter
      ActiveRecord::Base.configurations[RAILS_ENV]['adapter']
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
      when 'mysql', 'postgresql'
        execute "UPDATE #{tbl1},#{tbl2} SET #{tbl1}.#{fld1}=#{tbl2}.#{fld2} WHERE #{opts[:where]}"
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
      when 'mysql', 'postgresql'
        execute "ALTER IGNORE TABLE #{table} ADD UNIQUE KEY(#{keys})"
      when 'sqlite3'
        execute "CREATE UNIQUE INDEX IF NOT EXISTS #{(table + keys).gsub(/[^\w]/,'')} ON #{table} (#{keys})"
      else
        raise Exception.new("Database Adapter #{adapter.inspect} not supported yet (you can probably fix this).")
      end
    end

    # 'DELETE' depending on a two table query.
    def delete(table, opts)
      tbl1, tbl2 = opts[:from]
      fld1, fld2 = opts[:fields]
      case adapter
      when 'mysql', 'postgresql'
        execute "DELETE #{table} FROM #{opts[:from].join(',')} WHERE #{tbl1}.#{fld1} = #{tbl2}.#{fld2} AND #{opts[:where]}"
      when 'sqlite3'
        execute "DELETE FROM #{table} WHERE #{fld1} = (SELECT #{fld2} FROM #{tbl2} WHERE #{opts[:where]})"
      else
        raise Exception.new("Database Adapter #{adapter.inspect} not supported yet (you can probably fix this).")
      end
    end

    # Insert a list of values (multicolumn insert). The values should be properly escaped before
    # being passed to this method.
    def insert_many(table, columns, values)
      values = values.compact.uniq
      case adapter
      when 'sqlite3'
        pre_query = "INSERT INTO #{table} (#{columns.join(',')}) VALUES "
        values.each do |v|
          execute pre_query + "(#{v.join(',')})"
        end
      else
        values = values.map {|v| "(#{v.join(',')})"}.join(', ')
        execute "INSERT INTO #{table} (#{columns.map{|c| "`#{c}`"}.join(',')}) VALUES #{values}"
      end
    end

    # Fetch a single row of raw data from db
    def fetch_row(sql)
      case adapter
      when 'sqlite3'
        res = execute(sql)
        res.empty? ? nil : res.first[0]
      when 'mysql'
        res = execute(sql).fetch_row
        res ? res[0] : nil
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

    def fetch_attribute(attribute, sql)
      unless sql =~ /SELECT/i
        sql = "SELECT `#{attribute}` FROM #{table_name} WHERE #{sql}"
      end
      Zena::Db.fetch_row(sql)
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
      when 'sqlite3'
        # FIXME: is there a way to make this thread safe and atomic (like it is with mysql) ?
        update "UPDATE zips SET zip=zip+1 WHERE site_id = '#{site_id}'"
        fetch_row("SELECT zip FROM zips WHERE site_id = '#{site_id}'").to_i
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
        end
      when 'sqlite3'
        case function
        when 'year'
          "strftime('%Y', #{key})*1"
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
    end
  end # Db
end # Zena