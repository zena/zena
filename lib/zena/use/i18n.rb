module Zena
  module Use
    module I18n
      module Common

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

      module FormatDate

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
      end

      module ControllerMethods
        include Common

        def self.included(base)
          FastGettext.add_text_domain 'zena', :path => "#{Zena::ROOT}/locale"
          base.prepend_before_filter { FastGettext.text_domain = 'zena' }
          base.before_filter :set_lang, :check_lang
          base.after_filter  :set_encoding
        end

        # Choose best language to display content.
        # 1. 'test.host/oo?lang=en' use 'lang', redirect without lang
        # 3. 'test.host/oo' use visitor[:lang]
        # 4. 'test.host/'   use session[:lang]
        # 5. 'test.host/oo' use visitor lang
        # 6. 'test.host/'   use HTTP_ACCEPT_LANGUAGE
        # 7. 'test.host/'   use default language
        #
        # 8. 'test.host/fr' the redirect for this rule is called once we are sure the request is not for document data (lang in this case can be different from what the visitor is visiting due to caching optimization)
        def set_lang
          if params[:prefix] =~ /^\d+$/
            # this has nothing to do with set_lang...
            # 'test.host/34' --> /en/node34.html
            redirect_to "/#{prefix}/#{params[:prefix]}"
            return false
          end

          chosen_lang = nil
          [
            params[:lang],
            visitor.is_anon? ? session[:lang] : visitor.lang,
            (request.headers['HTTP_ACCEPT_LANGUAGE'] || '').split(',').sort {|a,b| (b.split(';q=')[1] || 1.0).to_f <=> (a.split(';q=')[1] || 1.0).to_f }.map {|l| l.split(';')[0].split('-')[0] },
            (visitor.is_anon? ? visitor.lang : nil), # anonymous user's lang comes last
          ].compact.flatten.uniq.each do |l|
            if current_site.lang_list.include?(l)
              chosen_lang = l
              break
            end
          end

          set_visitor_lang(chosen_lang || current_site[:default_lang])
          true
        end

        def set_visitor_lang(l)
          return unless current_site.lang_list.include?(l)
          session[:lang] = l

          if visitor.lang != l && !visitor.is_anon?
            visitor.update_attribute('lang', l)
          else
            visitor.lang = l
          end

          if File.exist?("#{Zena::ROOT}/locale/#{l}/LC_MESSAGES/zena.mo")
            ::I18n.locale = l
          else
            ::I18n.locale = 'en'
          end
        end

        # Redirect on lang change "...?lang=de"
        def check_lang
          if params[:lang]
            # redirects other controllers (users controller, etc)
            redirect_url = params
            redirect_url.delete(:lang)
            if params[:controller] == 'nodes'
              redirect_to redirect_url.merge(:prefix => prefix) and return false
            else
              redirect_to redirect_url and return false
            end
          end
          true
        end

        def set_encoding
          headers['Content-Type'] ||= 'text/html'
          if headers['Content-Type'].starts_with?('text/') and !headers['Content-Type'].include?('charset=')
            headers['Content-Type'] += '; charset=utf-8'
          end
        end

      end

      module ViewMethods
        def self.included(base)
          base.send(:alias_method_chain, :will_paginate, :i18n) if base.respond_to?(:will_paginate)
        end

        include Common
        include FormatDate

        # Enable translations for will_paginate
        def will_paginate_with_i18n(collection, options = {})
          will_paginate_without_i18n(collection, options.merge(:prev_label => _('img_prev_page'), :next_label => _('img_next_page')))
        end

        # translation of static text using gettext
        # FIXME: I do not know why this is needed in order to have <%= _('blah') %> find the translations on some servers
        def _(str)
          ApplicationController.send(:_, str)
        end

        # Show a little [xx] next to the title if the desired language could not be found. You can
        # use a :text => '(lang)' option. The word 'lang' will be replaced by the real value.
        def check_lang(obj, opts={})
          wlang = (opts[:text] || '[#LANG]').sub('#LANG', obj.version.lang).sub('_LANG', _(obj.version.lang))
          obj.version.lang != lang ? "<#{opts[:wrap] || 'span'} class='#{opts[:class] || 'wrong_lang'}'>#{wlang}</#{opts[:wrap] || 'span'}>" : ""
        end

      end # ViewMethods

    end # I18n
  end # Use
end # Zena