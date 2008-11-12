require 'recaptcha'
module ApplicationHelper
  include ReCaptcha::ViewHelper
  asset_method 'email' => :email_asset
  
  # FIXME: remove when rails 2.0.
  # not present in our version of rails. This version is not multi-byte.
  def truncate(text, length = 30, truncate_string = "...")
    if text
      l = length - truncate_string.length
      text.length > length ? text[0..l] + truncate_string : text
    end
  end
  
  # Overwrite mail_hide to avoid MH_PUB, MH_PRIV globals
  def mail_hide(address, options={})
    contents = options[:contents] || truncate(address,10)
    pub_key  = options[:mh_pub]  || MH_PUB
    priv_key = options[:mh_priv] || MH_PRIV
    k = ReCaptcha::MHClient.new(pub_key, priv_key)
    enciphered = k.encrypt(address)
    uri = "http://mailhide.recaptcha.net/d?k=#{pub_key}&c=#{enciphered}"
    %{<a href="#{uri}" onclick="window.open('#{uri}', '', 'toolbar=0,scrollbars=0,location=0,statusbar=0,menubar=0,resizable=0,width=500,height=300'); return false;" title="#{_('Reveal this e-mail address')}">#{contents}</a>}
  end
  
  def email_asset(opts)
    content = opts[:content]
    if current_site.d_mail_hide_priv && current_site.d_mail_hide_pub
      mail_hide(content, :mh_priv => current_site.d_mail_hide_priv, :mh_pub => current_site.d_mail_hide_pub)
    else
      "<a href='mailto:#{content}'>#{content}</a>"
    end
  end
end