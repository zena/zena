module Zena
  module Use
    # This module lets the user use a node as if it was not versioned and will
    # take care of routing the attributes between the node and the version.
    module TransparentVersion

      def self.included(base)
        base.class_eval do
          # When writing attributes, we send everything that we do not know of
          # to the version.
          def attributes_with_multi_version=(attributes)
            columns = self.class.column_names
            version_attributes = {}
            attributes.keys.each do |k|
              if !respond_to?("#{k}=") && !columns.include?(k)
                version_attributes[k] = attributes.delete(k)
              end
            end
            version.attributes = version_attributes
            self.attributes_without_multi_version = attributes
          end

          alias_method_chain :attributes=, :multi_version
        end
      end

      private
        # We need method_missing in forms, normal access in templates should be made
        # through 'node.version.xxxx', not 'node.xxxx'.
        def method_missing(meth, *args)
          method = meth.to_s
          if !args.empty? || method[-1..-1] == '?' || self.class.column_names.include?(method)
            super
          elsif version.respond_to?(meth)
            version.send(meth)
          else
            #version.prop[meth.to_s]
            super
          end
        end

        # Any attribute starting with 'v_' belongs to the 'version' or 'redaction'
        # Any attribute starting with 'c_' belongs to the 'version' or 'redaction' content
        # FIXME: performance: create methods on the fly so that next calls will not pass through 'method_missing'. #189.
        # FIXME: this should not be used anymore. Remove.
        # def method_missing(meth, *args)
        #   if meth.to_s =~ /^(v_|c_|d_)(([\w_\?]+)(=?))$/
        #     target = $1
        #     method = $2
        #     value  = $3
        #     mode   = $4
        #     if mode == '='
        #       begin
        #         # set
        #         unless recipient = redaction
        #           # remove trailing '='
        #           redaction_error(meth.to_s[0..-2], "could not be set (no redaction)")
        #           return
        #         end
        #
        #         case target
        #         when 'c_'
        #           if recipient.content_class && recipient = recipient.redaction_content
        #             recipient.send(method,*args)
        #           else
        #             redaction_error(meth.to_s[0..-2], "cannot be set") # remove trailing '='
        #           end
        #         when 'd_'
        #           recipient.prop[method[0..-2]] = args[0]
        #         else
        #           recipient.send(method,*args)
        #         end
        #       rescue NoMethodError
        #         # bad attribute, just ignore
        #       end
        #     else
        #       # read
        #       recipient = version
        #       if target == 'd_'
        #         version.prop[method]
        #       else
        #         recipient = recipient.content if target == 'c_'
        #         return nil unless recipient
        #         begin
        #           recipient.send(method,*args)
        #         rescue NoMethodError
        #           # bad attribute
        #           return nil
        #         end
        #       end
        #     end
        #   else
        #     super
        #   end
        # end
    end
  end
end
