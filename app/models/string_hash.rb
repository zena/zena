class StringHash < Hash
  include RubyLess
  
  def self.from_string(str)
    from_hash(JSON.parse(str))
  rescue
    from_hash({})
  end
  
  def self.from_hash(hash)
    obj = new
    hash.each do |k,v|
      obj[k.to_s] = v.to_s
    end
    obj
  end
  
  def self.[](value)
    from_hash(value)
  end
  
  # Deserialization used by Property
  def self.json_create(serialized)
    if data = serialized['data']
      StringHash[data]
    else
      nil
    end
  end
  
  def []=(k, v)
    if v.blank?
      delete(k.to_s)
    else
      super(k.to_s, v.to_s)
    end
  end
  
  def merge!(value)
    value.each do |k,v|
      self[k] = v
    end
    self
  end
  
  def merge(value)
    obj = dup
    value.each do |k,v|
      obj[k] = v
    end
    obj
  end
  
  # Serialization used by Property
  def to_json(*args)
    { 'json_class' => 'StringHash', 'data' => Hash[self] }.to_json
  end
  
  # This is used in case we show a form with the StringHash so that the value
  # is not serialized to junk. This is the other side of "from_string".
  def to_s
    Hash[self].to_json
  end

  safe_context [:[], String] => String
  safe_method :keys => {:class => [String], :method => 'keys.sort'}
end