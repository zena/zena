module Property
  # This module implement ActiveRecord::Dirty functionalities with Property attributes. It
  # enables the usual 'changed?' and 'changes' to include property changes. Unlike dirty,
  # 'foo_changed?' and 'foo_was' are not defined in the model and should be replaced by
  # #prop.foo_changed? and prop.foo_was.
  #
  # If you need to find the property changes only, you can use #prop.changes or prop.changed?
  #
  module Dirty

    private

      def self.included(base)
        base.class_eval do
          alias_method_chain :changed?, :properties
          alias_method_chain :changed,  :properties
          alias_method_chain :changes,  :properties
        end
      end

      def changed_with_properties?
        changed_without_properties? || properties.changed?
      end

      def changed_with_properties
        changed_without_properties + properties.changed
      end

      def changes_with_properties
        changes_without_properties.merge properties.changes
      end

  end # Dirty

  # This module implements ActiveRecord::Dirty functionalities for the properties hash.
  module DirtyProperties
    CHANGED_REGEXP = %r{(.+)_changed\?$}
    WAS_REGEXP = %r{(.+)_was$}

    def []=(key, value)
      @original_hash ||= self.dup
      super
    end

    def delete(key)
      @original_hash ||= self.dup
      super
    end

    def merge!(other_hash)
      @original_hash ||= self.dup
      super
    end

    def changed?
      !changes.empty?
    end

    def changed
      changes.keys
    end

    def changes
      return {} unless @original_hash
      compact!
      changes = {}

      # look for updated value
      each do |key, new_value|
        if new_value != (old_value = @original_hash[key])
          changes[key] = [old_value, new_value]
        end
      end

      # look for deleted value
      (@original_hash.keys - keys).each do |key|
        changes[key] = [@original_hash[key], nil]
      end

      changes
    end

    # This method should be called to reset dirty information before dump
    def clear_changes!
      remove_instance_variable(:@original_hash) if defined?(@original_hash)
    end

    def method_missing(meth, *args)
      if method.to_s =~ CHANGED_REGEXP
        !changes[$1].nil?
      elsif method =~ WAS_REGEXP
        (@original_hash || self)[$1]
      else
        super
      end
    end
  end
end # Property