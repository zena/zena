module Zena
  module Use
    module I18n
      module Common
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
      end
      
      module ViewMethods
        def self.include(base)
          base.send(:alias_method_chain, :will_paginate, :i18n)
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
          NodesController.send(:_,str)
        end

        # Show a little [xx] next to the title if the desired language could not be found. You can
        # use a :text => '(lang)' option. The word 'lang' will be replaced by the real value.
        def check_lang(obj, opts={})
          wlang = (opts[:text] || '[#LANG]').sub('#LANG', obj.v_lang).sub('_LANG', _(obj.v_lang))
          obj.v_lang != lang ? "<#{opts[:wrap] || 'span'} class='#{opts[:class] || 'wrong_lang'}'>#{wlang}</#{opts[:wrap] || 'span'}>" : ""
        end

      end # ViewMethods
      
    end # I18n
  end # Use
end # Zena