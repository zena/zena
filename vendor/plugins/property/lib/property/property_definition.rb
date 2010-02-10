module Property
  # The PropertyDefinition class is used to hold variables about a Property declaration,
  # such as name, data_type and options.
  class PropertyDefinition
    attr_accessor :name, :data_type, :options, :default, :indexed

    def initialize(name, type, options={})
      raise ArgumentError.new("You cannot use symbols as property keys (#{name.inspect})") unless name.kind_of?(String)
      @name, @data_type = name, type
      @default = options.delete(:default)
      @indexed = options.delete(:indexed)
      @options = options
    end

    def ==(other)
      @name == other.name && @type == other.type
    end

    def validate(value, model)
      if !value.kind_of?(data_type)
        if value.nil?
          @default
        else
          model.errors.add("#{name}", "invalid data type. Received #{value.class}, expected #{data_type}.")
          nil
        end
      end
    end

    # def get(value)
    #   if value.nil? && !default_value.nil?
    #     return default_value
    #   end
    #
    #   type_cast(value)
    # end
  end # Property
end # Property