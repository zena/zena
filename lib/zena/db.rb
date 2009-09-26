# FIXME: we should patch the connection adapters instead of having 'case, when' evaluated each time
module Zena
  module Db
    extend self

    # constants
    case ActiveRecord::Base.configurations[RAILS_ENV]['adapter']
    when 'mysql'
      NOW = 'now()'
    when 'sqlite3'
      NOW = "date('now')"
    end


    def adapter
      ActiveRecord::Base.configurations[RAILS_ENV]['adapter']
    end

    def execute(*args)
      ActiveRecord::Base.connection.execute(*args)
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

    # Escape a list of values for multicolumn insert.
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
        execute "INSERT INTO #{table} (#{columns.join(',')}) VALUES #{values}"
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
        res ? res[0].to_i : nil
      else
        raise Exception.new("Database Adapter #{adapter.inspect} not supported yet (you can probably fix this).")
      end
    end
  end # Db
end # Zena