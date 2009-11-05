module Zafu
  module Dates
    def r_date
      select = @params[:select]
      case select
      when 'main'
        expand_with(:date=>'main_date')
      when 'now'
        expand_with(:date=>'Time.now')
      else
        if select =~ /^\d{4}-\d{1,2}-\d{1,2}$/
          begin
            d = Date.parse(select)
            expand_with(:date=>select.inspect)
          rescue
            parser_error("invalid date '#{select}' should be 'YYYY-MM-DD'")
          end
        elsif date = find_stored(Date, select)
          if date[0..0] == '"'
            begin
              d = Date.parse(date[1..-2])
              expand_with(:date=>date)
            rescue
              parser_error("invalid date #{select} (#{date}) should be 'YYYY-MM-DD'")
            end
          else
            expand_with(:date=>select)
          end
        elsif select =~ /\[(.*)\]/
          date, static = parse_attributes_in_value(select, :erb => false)
          expand_with(:date => "\"#{date}\"")
        else
          parser_error("bad parameter '#{select}'")
        end
      end
    end

    protected
      def current_date
        @context[:date] || 'main_date'
      end

      # This is used by zafu and it's a mess.
      # ref_date can be a string ('2005-05-03') or ruby ('Time.now'). It should not come uncleaned from evil web.
      def date_condition(date_cond, field, ref_date='today')
        if date_cond == 'today' || ref_date == 'today'
          ref_date = Zena::Db::NOW
        elsif ref_date =~ /(\d{4}-\d{1,2}-\d{1,2}( \d{1,2}:\d{1,2}(:\d{1,2})?)?)/
          ref_date = "'#{$1}'"
        elsif ref_date =~ /\A"/
          ref_date = "'\#{format_date(#{ref_date})}'"
        else
          ref_date = "'\#{#{ref_date}.strftime('%Y-%m-%d %H:%M:%S')}'"
        end
        Zena::Db.date_condition(date_cond, field, ref_date)
      end
  end # Dates
end # Zafu