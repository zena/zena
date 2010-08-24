require File.join(File.dirname(__FILE__), 'info')

Zena::Use.module  [
  Zena::Use::Action,
  Zena::Use::Authlogic,
  Zena::Use::Calendar,
  Zena::Use::Context,
  Zena::Use::Dates,
  Zena::Use::Display,
  Zena::Acts::Enrollable,
  Zena::Use::ErrorRendering,
  Zena::Use::Forms,
  Zena::Use::HtmlTags,
  Zena::Use::I18n,
  Zena::Use::NestedAttributesAlias,
  Zena::Use::QueryBuilder,
  Zena::Use::Refactor,
  Zena::Use::Rendering,
  # Ajax must appear after rendering because it uses 'super' in js_render
  Zena::Use::Ajax,
  Zena::Use::Upload,
  Zena::Use::Urls,
  Zena::Use::ZafuAttributes,
  Zena::Use::ZafuSafeDefinitions,
  Zena::Use::ZafuTemplates,
  Zena::Use::Zazen,
]

module Zena
  module App
    def self.included(base)
      base.prepend_view_path SITES_ROOT
      base.class_eval do
        Zena::Use.each_module_for('Controller') do |mod|
          include mod
        end

        include RubyLess

        helper  Zena::Acts::Secure

        Zena::Use.each_module_for('View') do |mod|
          helper mod
        end

        helper_method :render_to_string
      end
      Bricks.apply_patches('application_controller.rb')
      Bricks.apply_patches('application_helper.rb')
    end
  end
end