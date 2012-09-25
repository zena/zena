require 'zafu/parser'

if defined?(ActionView)
  require 'zafu/handler'
  ActionView::Template.register_template_handler(:zafu, Zafu::Handler)
  ActionView::Template.register_template_handler(:html, Zafu::Handler)
end
