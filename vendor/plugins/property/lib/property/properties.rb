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
      if column = columns[key]
        if value.blank?
          if default = column.default
            super(key, default)
          else
            delete(key)
          end
        else
          super(key, column.type_cast(value.to_s))
        end
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
      columns = @owner.class.property_columns
      column_names = @owner.class.property_column_names
      errors = @owner.errors
      no_errors = true

      bad_keys     = keys - column_names
      missing_keys = column_names - keys

      bad_keys.each do |key|
        errors.add("#{key}", 'property is not declared')
      end

      missing_keys.each do |key|
        column = columns[key]
        if column.has_default?
          self[key] = column.default
        end
      end

      bad_keys.empty?
    end

    def compact!
      #keys.each do |key|
      #  if self[key].nil?
      #    delete(key)
      #  end
      #end
    end

    private
      def write_attribute(key, value)
      end

      def columns
        @columns ||= @owner.class.property_columns
      end
  end
end
