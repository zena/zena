module Dynamo
  class Property

    # Dynamo::Property Class is used to hold variables about a Dynamo declaration,
    # such as name, data_type and options.

    attr_accessor :name, :data_type, :options, :default, :indexed

    def initialize(name, type, options={})
      @name, @data_type = name, type
      self.default = options.delete(:default)
      self.indexed = options.delete(:indexed)
      self.options = options
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