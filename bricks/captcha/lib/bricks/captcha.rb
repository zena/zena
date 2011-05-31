require 'ruby-recaptcha'

# You have to name your module Bricks::[NameOfBrick]::ZafuMethods in order
# for the module to be inserted into the ZafuParser.
module Bricks
  module Captcha
    module ControllerMethods
      include ReCaptcha::AppHelper

      private
        def should_save(obj, params)
          !visitor.is_anon? ||
          validate_recap(params, obj.errors, :rcc_pub => current_site.prop['recaptcha_pub'], :rcc_priv => current_site.prop['recaptcha_priv'])
        end
    end

    module ViewMethods
      include ReCaptcha::ViewHelper

      # Overwrite mail_hide to avoid MH_PUB, MH_PRIV globals
      def mail_hide(address, options={})
        show     = options[:show] || truncate(address, :length => 10)
        pub_key  = options[:mh_pub]  || current_site.prop['mail_hide_pub']
        priv_key = options[:mh_priv] || current_site.prop['mail_hide_priv']
        k = ReCaptcha::MHClient.new(pub_key, priv_key, address)
        uri = "http://www.google.com/recaptcha/mailhide/d?k=#{pub_key}&c=#{k.crypted_address}"
        %Q{<a href="#{uri}" onclick="window.open('#{uri}', '', 'toolbar=0,scrollbars=0,location=0,statusbar=0,menubar=0,resizable=0,width=500,height=300'); return false;" title="#{_('Reveal this e-mail address')}">#{show}</a>}
      end

      # Rewrite get_captcha to avoid writing priv/pub keys in templates
      def get_captcha(options={})
        pub_key  = options[:rcc_pub]  || current_site.prop['recaptcha_pub']
        priv_key = options[:rcc_priv] || current_site.prop['recaptcha_priv']
        k = ReCaptcha::Client.new(pub_key, priv_key, options[:ssl])
        r = k.get_challenge(session[:rcc_err] || '', options)
        session[:rcc_err]=''
        r
      end

      def email_asset(opts)
        content = opts[:content]
        if current_site.prop['mail_hide_priv'] && current_site.prop['mail_hide_pub']
          mail_hide(content, :mh_priv => current_site.prop['mail_hide_priv'], :mh_pub => current_site.prop['mail_hide_pub'])
        else
          "<a href='mailto:#{content}'>#{content}</a>"
        end
      end
    end # ViewMethods

    module ZafuMethods
      def r_captcha
        return parser_error("recaptcha keys not set") unless current_site.prop['recaptcha_pub'] && current_site.prop['recaptcha_priv']
        res = "<%= get_captcha(:ssl => #{@params[:ssl] == 'true' ? 'true' : 'false'}#{get_recaptcha_params}) %>"
        res += expand_with
        "<% if visitor.is_anon? %>#{@markup.wrap(res)}<% end %>"
      end

      def r_mail_hide
        if code = get_attribute_or_eval
          return parser_error("Argument to mail_hide should be a String (found #{code.klass}).") unless code.klass <= String
          if show = @params[:show]
            show = RubyLess.translate_string(self, show)
          end
          "<%= visitor.is_anon? ? mail_hide(#{code}#{get_recaptcha_params(show)}) : #{code} %>"
        end
      end

      def get_recaptcha_params(mh_show = nil)
        res = ", :options => {"
        if mh_show
          res << ":show => #{mh_show},"
        end
        res << ":theme => #{(@params[:theme] || 'red').inspect}"
        res << ", :lang => #{(@params[:lang]  || helper.send(:lang)).inspect}"
        res << ", :tabindex => #{(@params[:tabindex] || 0).to_i}}"
        res
      end
    end # ZafuMethods
  end # Captcha
end # Bricks