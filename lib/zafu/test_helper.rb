module Zafu
  module TestHelper
    include RubyLess::SafeClass

    def zafu_erb(source, src_helper = self, compiler = Zafu::Compiler)
      Zafu::Template.new(source, src_helper, compiler).to_erb(compilation_context)
    end

    def zafu_render(source, src_helper = self, compiler = Zafu::Compiler)
      eval Zafu::Template.new(source, src_helper, compiler).to_ruby(compilation_context)
    end

    def compilation_context
      {:node => @node_context, :helper => self}
    end
  end
end