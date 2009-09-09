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
      def nested_attributes_alias(definitions)
        definitions.each do |regexp, target|
          definition = {}
          if target.kind_of?(String)
            target = target.split(".").map {|group| "#{group}_attributes"}
          end
          self.nested_attributes_alias_filters << [regexp, target]
        end
      end
      
      def resolve_attributes_alias(attributes)
        new_attributes = {}
        filters = self.nested_attributes_alias_filters
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
