# This is replaced by public_attributes

# Only zafu_context definition is needed

module Zena
  module Use
    module Zafu
      def self.included(base)
        base.send :class_eval do
          def self.zafu_context(hash)
            # dummy
          end
        end
      end
    end
  end
end
=begin
module Zena
  module Use
    module Zafu
      def self.included(base)
        zafu_class_methods = <<-END
          @@_zafu_readable  ||= {} # defined for each class
          @@_safe_attribute ||= {} # defined for each class
          @@_zafu_context   ||= {} # defined for each class (list of methods to change contexts)
          @@_zafu_readable_attributes ||= {} # full list with inherited attributes
          @@_safe_attribute_list      ||= {} # full list with inherited attributes
          @@_zafu_known_contexts      ||= {} # full list with inherited attributes

          def self.zafu_readable(*list)
            @@_zafu_readable[self] ||= []
            @@_zafu_readable[self] = (@@_zafu_readable[self] + list.map{|l| l.to_s}).uniq
          end

          def self.safe_attribute(*list)
            @@_safe_attribute[self] ||= []
            @@_safe_attribute[self] = (@@_safe_attribute[self] + list.map{|l| l.to_s}).uniq
          end

          def self.zafu_context(hash)
            @@_zafu_context[self] ||= {}
            @@_zafu_context[self].merge!(hash.stringify_keys)
          end

          def self.zafu_readable_attributes
            @@_zafu_readable_attributes[self] ||= if superclass == ActiveRecord::Base
              @@_zafu_readable[self] || []
            else
              (superclass.zafu_readable_attributes + (@@_zafu_readable[self] || [])).uniq.sort
            end
          end

          def self.safe_attribute_list
            @@_safe_attribute_list[self] ||= if superclass == ActiveRecord::Base
              @@_safe_attribute[self] || []
            else
              (superclass.safe_attribute_list + (@@_safe_attribute[self] || [])).uniq.sort
            end
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

          def self.safe_attribute?(sym)
            column_names.include?(sym) || zafu_readable?(sym) || safe_attribute_list.include?(sym.to_s)
          end

          def self.zafu_readable?(sym)
            if sym.to_s =~ /(.*)_zips?$/
              return true if self.ancestors.include?(Node) && RelationProxy.find_by_role($1.singularize)
            end
            self.zafu_readable_attributes.include?(sym.to_s)
          end
          
          def zafu_read(sym)
            return "'\#{sym}' not readable" unless self.class.zafu_readable?(sym)
            self.send(sym)
          end
        END
        
        base.send(:class_eval, zafu_class_methods)
      end
    end
  end
end
=end