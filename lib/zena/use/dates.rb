require 'tzinfo'

module Zena
  module Use
    module Dates
      ISO_DATE_FORMAT = '%Y-%m-%dT%H:%M:%S'
      module Common

        # This is like strftime but with better support for i18n (translate day names, month abbreviations, etc)
        def format_date(thedate, opts = {})
          return '' if thedate.blank?

          theformat, tz_name, lang = opts[:format], opts[:tz], opts[:lang]
          format = theformat || _('datetime')

          if tz_name
            if tz_name.kind_of?(TZInfo::Timezone)
              tz = tz_name
            else
              # display time local to event's timezone
              begin
                tz = TZInfo::Timezone.get(tz_name)
              rescue TZInfo::InvalidTimezoneIdentifier
                return "<span class='parser_error'>invalid timezone #{tz_name.inspect}.</span>"
              end
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
              return "<span class='parser_error'>invalid date #{thedate.inspect}</span>"
            end
          else
            adate    = thedate
            utc_date = adate
          end

          # TODO: REFACTOR TO something like:
          # with_locale(lang) do
          # ...
          # end
          if lang
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

          if lang
            # Restore
            ::I18n.locale = visitor.lang
          end

          adate.strftime(format)
        end

      end # Common

      module ControllerMethods
        include Common
      end

      module FormTags
        # Date selection tool.
        # TODO: make it work with form_helper: <%= f.date_box(:event_at) %>
      	def date_box(obj, name, opts = {})
      	  rnd_id = rand(100000000000)
      	  defaults = {  :id=>"datef#{rnd_id}", :button=>"dateb#{rnd_id}", :display=>"dated#{rnd_id}" }
      	  opts = defaults.merge(opts)
      	  date = opts[:value] || obj.safe_send(name)
      	  showsTime = opts[:time] || 'true'
      	  # TODO: could we pass the format from the view so that it is
      	  # translated with the view's dictionary during compilation ?
      	  dateFormat = showsTime == 'true' ? _('datetime') : _('long_date')
      	  value = format_date(date, :format => dateFormat)

      	  # TODO: migrate code to Zafu::Markup (needs Zafu 0.7.7)
      	  # fld = Zafu::Markup.new('input')
      	  # fld.params = (opts[:html] || {}).merge(:name => "node[#{name}]", :id => opts[:id], :type => 'text', :value => value)
      	  if opts[:size]
            fld = "<input id='#{opts[:id]}' name='node[#{name}]' type='text' size='#{opts[:size]}' value='#{value}' class='#{opts[:class]}'/>"
          else
            fld = "<input id='#{opts[:id]}' name='node[#{name}]' type='text' value='#{value}' class='#{opts[:class]}'/>"
          end

          js_data << %Q{Calendar.setup({
              inputField  : "#{opts[:id]}",      // id of the input field
              button      : "#{opts[:button]}",  // trigger for the calendar (button ID)
              singleClick : true,
              showsTime   : #{showsTime},
              ifFormat    : '#{dateFormat}'
          });}

      		<<-EOL
      <span class="date_box"><img src="/calendar/iconCalendar.gif" id="#{opts[:button]}" alt='#{_('date selection')}'/>
      #{fld}</span>
      		EOL
      	end
      end

      module ViewMethods
        include Common
        include FormTags

        # default date used to filter events in templates
        def main_date(tz = visitor.tz)
          @main_dates ||= {}
          @main_dates[tz] ||= begin
            if params[:date]
              if date = params[:date].to_utc(ISO_DATE_FORMAT, tz)
                date
              else
                # FIXME: when date parsing fails: show an error, not a 500...
                Node.logger.warn "Could not parse 'date' parameter: #{params[:date].inspect}."
                # malformed url... 404 ?
                Time.now.utc
              end
            else
              # no 'date' parameter
              Time.now.utc
            end
          end
        end

        def parse_date(string, format = nil, tz = nil)
          return nil unless string
          format = _('datetime') if format.blank?
          tz     = visitor.tz if tz.blank?
          string.to_utc(format, visitor.tz)
        end
      end # ViewMethods

      # FIXME: remove from other models (has been removed from Node) !
      module AddParseDateAttributeMethod
        def parse_date_attribute(*args)
          args.each do |arg|
            define_method("#{arg}=") do |date|
              super(date.kind_of?(String) ? date.to_utc(_('datetime'), visitor.tz) : date)
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
        SPLIT_STRING = /[^0-9]+/
        SPLIT_FORMAT = /[^\w%]*%/
        # Parse date : return an utc date from a string and an strftime format. With the current implementation, you can only use '.', '-', ' ' or ':' to separate the different parts in the format.
        def to_utc(format, timezone=nil)
          elements = split(SPLIT_STRING)
          format = format.sub('T', ' ').split(SPLIT_FORMAT)[1..-1]
          if elements
            hash = {}
            elements.each_index do |i|
              hash[format[i]] = elements[i]
            end
            hash['Y'] ||= hash['y'] ? (hash['y'].to_i + 2000) : Time.now.year
            hash['H'] ||= 0
            hash['M'] ||= 0
            hash['S'] ||= 0
            if hash['Y'] && hash['m'] && hash['d']
              res = Time.utc(hash['Y'], hash['m'], hash['d'], hash['H'], hash['M'], hash['S'])
              begin
                timezone ? timezone.local_to_utc(res, true) : res
              rescue TZInfo::AmbiguousTime
                # Better a bad date then nothing
                res
              end
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

      module TimeMethods

        def strftime_tz(format, tz = nil)
          if tz.blank?
            tz = visitor.tz
          elsif tz.kind_of?(String)
            tz = TZInfo::Timezone.get(tz)
          end
          tz.utc_to_local(self).strftime(format.to_s)
        rescue TZInfo::InvalidTimezoneIdentifier
          ''
        rescue TZInfo::AmbiguousTime
          ''
        end
      end

      module ZafuMethods
        include RubyLess
        safe_method_for Time, :year       => {:class => Number, :pre_processor => true}
        safe_method_for Time, [:strftime, String] => {:class => String, :pre_processor => true, :method => 'strftime_tz'}
        safe_method_for Time, [:strftime, String, String] => {:class => String, :pre_processor => true, :method => 'strftime_tz'}
        safe_method_for Time, [:strftime, String, TZInfo::Timezone] => {:class => String, :pre_processor => true, :method => 'strftime_tz'}
        safe_method_for TZInfo::Timezone, :to_s => {:class => String, :pre_processor => true}

        safe_method :date                     => :get_date
        safe_method [:date, TZInfo::Timezone] => :get_date
        safe_method :tz                       => :get_tz
        safe_method [:parse_date, String]     => {:class => Time, :nil => true, :accept_nil => true}
        safe_method [:parse_date, String, String] => {:class => Time, :nil => true, :accept_nil => true}
        safe_method [:parse_date, String, String, TZInfo::Timezone] => {:class => Time, :nil => true, :accept_nil => true}

        def get_date(signature)
          if var = get_context_var('set_var', 'date')
            {:class => var.klass, :method => var, :nil => var.could_be_nil?}
          else
            {:class => Time, :method => 'main_date'}
          end
        end

        def get_tz(signature)
          if var = get_context_var('set_var', 'tz')
            {:class => var.klass, :method => var, :nil => var.could_be_nil?}
          else
            {:class => TZInfo::Timezone, :method => 'visitor.tz'}
          end
        end

        def r_default
          if tz_name = @params.delete(:tz)
            set_tz_code, tz_var = set_tz_var(tz_name)
            out set_tz_code
          end
          super
        end


        # date_box seizure setup
        def r_uses_datebox
          if ZENA_CALENDAR_LANGS.include?(visitor.lang)
            l = visitor.lang
          else
            l = visitor.site[:default_lang]
          end
<<-EOL
<script src="#{helper.send(:compute_public_path, 'calendar', 'calendar', 'js')}" type="text/javascript"></script>
<script src="#{helper.send(:compute_public_path, 'calendar-setup', 'calendar', 'js')}" type="text/javascript"></script>
<script src="#{helper.send(:compute_public_path, "calendar-#{l}-utf8", 'calendar/lang', 'js')}" type="text/javascript"></script>
<link href="#{helper.send(:compute_public_path, "calendar-brown", 'calendar', 'css')}" media="screen" rel="Stylesheet" type="text/css" />
<% js_data << %Q{Calendar._TT["DEF_DATE_FORMAT"] = "#{_('datetime')}";} -%>
<% js_data << %Q{Calendar._TT["FIRST_DAY"] = #{_('week_start_day')};} -%>
EOL
        end

        # Select a date for the current context
        # FIXME: Remove ? Is this used ?
        # def r_set_main_date
        #   return nil unless code = get_attribute_or_eval
        #
        #   if format = @params[:format]
        #     format = RubyLess.translate_string(self, format)
        #   else
        #     format = "'%Y-%m-%d %H:%M:%S'"
        #   end
        #
        #   if code.klass <= String
        #     if code.could_be_nil?
        #       code = "(#{code} || '').to_utc(#{format})"
        #     else
        #       code = "#{code}.to_utc(#{format})"
        #     end
        #     could_be_nil = true
        #   elsif code.klass <= Time
        #     could_be_nil = code.could_be_nil?
        #   else
        #     return parser_error("should evaluate to a String or Time (found #{code.klass})")
        #   end
        #   v = get_var_name('set_var', 'date')
        #   out "<% #{v} = #{code} %>"
        #   set_context_var('set_var', 'date', RubyLess::TypedString.new(v, :class => Time, :nil => could_be_nil))
        #   out expand_with
        # end

        protected

          def set_tz_var(tz_name)
            tz = TZInfo::Timezone.get(tz_name)
            tz_var = get_var_name('dates', 'tz')

            set_context_var('set_var', 'tz', RubyLess::TypedString.new(
              tz_var,
              :class => TZInfo::Timezone
            ))
            return "<% #{tz_var} = TZInfo::Timezone.get(#{tz.name.inspect}) %>", tz_var
          rescue TZInfo::InvalidTimezoneIdentifier
            parser_error("Invalid timezone #{tz_name.inspect}.")
          end

          def show_time(method)
            if tformat = param(:tformat)
              tformat = RubyLess.translate(self, "t(%Q{#{tformat}})")
              method = "#{method}, :format => #{tformat}"
            end

            if hash_arguments = extract_from_params(:tz, :lang, :format)
              unless @params[:tz]
                # We might have set_tz_var
                if tz = get_context_var('set_var', 'tz')
                  if tz.klass <= TZInfo::Timezone || tz.klass <= String
                    hash_arguments << ":tz => #{tz}"
                  end
                end
              end
              "<%= format_date(#{method}, #{hash_arguments.join(', ')}) %>"
            elsif tformat
              "<%= format_date(#{method}) %>"
            else
              "<%= #{method} %>"
            end
          end
      end # ZafuMethods
    end # Dates
  end # Use
end # Zena

# FIXME: where should we put this ?
String.send(:include, Zena::Use::Dates::StringMethods)

# FIXME: where should we put this ?
Time.send(:include, Zena::Use::Dates::TimeMethods)