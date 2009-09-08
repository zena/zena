module Zena
  module Use
    module NestedAttributesAliasClassMethods
      def nested_attributes_alias(definition, &block)
        definition[:accessor] = block
        if definition[:prefix]
          definition[:regexp] = /^#{definition[:prefix].gsub('*', '\\*')}(.+)$/
        elsif definition[:suffix]
          definition[:regexp] = /^(.+)#{definition[:suffix].gsub('*', '\\*')}$/
        end
        
        if definition[:for]
          definition[:for] = definition[:for].split(".").map {|group| "#{group}_attributes"}
        end
        
        raise ArgumentError.new("Missing :regexp or :prefix key for nested_attributes_alias.") unless definition[:regexp]
        
        self.nested_attributes_alias_filters << definition
      end
      
      def resolve_attributes_alias(attributes)
        new_attributes = {}
        filters = self.nested_attributes_alias_filters
        attributes.each do |k, v|
          matched = false
          filters.each do |f|
            regexp = f[:regexp]
            if k.to_s =~ regexp
              if proc = f[:proc]
                if hash = proc.call($~.to_a, v)
                  matched = true
                  deep_merge_hash(new_attributes, hash)
                  break
                end
              else
                matched = true
                new_key = $1
                merge_groups_in_hash(new_attributes, f[:for])[new_key] = v
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
