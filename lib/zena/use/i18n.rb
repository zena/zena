module Zena
  module Use
    # On load this module changes ENV['LANG'] to 'C' in order to behave consitently without
    # strange bugs when the locale is changed.
    module I18n
      ::ENV['LANG'] = 'C'

      module FormatDate

        # display the time with the format provided by the translation of 'long_time'
        def long_time(atime)
          format_date(atime, :format => _("long_time"))
        end

        # display the time with the format provided by the translation of 'short_time'
        def short_time(atime)
          format_date(atime, :format => _("short_time"))
        end

        # display the time with the format provided by the translation of 'full_date'
        def full_date(adate)
          format_date(adate, :format => _("full_date"))
        end

        # display the time with the format provided by the translation of 'long_date'
        def long_date(adate)
          format_date(adate, :format => _("long_date"))
        end

        # display the time with the format provided by the translation of 'short_date'
        def short_date(adate)
          format_date(adate, :format => _("short_date"))
        end

        # format a date with the given format. Translate month and day names.
        def tformat_date(thedate, fmt)
          format_date(thedate, :format => _(fmt))
        end
      end

      module ControllerMethods

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
            params[:node] ? params[:node][:v_lang] : nil,
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
        include RubyLess
        translate = { :class  => String,
                      :method => 'trans',
                      :pre_processor => Proc.new {|str| self.rubyless_translate(str)}
                    }
        safe_method [:trans, String] => translate
        safe_method [:t,     String] => translate
        safe_method [:lang_links, {:wrap => String, :join => String}] => String

        def self.included(base)
          base.send(:alias_method_chain, :will_paginate, :i18n) if base.respond_to?(:will_paginate)
        end

        include FormatDate

        # Enable translations for will_paginate
        def will_paginate_with_i18n(collection, options = {})
          will_paginate_without_i18n(collection, options.merge(:prev_label => _('img_prev_page'), :next_label => _('img_next_page')))
        end

        def self.rubyless_translate(str)
          str = str.kind_of?(Hash) ? str['text'] : str
          ApplicationController.send(:_, str)
        end

        # translation of static text using gettext
        # FIXME: I do not know why this is needed in order to have <%= _('blah') %> find the translations on some servers
        def _(str)
          ApplicationController.send(:_, str)
        end

        def trans(str)
          ApplicationController.send(:_, str)
        end


        # show language selector
        def lang_links(opts={})
          if opts[:wrap]
            tag_in  = "<#{opts[:wrap]}>"
            tag_out = "</#{opts[:wrap]}>"
          else
            tag_in = tag_out = ''
          end
          res = []
          visitor.site.lang_list.each do |l|
            if l == visitor.lang
              if opts[:wrap]
                res << "<#{opts[:wrap]} class='on'>#{l}" + tag_out
              else
                res << "<em>#{l}</em>"
              end
            else
              if params[:controller] == 'nodes'
                res << tag_in + "<a href='#{zen_path(@node, :lang => l)}'>#{l}</a>"
              else
                res << tag_in + link_to(l, params.merge(:lang => l)) + tag_out
              end
            end
          end
          res.join(opts[:join] || '')
        end
      end # ViewMethods

      module ZafuMethods

        # Show a little [xx] next to the title if the desired language could not be found. You can
        # use a :text => '(lang)' option. The word 'lang' will be replaced by the real value.
        def r_wrong_lang(params = @params)
          if @blocks.empty? || @method != 'wrong_lang'
            text = params[:text] || %q{<span class='wrong_lang'>[#{v.lang}]</span> }
            "<%=  #{node}.version.lang == lang ? '' : #{::RubyLess.translate_string(self, text)} %>"
          else
            expand_if("#{node}.version.lang != lang")
          end
        end

        def r_load
          if dict = @params[:dictionary]
            dict_content, absolute_url, base_path = self.class.get_template_text(dict, @options[:helper], @options[:base_path])
            return parser_error("dictionary #{dict.inspect} not found") unless base_path
            # TODO: How to use dict offline ?
            # We could do:
            # dict_name = get_var_name('dict', 'dictionary')
            # set_context_var('set_var', 'dictionary', TypedString.new(dict_name, StringDictionary))
            # Load with <% #{dict_name} = load_dictionary(#{dict_zip}) -%>
            @context[:dict] ||= {}
            begin
              definitions = YAML::load(dict_content)
              definitions['translations'].each do |elem|
                @context[:dict][elem[0]] = elem[1]
              end
            rescue
              return parser_error("invalid dictionary content #{dict.inspect}")
            end
          else
            return parser_error("missing 'dictionary'")
          end
          expand_with
        end

        def _(text)
          if @context[:dict]
            @context[:dict][text] || helper.send(:_,text)
          else
            helper.send(:_,text)
          end
        end

        def r_trans
          # _1 ==> insert this param ==> trans(@params[:text])
          return nil unless method = get_attribute_or_eval
          klass = method.klass
          return parser_error("Cannot translate a '#{klass}'.") unless klass <= String

          if method.literal
            helper.send(:_, method.literal)
          else
            "<%= trans(#{method}) %>"
          end
        end

        alias r_t r_trans
        #def r_trans
        #  static = true
        #  if @params[:text]
        #    text = @params[:text]
        #  elsif @params[:attr]
        #    text = "#{node_attribute(@params[:attr])}"
        #    static = false
        #  else
        #    res  = []
        #    text = ""
        #    @blocks.each do |b|
        #      if b.kind_of?(String)
        #        res  << b.inspect
        #        text << b
        #      elsif ['show', 'current_date'].include?(b.method)
        #        res << expand_block(b, :trans=>true)
        #        static = false
        #      else
        #        # ignore
        #      end
        #    end
        #    unless static
        #      text = res.join(' + ')
        #    end
        #  end
        #  if static
        #    _(text)
        #  else
        #    "<%= _(#{text}) %>"
        #  end
        #end


        # show language selector
        #def r_lang_links
        #  if wrap_tag = @params[:wrap]
        #    wrap_tag = Zafu::Markup.new(wrap_tag)
        #    tag_in  = "<#{opts[:wrap]}>"
        #    tag_out = "</#{opts[:wrap]}>"
        #  else
        #    tag_in = tag_out = ''
        #  end
        #  res = []
        #  visitor.site.lang_list.each do |l|
        #    if l == visitor.lang
        #      if opts[:wrap]
        #        res << "<#{opts[:wrap]} class='on'>#{l}" + tag_out
        #      else
        #        res << "<em>#{l}</em>"
        #      end
        #    else
        #      if visitor.is_anon? && params[:prefix]
        #        res << tag_in + link_to(l, params.merge(:prefix => l)) + tag_out
        #      else
        #        res << tag_in + link_to(l, params.merge(:lang => l)) + tag_out
        #      end
        #    end
        #  end
        #  res.join(opts[:join] || '')
        #end
      end
    end # I18n
  end # Use
end # Zena