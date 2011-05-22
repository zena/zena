module Zena
  module Use
    module ErrorRendering
      module Common

        #TODO: test
        def error_messages_for(type, opts={})
          obj = opts[:object]
          return '' if !obj || obj.errors.empty?
          res = ["<table class='#{opts[:class] || 'errors'}'>"]
          obj.errors.each_error do |er,msg|
            res << "<tr><td><b>#{er}</b></td><td>#{_(msg)}</td></tr>"
          end
          res << '</table>'
          res.join("\n")
        end

        # TODO: test (where is this used ? discussions, ?)
        def processing_error(msg)
          # (this method used to be called add_error, but it messed up with 'test/unit/testcase.rb' when testing helpers)
          @errors ||= []
          @errors << _(msg)
        end

        # TODO: test
        def render_errors(errs=@errors)
          if !errs || errs.empty?
            ""
          elsif errs.kind_of?(ActiveRecord::Errors)
            res = "<table class='errors'>"
            errs.each do |k,v|
              res << "<tr><td><b>#{k}</b></td><td>#{v}</td></tr>\n"
            end
            res << "</table>"
            res
          else
            "<table class='errors'><tr><td>#{errs.join("</td></tr>\n<tr><td>")}</td></tr></table>"
          end
        end

      end # Common

      module ControllerMethods
        include Common
      end

      module ViewMethods
        include Common
      end

    end # ErrorRendering
  end # Use
end # Zena