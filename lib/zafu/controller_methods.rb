module Zafu
  module ControllerMethods
    def self.included(base)
      base.helper Common
      if RAILS_ENV == 'development'
        base.class_eval do
          def render_for_file_with_rebuild(template_path, status = nil, layout = nil, locals = {}) #:nodoc:
            path = template_path.respond_to?(:path_without_format_and_extension) ? template_path.path_without_format_and_extension : template_path
            logger.info("Rendering #{path}" + (status ? " (#{status})" : '')) if logger
            # if params[:rebuild] == 'true'
              t = self.view_paths.find_template(template_path, 'html')
              t.previously_last_modified = nil
            # end
            render_for_text @template.render(:file => template_path, :locals => locals, :layout => layout), status
          end
          alias_method_chain :render_for_file, :rebuild
        end
      end
    end

    def zafu_node(name, klass)
      zafu_context[:node] = Zafu::NodeContext.new(name, klass)
    end

    module Common
      def zafu_context
        @zafu_context ||= {}
      end

      # Quote for html attributes (field quote). There might be a better rails alternative to this.
      def fquote(text)
        text.to_s.gsub("'",'&apos;')
      end

      # This method should return the template for a given 'src' and
      # 'base_path'.
      def get_template_text(path, base_path, opts={})
        [path, "#{base_path}/#{path}"].each do |p|
          begin
            t = self.view_paths.find_template(p, 'html') # FIXME: format ?
          rescue ActionView::MissingTemplate
            t = nil
          end
          return [t.source, t.path, t.base_path] if t
        end
        nil
      end

      def template_url_for_asset(opts)
        opts[:src]
      end
    end # Common

    include Common
  end
end