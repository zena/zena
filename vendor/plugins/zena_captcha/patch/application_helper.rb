require 'recaptcha'
module ApplicationHelper
  include ReCaptcha::ViewHelper
  
  # Overwrite mail_hide to avoid MH_PUB, MH_PRIV globals
  def mail_hide(address, options={})
    contents = options[:contents] || truncate(address,10)
    pub_key  = options[:mh_pub]  || MH_PUB
    priv_key = options[:mh_priv] || MH_PRIV
    k = ReCaptcha::MHClient.new(pub_key, priv_key)
    enciphered = k.encrypt(address)
    uri = "http://mailhide.recaptcha.net/d?k=#{pub_key}&c=#{enciphered}"
    t =<<-EOF
    <a href="#{uri}"
    onclick="window.open('#{uri}', '', 'toolbar=0,scrollbars=0,location=0,statusbar=0,menubar=0,resizable=0,width=500,height=300'); return false;" title="#{_('Reveal this e-mail address')}">#{contents}</a>
  EOF
  end
end