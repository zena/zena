module Zena
  module DbHelper
    # Singleton to help with database queries.
    class Mysql
      NOW         = 'now()'
      TRUE        = '1'
      TRUE_RESULT = '1'
      FALSE       = '0'

      class << self
        # Singleton inheritence
        include Zena::DbHelper::AbstractDb

        def add_column(table, column_name, type, opts={})
          # Force the use of :longtext instead of :text
          if type == :text
            execute "ALTER TABLE #{table} ADD COLUMN #{column_name} LONGTEXT"
          else
            super
          end
        end

        def change_column(table, column_name, type, opts={})
          if type == :text
            execute "ALTER TABLE #{table} CHANGE COLUMN #{column_name} #{column_name} LONGTEXT"
          else
            super
          end
        end

        def quote_date(date)
          if date.kind_of?(Time)
            date.strftime('%Y%m%d%H%M%S')
          else
            "''"
          end
        end

        def table_options
          'type=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci'
        end

        def update_value(name, opts)
          tbl1, fld1 = name.split('.')
          tbl2, fld2 = opts[:from].split('.')
          execute "UPDATE #{tbl1},#{tbl2} SET #{tbl1}.#{fld1}=#{tbl2}.#{fld2} WHERE #{opts[:where]}"
        end

        def change_engine(table, engine)
          execute "ALTER TABLE #{table} ENGINE = #{engine}"
        end

        def add_unique_key(table, keys)
          execute "ALTER IGNORE TABLE #{table} ADD UNIQUE KEY(#{keys.join(', ')})"
        end

        # 'DELETE' depending on a two table query.
        def delete(table, opts)
          tbl1, tbl2 = opts[:from]
          fld1, fld2 = opts[:fields]
          execute "DELETE #{table} FROM #{opts[:from].join(',')} WHERE #{tbl1}.#{fld1} = #{tbl2}.#{fld2} AND #{opts[:where]}"
        end

        # Fetch a single row of raw data from db
        def fetch_attribute(sql)
          res = execute(sql).fetch_row
          res ? res.first : nil
        end

        def next_zip(site_id)
          res = update "UPDATE zips SET zip=@zip:=zip+1 WHERE site_id = '#{site_id}'"
          if res == 0
            # error
            raise Zena::BadConfiguration, "no zip entry for (#{site_id})"
          end
          rows = execute "SELECT @zip"
          rows.fetch_row[0].to_i
        end

        # Return a string matching the pseudo sql function.
        def sql_function(function, key)
          return key unless function
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
          else
            super
          end
        end

        # This is used by zafu and it's a mess.
        # ref_date can be a string ('2005-05-03') or ruby ('Time.now'). It should not come uncleaned from evil web.
        def date_condition(date_cond, field, ref_date)
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
            else
              # bad date_cond
              nil
            end
          end
        end # date_condition


        def prepare_connection_for_timezone
          # Fixes timezone to "+0:0"
          raise "prepare_connection_for_timezone executed too late, connection already active." if Class.new(ActiveRecord::Base).connected?

          ActiveRecord::ConnectionAdapters::MysqlAdapter.class_eval do
            def configure_connection_with_timezone
              configure_connection_without_timezone
              tz = ActiveRecord::Base.default_timezone == :utc ? "+0:0" : "SYSTEM"
              execute("SET time_zone = '#{tz}'")
            end
            alias_method_chain :configure_connection, :timezone
          end
        end
      end # class << self
    end # Mysql
  end # DbHelper
end # Zena