module Zena
  module Use
=begin

Example:

class Foo < ActiveRecord::Base
  include Zena::Use::NestedAttributesAlias
  has_one :redaction
  nested_attributes_alias /^r_(.+)/ => 'redaction'
end

=end
    module NestedAttributesAliasClassMethods
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
            target = target.split(".").map {|group| "#{group}_attributes"}
          end
          list << [regexp, target]
        end
      end
      
      def resolve_attributes_alias(attributes)
        new_attributes = {}
        filters = self.nested_attr_alias_list
        attributes.each do |k, v|
          matched = false
          filters.each do |regexp, target|
            if k.to_s =~ regexp
              if target.kind_of?(Proc)
                if hash = target.call($~.to_a, v)
                  matched = true
                  deep_merge_hash(new_attributes, hash)
                  break
                end
              else
                matched = true
                new_key = $1
                merge_groups_in_hash(new_attributes, target)[new_key] = v
                break
              end
            end
          end
          deep_merge_hash(new_attributes, k => v) unless matched
        end
        new_attributes
      end
      
      def merge_groups_in_hash(target, groups)
        groups.each do |group|
          target = target[group] ||= {}
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
    end # NestedAttributesAliasClassMethods
    
    module NestedAttributesAlias
      def self.included(base)
        base.class_eval do
          @nested_attributes_alias_filters = []
        end
        
        class << base
          attr_reader :nested_attributes_alias_filters
          
          include Zena::Use::NestedAttributesAliasClassMethods
        end
      end
    end # NestedAttributesAlias
  end # Use
end # Zena
