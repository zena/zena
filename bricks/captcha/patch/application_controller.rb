require 'ruby-recaptcha'
class ApplicationController
  include ReCaptcha::AppHelper

  private
    def save_if_not_spam(obj, params)
      (!visitor.is_anon? || validate_recap(params, obj.errors, :rcc_pub => current_site.dyn['recaptcha_pub'], :rcc_priv => current_site.dyn['recaptcha_priv'])) && obj.save
    end
end

