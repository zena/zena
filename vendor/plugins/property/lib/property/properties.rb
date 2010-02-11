module Property
  class Properties < Hash
    attr_accessor :owner
    include Property::DirtyProperties

    def self.json_create(serialized)
      self[serialized['data']]
    end

    def to_json(*args)
      {
        'json_class' => self.class.name,
        'data' => Hash[self]
      }.to_json(*args)
    end

    def []=(key, value)
      if value.kind_of?(String) && column = columns[key]
        super(key, column.type_cast(value))
      else
        super
      end
    end

    # We need to write our own merge so that typecasting is called
    def merge!(attributes)
      raise TypeError.new("can't convert #{attributes.class} into Hash") unless attributes.kind_of?(Hash)
      attributes.each do |key, value|
        self[key] = value
      end
    end

    def validate
      property_definitions = @owner.class.property_definitions
      errors = @owner.errors
      no_errors = true

      each do |key, value|
        if property_definition = property_definitions[key]
          if default = property_definition.validate(value, errors)
            self[key] = default
          end
        else
          no_errors = false
          errors.add("#{key}", 'property not declared.')
        end
      end
      no_errors
    end

    def compact!
      keys.each do |key|
        if self[key].nil?
          delete(key)
        end
      end
    end

    private
      def write_attribute(key, value)
      end

      def columns
        @columns ||= @owner.class.property_definitions
      end
  end
end
