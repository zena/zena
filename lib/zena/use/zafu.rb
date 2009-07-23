# This is replaced by public_attributes

# Only zafu_context definition is needed

module Zena
  module Use
    module Zafu
      def self.included(base)
        zafu_class_methods = <<-END
          @@_zafu_context   ||= {} # defined for each class (list of methods to change contexts)
          @@_zafu_known_contexts      ||= {} # full list with inherited attributes

          def self.zafu_context(hash)
            @@_zafu_context[self] ||= {}
            @@_zafu_context[self].merge!(hash.stringify_keys)
          end

          def self.zafu_known_contexts
            @@_zafu_known_contexts[self] ||= begin
              res = {}
              if superclass == ActiveRecord::Base
                @@_zafu_context[self] || {}
              else
                superclass.zafu_known_contexts.merge(@@_zafu_context[self] || {})
              end.each do |k,v|
                if v.kind_of?(Hash)
                  res[k] = v.merge(:node_class => parse_class(v[:node_class]))
                else
                  res[k] = {:node_class => parse_class(v)}
                end
              end
              res
            end
          end

          def self.parse_class(klass)
            if klass.kind_of?(Array)
              if klass[0].kind_of?(String)
                [Module::const_get(klass[0])]
              else
                klass
              end
            else
              if klass.kind_of?(String)
                Module::const_get(klass)
              else
                klass
              end
            end
          end
        END
        
        base.send(:class_eval, zafu_class_methods)
      end
    end
  end
end