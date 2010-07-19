require 'bricks/captcha'
Zena::Use.module Bricks::Captcha

# TODO change 'asset_method' to Zena::Use.zazen_tag 'email' => :zazen_email
Zena::Use::Zazen::ViewMethods.asset_method 'email' => :email_asset

# set public and private keys
properties = %w{recaptcha_pub recaptcha_priv mail_hide_pub mail_hide_priv}
Site.property.string properties
Site.attributes_for_form[:text] += properties
Site.send(:attr_accessible, *properties)
