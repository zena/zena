module Zena
  module Use
    module Dates
      module Common
        
        # This is like strftime but with better support for i18n (translate day names, month abbreviations, etc)
        def format_date(thedate, theformat = nil, tz_name=nil, lang=visitor.lang)
          format = theformat || '%Y-%m-%d %H:%M:%S'
          return "" unless thedate
          if tz_name
            # display time local to event's timezone
            begin
              tz = TZInfo::Timezone.get(tz_name)
            rescue TZInfo::InvalidTimezoneIdentifier
              return "<span class='parser_error'>invalid timezone #{tz_name.inspect}</span>"
            end
          else
            tz = visitor.tz
          end
          if thedate.kind_of?(Time)
            utc_date = thedate
            adate = tz.utc_to_local(thedate)
          elsif thedate.kind_of?(String)
            begin
              adate    = Date.parse(thedate)
              utc_date = adate

            rescue
              # only return error if there is a format (without = used in sql query)
              return theformat ? "<span class='parser_error'>invalid date #{thedate.inspect}</span>" : Time.now.strftime('%Y-%m-%d %H:%M:%S')
            end
          else
            adate    = thedate
            utc_date = adate
          end

          # TODO: REFACTOR TO something like:
          # with_locale(lang) do
          # ...
          # end
          if visitor.lang != lang
            ::I18n.locale = lang
          end
          
          if format =~ /^age\/?(.*)$/
            format = $1.blank? ? _('long_date') : $1
            # how long ago/in how long is the date
            # FIXME: when using 'age', set expire_at (+1 minute, +1 hour, +1 day, never)
            age = (Time.now.utc - utc_date) / 60

            if age > 7 * 24 * 60
              # far in the past, use strftime
            elsif age >= 2 * 24 * 60
              # days
              return _("%{d} days ago") % {:d => (age/(24*60)).floor}
            elsif age >= 24 * 60
              # days
              return _("yesterday")
            elsif age >= 2 * 60
              # hours
              return _("%{h} hours ago") % {:h => (age/60).floor}
            elsif age >= 60
              return _("1 hour ago")
            elsif age > 2
              # minutes
              return _("%{m} minutes ago") % {:m => age.floor}
            elsif age > 0
              return _("1 minute ago")
            elsif age >= -1
              return _("in 1 minute")
            elsif age > -60
              return _("in %{m} minutes") % {:m => -age.ceil}
            elsif age > -2 * 60
              return _("in 1 hour")
            elsif age > -24 * 60
              return _("in %{h} hours") % {:h => -(age/60).ceil}
            elsif age > -2 * 24 * 60
              return _("tomorrow")
            elsif age > -7 * 24 * 60
              return _("in %{d} days") % {:d => -(age/(24*60)).ceil}
            else
              # too far in the future, use strftime
            end
          end

          # month name
          format = format.gsub("%b", _(adate.strftime("%b")) )
          format.gsub!("%B", _(adate.strftime("%B")) )

          # weekday name
          format.gsub!("%a", _(adate.strftime("%a")) )
          format.gsub!("%A", _(adate.strftime("%A")) )

          if visitor.lang != lang
            ::I18n.locale = visitor.lang
          end

          adate.strftime(format)
        end
          
      end # Common
      
      module ControllerMethods
        include Common
      end
      
      module ViewMethods
        include Common
        
        # display the time with the format provided by the translation of 'long_time'
        def long_time(atime)
          format_date(atime, _("long_time"))
        end

        # display the time with the format provided by the translation of 'short_time'
        def short_time(atime)
          format_date(atime, _("short_time"))
        end

        # display the time with the format provided by the translation of 'full_date'
        def full_date(adate)
          format_date(adate, _("full_date"))
        end

        # display the time with the format provided by the translation of 'long_date'
        def long_date(adate)
          format_date(adate, _("long_date"))
        end

        # display the time with the format provided by the translation of 'short_date'
        def short_date(adate)
          format_date(adate, _("short_date"))
        end

        # format a date with the given format. Translate month and day names.
        def tformat_date(thedate, fmt)
          format_date(thedate, _(fmt))
        end
      end # ViewMethods
      
      module AddParseDateAttributeMethod
        def parse_date_attribute(*args)
          args.each do |arg|
            define_method("#{arg}=") do |date|
              super(date.kind_of?(Time) ? date : date.to_utc(_('datetime'), visitor.tz))
            end
          end
        end
      end
      
      module ModelMethods
        def self.included(base)
          base.extend Zena::Use::Dates::AddParseDateAttributeMethod
        end
      end
      
      module StringMethods
        # Parse date : return an utc date from a string and an strftime format. With the current implementation, you can only use '.', '-', ' ' or ':' to separate the different parts in the format.
        def to_utc(format, timezone=nil)
          elements = split(/(\.|\-|\/|\s|:)+/)
          format = format.split(/(\.|\-|\/|\s|:)+/)
          if elements
            hash = {}
            elements.each_index do |i|
              hash[format[i]] = elements[i]
            end
            hash['%Y'] ||= hash['%y'] ? (hash['%y'].to_i + 2000) : Time.now.year
            hash['%H'] ||= 0
            hash['%M'] ||= 0
            hash['%S'] ||= 0
            if hash['%Y'] && hash['%m'] && hash['%d']
              res = Time.utc(hash['%Y'], hash['%m'], hash['%d'], hash['%H'], hash['%M'], hash['%S'])
              timezone ? timezone.local_to_utc(res) : res
            else
              nil
            end
          else
            nil
          end
        rescue ArgumentError
          nil
        end
        
        
        # Convert a string of the form '1 month 4 days' to the duration in seconds.
        # Valid formats are:
        # y : Y      : year : years
        # M : month  : months
        # d : day    : days
        # h : hour   : hours
        # m : minute : minutes
        # s : second : seconds  
        def to_duration
          res = 0
          val = 0
          split(/\s+/).map {|e| e =~ /^(\d+)([a-zA-Z]+)$/ ? [$1,$2] : e }.flatten.map do |e|
            if e =~ /[0-9]/
              val = e.to_i
            else
              if e[0..1] == 'mo'
                e = 'M'
              end
              res += val * case e[0..0]
              when 'y','Y'
                31536000
              when 'M'
                2592000
              when 'd'
                86400
              when 'h'
                3600
              when 'm'
                60
              when 's'
                1
              else
                0
              end
              val = 0
            end
          end
          res
        end
      end
    end # Dates
  end # Use
end # Zena

# FIXME: where should we put this ?
String.send(:include, Zena::Use::Dates::StringMethods)
