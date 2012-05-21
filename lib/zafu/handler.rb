require 'zafu/parser'
require 'zafu/markup'
require 'zafu/node_context'
require 'zafu/template'

module Zafu
  class Handler < ActionView::TemplateHandler
    include ActionView::TemplateHandlers::Compilable

    def compile(template)
      @template = template
      helper   = Thread.current[:view]
      if !helper.respond_to?(:zafu_context)
        raise Exception.new("Please add \"include Zafu::ControllerMethods\" into your ApplicationController for zafu to work properly.")
      end
      ast = Zafu::Template.new(template, self)
      context = helper.zafu_context.merge(:helper => helper)
      context[:node] ||= get_zafu_node_from_view(helper)
      rb = ast.to_ruby('@output_buffer', context)
      ";@erb = %q{#{ast.to_erb(context)}};#{rb}"
    end

    def get_template_text(path, base_path)
      if path == @template.path && base_path.nil?
        [@template.source, @template.path, @template.base_path]
      else
        Thread.current[:view].get_template_text(path, base_path)
      end
    end

    private
      def get_zafu_node_from_view(view)
        controller = view.controller
        if controller.class.to_s =~ /\A([A-Z]\w+?)s?[A-Z]/
          ivar = "@#{$1.downcase}"
          if var = controller.instance_variable_get(ivar.to_sym)
            name  = ivar
            klass = var.class
          elsif var = controller.instance_variable_get(ivar + 's')
            name = ivar + 's'
            klass = [var.first.class]
          end
          return Zafu::NodeContext.new(name, klass) if name
        end
        raise Exception.new("Could not guess main instance variable from request parameters, please add something like \"zafu_node('@var_name', Page)\" in your action.")
      end
  end
end

class ActionView::Template
  attr_reader :view
  def render_template_with_zafu(view, local_assigns = {})
    Thread.current[:view] = view
    render_template_without_zafu(view, local_assigns)
  end
  alias_method_chain :render_template, :zafu
end
