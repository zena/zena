module Zena
  module DbHelper
    class Sqlite3
      NOW         = "datetime('now')"
      TRUE        = '1'
      TRUE_RESULT = 't'
      FALSE       = '0'

      class << self
        # Singleton inheritence
        include Zena::DbHelper::AbstractDb
        def insensitive_find(klass, count, attributes)
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
        end

        def update_value(name, opts)
          tbl1, fld1 = name.split('.')
          tbl2, fld2 = opts[:from].split('.')
          execute "UPDATE #{tbl1} SET #{fld1} = (SELECT #{fld2} FROM #{tbl2} WHERE #{opts[:where]})"
        end

        def add_unique_key(table, keys)
          execute "CREATE UNIQUE INDEX IF NOT EXISTS #{([table] + keys).join('_').gsub(/[^\w]/,'')} ON #{table} (#{keys.join(', ')})"
        end

        # 'DELETE' depending on a two table query.
        def delete(table, opts)
          tbl1, tbl2 = opts[:from]
          fld1, fld2 = opts[:fields]
          execute "DELETE FROM #{table} WHERE #{fld1} = (SELECT #{fld2} FROM #{tbl2} WHERE #{opts[:where]})"
        end

        # Insert a list of values (multicolumn insert). The values should be properly escaped before
        # being passed to this method.
        def insert_many(table, columns, values)
          values = values.compact.uniq.map do |list|
            list.map {|e| quote(e)}
          end

          columns = columns.map{|c| quote_column_name(c)}.join(',')

          pre_query = "INSERT INTO #{table} (#{columns}) VALUES "
          values.each do |value|
            execute pre_query + "(#{value.join(',')})"
          end
        end

        # Fetch a single row of raw data from db
        def fetch_attribute(sql)
          res = execute(sql)
          res.empty? ? nil : res.first[0]
        end

        def next_zip(site_id)
          # FIXME: is there a way to make this thread safe and atomic (like it is with mysql) ?
          res = update "UPDATE zips SET zip=zip+1 WHERE site_id = '#{site_id}'"
          if res == 0
            # error
            raise Zena::BadConfiguration, "no zip entry for (#{site_id})"
          end
          fetch_attribute("SELECT zip FROM zips WHERE site_id = '#{site_id}'").to_i
        end

        # Return a string matching the SQLiss function.
        def sql_function(function, arg)
          return arg unless function
          case function
          when 'year'
            # we multiply by '1' to force a cast to INTEGER so that comparaison against
            # numbers works.
            "strftime('%Y', #{arg})*1"
          when 'month'
            "strftime('%Y-%m', #{arg})"
          when 'week'
            "strftime('%Y-%W', #{arg})"
          when 'day'
            "DATE(#{arg})"
          when 'random'
            'random()'
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
            else
              # bad date_cond
              nil
            end
          end
        end # date_condition
      end # class << self
    end # Sqlite3
  end # DbHelper
end # Zena