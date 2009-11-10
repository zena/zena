require File.join(File.dirname(__FILE__), 'info')
module Zena
  module App
    def self.included(base)
      base.prepend_view_path SITES_ROOT
      base.class_eval do
        include Zena::Use::Authlogic::ControllerMethods
        include Zena::Use::Dates::ControllerMethods
        include Zena::Use::ErrorRendering::ControllerMethods
        include Zena::Use::I18n::ControllerMethods
        include Zena::Use::Refactor::ControllerMethods
        include Zena::Use::Rendering::ControllerMethods
        include Zena::Use::Upload::ControllerMethods
        include Zena::Use::Urls::ControllerMethods
        include Zena::Use::Zafu::ControllerMethods

        # FIXME: could we move these into their modules ?
        before_filter :set_visitor, :set_after_login
        before_filter :set_lang, :check_lang
        after_filter  :set_encoding
        layout        false

        FastGettext.add_text_domain 'zena', :path => "#{Zena::ROOT}/locale" #File.dirname(__FILE__) + '/../../locale'
        FastGettext.text_domain = 'zena'

        helper  Zena::Use::Authlogic::ViewMethods
        helper  Zena::Acts::Secure
        helper  Zena::Use::Ajax::ViewMethods
        helper  Zena::Use::Calendar::ViewMethods
        helper  Zena::Use::Dates::ViewMethods
        helper  Zena::Use::ErrorRendering::ViewMethods
        helper  Zena::Use::HtmlTags::ViewMethods
        helper  Zena::Use::I18n::ViewMethods
        helper  Zena::Use::NestedAttributesAlias::ViewMethods
        helper  Zena::Use::Refactor::ViewMethods
        helper  Zena::Use::Rendering::ViewMethods
        helper  Zena::Use::Upload::ViewMethods
        helper  Zena::Use::Urls::ViewMethods
        helper  Zena::Use::Zafu::ViewMethods
        helper  Zena::Use::Zazen::ViewMethods
        helper_method :render_to_string
      end
      Bricks.apply_patches('application_controller.rb')
      Bricks.apply_patches('application_helper.rb')
    end
  end
end