module Property
  class Properties < Hash
    include ::Property::DirtyProperties

    def self.json_create(serialized)
      self[serialized['data']]
    end

    def to_json(*args)
      {
        'json_class' => self.class.name,
        'data' => Hash[self]
      }.to_json(*args)
    end

    def compact!
      keys.each do |key|
        if self[key].nil?
          delete(key)
        end
      end
    end
  end
end
