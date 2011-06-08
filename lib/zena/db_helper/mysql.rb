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
          'type=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci'
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

        # Return a string matching the SQLiss function.
        def sql_function(function, arg)
          return arg unless function
          case function
          when 'year'
            "year(#{arg})"
          when 'month'
            "date_format(#{arg},'%Y-%m')"
          when 'week'
            "date_format(#{arg},'%Y-%v')"
          when 'day'
            "DATE(#{arg})"
          when 'random'
            'RAND()'
          else
            super
          end
        end

        # This is used by zafu and it's a mess.
        # ref_date can be a string ('2005-05-03') or ruby ('Time.now'). It should not come uncleaned from evil web.
        def date_condition(date_cond, field, ref_date)
          # raise "DEPRECATED"
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

        # Deadlock retry
        DEADLOCK_REGEX = %r{Deadlock found when trying to get lock}
        DEADLOCK_MAX_RETRY = 3

        def prepare_connection
          # Fixes timezone to "+0:0"
          raise "prepare_connection executed too late, connection already active." if Class.new(ActiveRecord::Base).connected?

          ActiveRecord::ConnectionAdapters::MysqlAdapter.class_eval do
            def configure_connection_with_zena
              configure_connection_without_zena
              tz = ActiveRecord::Base.default_timezone == :utc ? "+0:0" : "SYSTEM"
              execute("SET time_zone = '#{tz}'")
              execute("SET collation_connection = 'utf8_unicode_ci'")
            end
            alias_method_chain :configure_connection, :zena
          end

          class << ActiveRecord::Base
            def transaction_with_deadlock_retry(*args, &block)
              retry_count = 0

              begin
                transaction_without_deadlock_retry(*args, &block)
              rescue ActiveRecord::StatementInvalid => error
                # Raise if we are in a nested transaction
                raise if connection.open_transactions != 0
                if error.message =~ DEADLOCK_REGEX
                  retry_count += 1
                  if retry_count < DEADLOCK_MAX_RETRY
                    Node.logger.warn "#{Time.now.strftim('%Y-%m-%d %H:%M:%S')} [#{current_site.host}] Retry (#{retry_count}) #{error.message}"
                    retry
                  else
                    raise
                  end
                else
                  # Not a deadlock error
                  raise
                end
              end
            end
            alias_method_chain :transaction, :deadlock_retry
          end # class << ActiveRecord::Base
        end # prepare_connection
      end # class << self
    end # Mysql
  end # DbHelper
end # Zena