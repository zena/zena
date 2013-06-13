require 'iconv'

module Zena
  module Use
    # On load this module changes ENV['LANG'] to 'C' in order to behave consitently without
    # strange bugs when the locale is changed.
    module I18n
      ::ENV['LANG'] = 'C'

      class TranslationDict
        attr_reader :last_error, :node_id, :static

        include Zena::Acts::Secure
        include RubyLess

        # never returns nil
        safe_method [:get, String] => {:class => String, :accept_nil => true, :html_safe => true}

        def initialize(node_id, static = nil)
          @node_id = node_id
          @static  = static
        end

        def get(key, use_global = true)
          load!
          get_without_loading(key, use_global)
        end

        def get_without_loading(key, use_global = true)
          # SECURITY: We consider all strings in dictionaries as SAFE.
          @dict[key] || (use_global && ApplicationController.send(:_, key))
        end

        def load!(text = nil)
          unless text
            if @node_id
              if dict = secure(Node) { Node.find(:first, :conditions => {:id => @node_id}) }
                text = dict.prop['text']
              else
                @dict = {}
                error("missing 'dictionary'")
                return false
              end
            else
              text, ignore = ::Skin.text_from_fs_skin(@static[:brick_name], @static[:skin_name], @static[:path], :ext => 'yml')
              unless text
                @dict = {}
                error("missing 'dictionary'")
                return false
              end
            end
          end
          
          begin
            definitions = YAML::load(text)
            if translations = definitions['translations']
              if translations.kind_of?(Hash)
                # ok
                @dict = translations
              else
                return error("bad 'translations' content (should be a dictionary)")
              end
            else
              return error("missing 'translations' top-level key in dictionary")
            end
          rescue
            return error("invalid dictionary content #{dict.inspect}")
          end

          class << self
            alias get get_without_loading
          end

          true
        end

        private
          def error(message)
            @last_error = message
            nil
          end
      end

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
        # 2. 'test.host/nodes/12?node[v_lang]=es
        # 3. 'test.host/oo' use visitor[:lang]
        # 4. 'test.host/es' use prefix  ONLY ENABLED FOR html format (see below)
        # 5. 'test.host/'   use session[:lang]
        # 6. 'test.host/oo' use visitor lang
        # 7. 'test.host/'   use HTTP_ACCEPT_LANGUAGE
        # 8. 'test.host/'   use default language
        #
        # 4. 'test.host/es' the redirect for this rule is called once we are sure the request is
        #     not for document data (lang in this case can be different from what the visitor is
        #     visiting due to caching optimization).
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
            # Avoid redirects for static assets (cached documents).
            request.format == Mime::HTML ? params[:prefix] : nil,
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

        safe_method [:lang_links, {:wrap => String, :join => String}] => {:class => String, :method => 'lang_links', :html_safe => true}

        def self.included(base)
          base.send(:alias_method_chain, :will_paginate, :i18n) if base.respond_to?(:will_paginate)
        end

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

        def trans(str)
          ApplicationController.send(:_, str)
        end

        def load_dictionary(node_id, static=nil)
          Zena::Use::I18n::TranslationDict.new(node_id, static)
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
                res << tag_in + "<a href='#{zen_path(@node, :lang => l)}'>#{l}</a>" + tag_out
              else
                res << tag_in + link_to(l, params.merge(:lang => l)) + tag_out
              end
            end
          end
          res.join(opts[:join] || '')
        end
      end # ViewMethods

      module ZafuMethods
        include RubyLess
        safe_method [:trans, String] => :translate
        safe_method [:t,     String] => :translate

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

        def r_iconv
          return parser_error("missing 'to' parameter") unless to = @params[:to]
          begin
            Iconv.iconv(to, 'utf8', 'éaïl')
          rescue
            return parser_error("invalid encoding #{to.inspect}")
          end

          data_name = get_var_name('iconv', 'data')
          out "<% #{data_name} = capture do %>"
          out expand_with
          out "<% end %>"
          out "<%= Iconv.iconv(#{to.inspect}, 'utf8', #{data_name}) %>"
        end

        def r_load
          if dict = @params[:dictionary]
            # FIXME: replace @options[:base_path] by @options[:skin_id]
            dict_content, absolute_url, base_path, doc = @options[:helper].send(:get_template_text, dict, @options[:base_path], :ext => 'yml')
            if dict_content
              # Lazy dictionary used for literal resolution
              if doc
                dict = TranslationDict.new(doc.id)
              else
                if absolute_url =~ /^\$([a-zA-Z_]+)-([a-zA-Z_]+)\/(.+)$/
                  static = {:brick_name => $1, :skin_name => $2, :path => $3}
                else
                  return parser_error("Invalid absolute_url for static asset ('#{absolute_url}')")
                end
                dict = TranslationDict.new(nil, static)
              end

              if dict.load!(dict_content)
                # Save dictionary in template for dynamic uses
                dict_name = get_var_name('dictionary', 'dict')

                # This is to use in RubyLess translations and static translations in Zafu
                set_context_var('set_var', 'dictionary', RubyLess::TypedString.new(dict_name, :class => TranslationDict, :literal => dict))

                # Lazy loading (loads file on first request)
                if doc
                  out "<% #{dict_name} = load_dictionary(#{doc.id}) %>"
                else
                  out "<% #{dict_name} = load_dictionary(nil, #{static.inspect}) %>"
                end
              else
                return parser_error(dict.last_error)
              end
            else
              # not found
              if @params[:missing] == 'ignore'
                # ignore
              else
                return parser_error("dictionary #{dict.inspect} not found") unless base_path
              end
            end
          else
            return parser_error("missing 'dictionary'")
          end

          expand_with
        end

        # Resolve RubyLess 't' and 'trans' methods
        def translate(signature, receiver = nil)
          return nil unless signature.size == 2 && signature[1] <= String

          dict = get_context_var('set_var', 'dictionary')

          if dict && dict.klass <= TranslationDict
            { :class  => String,
              :method => "#{dict}.get",
              :accept_nil => true,
              :html_safe  => true,
              :pre_processor => Proc.new {|this, str| 
                t = erb_escape(trans(str))
                RubyLess::TypedString.new(t.inspect, :html_safe => true, :literal => t, :class => String)
              }
            }
          else
            { :class  => String,
              :method => 'trans',
              :accept_nil => true,
              :html_safe  => true,
              :pre_processor => Proc.new {|this, str| 
                t = erb_escape(trans(str))
                RubyLess::TypedString.new(t.inspect, :html_safe => true, :literal => t, :class => String)
              }
            }
          end
        end

        def trans(text, use_global = true)
          dictionary = get_context_var('set_var', 'dictionary')

          if dictionary && dictionary.klass <= TranslationDict && dict = dictionary.literal
            # will call ApplicationController(:_) if key is not found
            dict.get(text, use_global)
          elsif use_global
            helper.send(:_, text)
          else
            nil
          end
        end

        # Translate a string representing a list of values separated with a comma ('dog,cat,house')
        # to a list of strings.
        def translate_list(str, prefix = nil)
          if trad = trans(str, false)
            trad.split(',').map(&:strip)
          elsif prefix
            str.split(',').map(&:strip).map do |v|
              k = "#{prefix}_#{v}"
              d = trans(k)
              d == k ? v : d
            end
          else
            str.split(',').map(&:strip).map{|v| trans(v)}
          end
        end

        def r_trans
          # _1 ==> insert this param ==> trans(@params[:text])
          return nil unless method = get_attribute_or_eval
          klass = method.klass
          return parser_error("Cannot translate a '#{klass}'.") unless klass <= String

          dict = get_context_var('set_var', 'dictionary')

          if method.literal
            erb_escape trans(method.literal)
          elsif dict && dict.klass <= TranslationDict
            "<%= #{dict}.get(#{method}) %>"
          else
            "<%= trans(#{method}) %>"
          end
        end

        alias r_t r_trans

        protected

          # Overwriten from Zafu to insert dictionary in partial if there is one
          def context_for_partial(cont)
            cleared_context, prefix = super(cont)
            prefix = prefix.to_s
            dict = get_context_var('set_var', 'dictionary')
            if dict && dict.klass <= TranslationDict
              # Lazy loading (loads file on first request)
              dict_name = get_var_name('dictionary', 'dict', cleared_context)
              set_context_var('set_var', 'dictionary', dict, cleared_context)
              d = dict.literal
              prefix += "<% #{dict_name} = load_dictionary(#{d.node_id.inspect},#{d.static.inspect}) %>"
              return cleared_context, prefix
            else
              return cleared_context, nil
            end
          end
      end
    end # I18n
  end # Use
end # Zena