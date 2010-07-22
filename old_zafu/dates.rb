module Zafu
  module Dates
    protected

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