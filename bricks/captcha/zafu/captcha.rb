require 'ruby-recaptcha'

# You have to name your module Bricks::[NameOfBrick]::Zafu in order
# for the module to be inserted into the ZafuParser.
module Bricks
  module Captcha
    module Zafu
      def r_captcha
        return parser_error("recaptcha keys not set") unless current_site.prop['recaptcha_pub'] && current_site.prop['recaptcha_priv']
        res = "<%= get_captcha(:rcc_pub => #{visitor.site.prop['recaptcha_pub'].inspect}, :rcc_priv => #{visitor.site.prop['recaptcha_priv'].inspect}#{get_recaptcha_params}) %>"
        res += expand_with
        "<% if visitor.is_anon? -%>#{render_html_tag(res)}<% end -%>"
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
    end # Zafu
  end # Captcha
end # Bricks