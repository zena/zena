require 'active_record'
ActiveRecord.load_all!

module Property
  # The PropertyDefinition class is used to hold variables about a Property declaration,
  # such as name, data_type and options.
  class PropertyDefinition < ::ActiveRecord::ConnectionAdapters::Column

    def initialize(name, type, options={})
      name = name.to_s
      extract_property_options(options)
      super(name, @default, type, options)
    end

    def validate(value, errors)
      if !value.kind_of?(klass)
        if value.nil?
          default
        else
          errors.add("#{name}", "invalid data type. Received #{value.class}, expected #{klass}.")
          nil
        end
      end
    end

    def extract_property_options(options)
      @indexed = options.delete(:indexed)
      @default = options.delete(:default)
    end
  end # PropertyDefinition
end # Property