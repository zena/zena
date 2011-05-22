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
        contents = options[:contents] || truncate(address, :length => 10)
        pub_key  = options[:mh_pub]  || MH_PUB
        priv_key = options[:mh_priv] || MH_PRIV
        k = ReCaptcha::MHClient.new(pub_key, priv_key)
        enciphered = k.encrypt(address)
        uri = "http://mailhide.recaptcha.net/d?k=#{pub_key}&c=#{enciphered}"
        %{<a href="#{uri}" onclick="window.open('#{uri}', '', 'toolbar=0,scrollbars=0,location=0,statusbar=0,menubar=0,resizable=0,width=500,height=300'); return false;" title="#{_('Reveal this e-mail address')}">#{contents}</a>}
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
        res = "<%= get_captcha(:rcc_pub => #{visitor.site.prop['recaptcha_pub'].inspect}, :rcc_priv => #{visitor.site.prop['recaptcha_priv'].inspect}#{get_recaptcha_params}) %>"
        res += expand_with
        "<% if visitor.is_anon? %>#{@markup.wrap(res)}<% end %>"
      end

      def r_mail_hide
        text = get_text_for_erb
        "<%= visitor.is_anon? ? mail_hide(#{text},:mh_pub => #{visitor.site.prop['mail_hide_pub'].inspect}, :mh_priv => #{visitor.site.prop['mail_hide_priv'].inspect}#{get_recaptcha_params}) : #{text} %>"
      end

      def get_recaptcha_params
        res = ", :options => {"
        res << ":theme => #{(@params[:theme] || 'red').inspect}"
        res << ", :lang => #{(@params[:lang]  || helper.send(:lang)).inspect}"
        res << ", :tabindex => #{(@params[:tabindex] || 0).to_i}}"
        res
      end
    end # ZafuMethods
  end # Captcha
end # Bricks