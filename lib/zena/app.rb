Zena.use  [
  Zena::Use::Action,
  Zena::Use::Authlogic,
  Zena::Use::Calendar,
  Zena::Use::Context,
  Zena::Use::Dates,
  Zena::Acts::Enrollable,
  Zena::Use::ErrorRendering,
  Zena::Use::Forms,
  Zena::Use::HtmlTags,
  Zena::Use::I18n,
  Zena::Use::NestedAttributesAlias,
  # Must appear before Display so that we first try to resolve as QB before r_show fallback.
  Zena::Use::QueryBuilder,
  Zena::Use::Display,
  Zena::Use::Refactor,
  Zena::Use::Rendering,
  # Ajax must appear after rendering because it uses 'super' in js_render
  Zena::Use::Ajax,
  Zena::Use::Upload,
  Zena::Use::Urls,
  Zena::Use::ZafuAttributes,
  Zena::Use::ZafuEval,
  Zena::Use::ZafuSafeDefinitions,
  Zena::Use::ZafuTemplates,
  Zena::Use::Zazen,
]

module Zena
  module App
    def self.included(base)
      base.prepend_view_path SITES_ROOT
      base.class_eval do
        bricks = []
        Zena::Use.each_module_for('Controller') do |mod|
          if mod.to_s =~ /^Bricks::/
            bricks << mod
          else
            include mod
          end
        end

        bricks.each do |mod|
          include mod
        end

        include RubyLess

        helper  Zena::Acts::Secure

        Zena::Use.each_module_for('View') do |mod|
          helper mod
        end

        helper_method :render_to_string
        filter_parameter_logging :password
      end
      Bricks.apply_patches('application_controller.rb')
      Bricks.apply_patches('application_helper.rb')
      
      Zena::Use.upgrade_class('User')
      Zena::Use.upgrade_class('Site')
      Zena::Use.upgrade_class('Skin')

    end
  end
end
