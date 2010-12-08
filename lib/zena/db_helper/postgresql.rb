module Zena
  module DbHelper
    # Singleton to help with database queries.
    class Postgresql
      NOW         = 'now()'
      TRUE        = 'true'
      TRUE_RESULT = 't'
      FALSE       = 'false'

      class << self
        # Singleton inheritence
        include Zena::DbHelper::AbstractDb
        def insensitive_find(klass, count, attributes)
          cond = [[]]
          attributes.each do |attribute, value|
            cond[0] << (value.kind_of?(String) ? "#{attribute} ILIKE ?" : "#{attribute} = ?")
            cond << value
          end
          cond[0] = cond[0].join(' AND ')
          klass.find(count, :conditions => cond)
        end

        def update_value(name, opts)
          tbl1, fld1 = name.split('.')
          tbl2, fld2 = opts[:from].split('.')
          execute "UPDATE #{tbl1} SET #{fld1}=#{tbl2}.#{fld2} FROM #{tbl2} WHERE #{opts[:where]}"
        end

        def add_unique_key(table, keys)
          execute "ALTER TABLE #{table} ADD CONSTRAINT #{keys.join('_')} UNIQUE (#{keys.join(', ')})"
        end

        # 'DELETE' depending on a two table query.
        def delete(table, opts)
          tbl1, tbl2 = opts[:from]
          fld1, fld2 = opts[:fields]
          using = opts[:from].reject {|t| t == table}
          execute "DELETE FROM #{table} USING #{using.join(', ')} WHERE #{tbl1}.#{fld1} = #{tbl2}.#{fld2} AND #{opts[:where]}"
        end

        # Fetch a single row of raw data from db
        def fetch_attribute(sql)
          res = connection.select_rows(sql)
          res.empty? ? nil : res.first.first
        end

        def next_zip(site_id)
          res = execute("UPDATE zips SET zip=zip+1 WHERE site_id = #{site_id} RETURNING zip").first
          if res.nil?
            # error
            raise Zena::BadConfiguration, "no zip entry for (#{site_id})"
          end
          res['zip'].to_i
        end

        # Return a string matching the sqless function.
        def sql_function(function, key)
          return key unless function
          # TODO
          super
        end

        def prepare_connection_for_timezone
          # Fixes timezone to "+0:0"
          raise "prepare_connection_for_timezone executed too late, connection already active." if Class.new(ActiveRecord::Base).connected?

          ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.class_eval do
            def configure_connection_with_timezone
              configure_connection_without_timezone
              tz = ActiveRecord::Base.default_timezone == :utc ? "UTC" : "SYSTEM"
              execute("SET TIMEZONE = '#{tz}'")
            end
            alias_method_chain :configure_connection, :timezone
          end
        end
      end # class << self
    end # Postgresql
  end # DbHelper
end # Zena