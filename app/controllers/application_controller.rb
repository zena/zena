class ApplicationController < ActionController::Base
  include Zena::Use::Authentification::ControllerMethods
  include Zena::Use::Dates::ControllerMethods
  include Zena::Use::ErrorRendering::ControllerMethods
  include Zena::Use::I18n::ControllerMethods
  include Zena::Use::Refactor::ControllerMethods
  include Zena::Use::Rendering::ControllerMethods
  include Zena::Use::Urls::ControllerMethods
  include Zena::Use::Zafu::ControllerMethods

  # FIXME: move into their module
  before_filter :set_lang
  before_filter :authorize
  before_filter :check_lang
  after_filter  :set_encoding
  
  helper  Zena::Acts::Secure
  helper  Zena::Use::Ajax::ViewMethods
  helper  Zena::Use::Calendar::ViewMethods
  helper  Zena::Use::Dates::ViewMethods
  helper  Zena::Use::ErrorRendering::ViewMethods
  helper  Zena::Use::HtmlTags::ViewMethods
  helper  Zena::Use::I18n::ViewMethods
  helper  Zena::Use::NestedAttributesAlias::ViewMethods
  helper  Zena::Use::Refactor::ViewMethods
  helper  Zena::Use::Urls::ViewMethods
  helper  Zena::Use::Zafu::ViewMethods
  helper  Zena::Use::Zazen::ViewMethods
  
  layout false
  
end

Bricks::Patcher.apply_patches
