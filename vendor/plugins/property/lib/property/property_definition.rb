module Dynamo
  # Dynamo::Property Class is used to hold variables about a Dynamo declaration,
  # such as name, data_type and options.
  class Property
    attr_accessor :name, :data_type, :options, :default, :indexed

    def initialize(name, type, options={})
      @name, @data_type = name, type
      @default = options.delete(:default)
      @indexed = options.delete(:indexed)
      @options = options
    end

    def ==(other)
      @name == other.name && @type == other.type
    end

    # def get(value)
    #   if value.nil? && !default_value.nil?
    #     return default_value
    #   end
    #
    #   type_cast(value)
    # end
  end # Property
end # Dynamo