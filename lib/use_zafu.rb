module Zena
  module ZafuExtension
    module UseZafu
      # this is called when the module is included into the 'base' module
      def self.included(base)
        # add all methods from the module "AddActsAsMethod" to the 'base' module
        base.extend Zena::ZafuExtension::TriggerClassMethod
      end
    end
    
    module ClassMethods
      # .. (using eval for @@ scope)
    end
    
    module TriggerClassMethod
      def use_zafu
        class_eval <<-END
          include Zena::ZafuExtension::InstanceMethods
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
        END
      end
    end
    
    module InstanceMethods
      def zafu_read(sym)
        return read_custom_field(sym) if custom_field?(sym)
        return "'#{sym}' not readable" unless self.class.zafu_readable?(sym)
        self.send(sym)
      end
      
      def custom_field?(sym)
        !methods.include?(sym) && !self.class.column_names.include?(sym.to_s)
      end
      
      def read_custom_field(sym)
        val = @attributes[sym]
        if sym =~ /_at$/ || sym =~ /_date$/
          self.class.columns.first.class.string_to_time(val)
        elsif sym =~ /_count$/
          val.to_i
        else
          val
        end
      end
    end
  end
end

ActiveRecord::Base.send :include, Zena::ZafuExtension::UseZafu
ActiveRecord::Base.send :use_zafu