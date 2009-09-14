module Zena
  module Use
    module NestedAttributesAlias
      # Lets you use nested_attributes_alias methods in forms:
      # <%= text_field 'v_title' %>
      module ViewMethods
        class InstanceTag < ActionView::Helpers::InstanceTag
          def value_before_type_cast(object)
            if object.respond_to?(:nested_model_names_for_alias) && nested_model_names = object.nested_model_names_for_alias(@method_name)
              method_name = nested_model_names.pop # remove method
              nested_model_names.each do |nested_model_name|
                object = object.send(nested_model_name)
              end
              self.class.value_before_type_cast(object, method_name)
            else
              self.class.value_before_type_cast(object, @method_name)
            end
          end
        end
        
        def text_field(object_name, method, options = {})
          ViewMethods::InstanceTag.new(object_name, method, self, options.delete(:object)).to_input_field_tag("text", options)
        end
        
        def password_field(object_name, method, options = {})
          ViewMethods::InstanceTag.new(object_name, method, self, options.delete(:object)).to_input_field_tag("password", options)
        end
        
        def hidden_field(object_name, method, options = {})
          ViewMethods::InstanceTag.new(object_name, method, self, options.delete(:object)).to_input_field_tag("hidden", options)
        end
        
        def file_field(object_name, method, options = {})
          ViewMethods::InstanceTag.new(object_name, method, self, options.delete(:object)).to_input_field_tag("file", options)
        end
        
        def text_area(object_name, method, options = {})
          ViewMethods::InstanceTag.new(object_name, method, self, options.delete(:object)).to_text_area_tag(options)
        end
        
        def check_box(object_name, method, options = {}, checked_value = "1", unchecked_value = "0")
          InstanceTag.new(object_name, method, self, options.delete(:object)).to_check_box_tag(options, checked_value, unchecked_value)
        end
        
        def radio_button(object_name, method, tag_value, options = {})
          InstanceTag.new(object_name, method, self, options.delete(:object)).to_radio_button_tag(tag_value, options)
        end
      end
      
      
      # Adds a class method called 'resolve_attributes_alias' to rewrite attributes.
      #
      # Example:
      # 
      # class Foo < ActiveRecord::Base
      #   include Zena::Use::NestedAttributesAlias::ModelMethods
      #   has_one :redaction
      #   nested_attributes_alias /^r_(.+)/ => 'redaction'
      # end
      # 
      module ModelMethods
        def self.included(base)
          base.extend  Zena::Use::NestedAttributesAlias::ClassMethods
          base.class_eval do
            alias_method_chain :attributes=, :nested_alias
          end
        end
        
        def attributes_with_nested_alias=(*args)
          self.attributes_without_nested_alias = resolve_attributes_alias(*args)
        end
        
        def resolve_attributes_alias(attributes)
          new_attributes = {}
          attributes.each do |k, v|
            if nested_model_names = nested_model_names_for_alias(k)
              if new_key = nested_model_names.pop
                merge_nested_model_names_in_hash(new_attributes, nested_model_names.map {|nested_model_name| "#{nested_model_name}_attributes"})[new_key] = v
              end
            else
              deep_merge_hash(new_attributes, k => v)
            end
          end
          new_attributes
        end
        
        def nested_model_names_for_alias(attribute)
          attribute = attribute.to_s
          nested_model_names = nil
          self.class.nested_attr_alias_list.each do |regexp, target|
            if attribute =~ regexp
              if target.kind_of?(Proc)
                if nested_model_names = target.call(self, $~.to_a)
                  break
                end
              else
                nested_model_names = target + [$1]
                break
              end
            end
          end
          nested_model_names
        end
        private
          
          def merge_nested_model_names_in_hash(target, nested_model_names)
            nested_model_names.each do |model_name|
              target = target[model_name] ||= {}
            end
            target
          end

          def deep_merge_hash(target, hash)
            deep_target = target
            hash.each do |k, v|
              if v.kind_of?(Hash)
                deep_target = target[k] ||= {}
                deep_target = deep_merge_hash(deep_target, v)
              else
                deep_target[k] = v
              end
            end
          end
      end # ModelMethods
      
      module ClassMethods
        @@_nested_attr_alias      ||= {} # defined for each class
        @@_nested_attr_alias_list ||= {} # full list with inherited attributes

        # Return the list of all ordered routes, including routes defined in the superclass
        def nested_attr_alias_list
          @@_nested_attr_alias_list[self] ||= if superclass.respond_to?(:nested_attributes_alias)
            # merge with superclass attributes
            list = superclass.nested_attr_alias_list.dup
            (@@_nested_attr_alias[self] || []).each do |regex, method|
              list.reject! do |k, v|
                # allow new rule to overwrite parent rule
                k == regex
              end
              list << [regex, method]
            end
            list
          else
            # top class, nothing to inherit
            @@_nested_attr_alias[self] || []
          end
        end

        def nested_attributes_alias(definitions)
          list = (@@_nested_attr_alias[self] ||= [])
          definitions.each do |regexp, target|
            # allow new rule to overwrite rule previously defined
            list.reject! {|k, v| k == regexp}

            if target.kind_of?(String)
              target = target.split(".")
            end
            list << [regexp, target]
          end
        end
      end # ClassMethods
      
    end # NestedAttributesAlias
  end # Use
end # Zena
