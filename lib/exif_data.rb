require 'json'
require 'rational'

class ExifData < Hash
  include RubyLess

  # Deserialization used by Property
  def self.json_create(serialized)
    if data = serialized['data']
      ExifData.new(data)
    else
      nil
    end
  end

  # Serialization used by Property
  def to_json(*args)
    { 'json_class' => 'ExifData', 'data' => Hash[self.to_a] }.to_json(*args)
  end

  # We need this extra rule to avoid ActiveSupport json encoder thinking Hash[self.to_a] is the
  # same object as this. This is a temporary fix until ActiveSupport use object_id for :seen.
  def ==(other)
    other.class == self.class && super
  end

  # You can create new ExifData objects with either a json representation (String), a
  # hash of key => value or an array of key,value pairs.
  def initialize(data)
    if data.kind_of?(String)
      replace JSON::parse(data) rescue {}
    elsif data.kind_of?(Hash)
      replace data
    elsif data.kind_of?(Array)
      replace Hash[*data.flatten] rescue {}
    else
      # ignore
    end
  end

  ['DateTime', 'DateTimeOriginal', 'DateTimeDigitised'].each do |k|
    method = k.underscore.to_sym
    safe_method method => Time
    define_method(method) do
      date_from_field(k)
    end
  end

  ['GPSLongitude', 'GPSLatitude'].each do |k|
    method = k.underscore.to_sym
    safe_method method => Number
    define_method(method) do
      position_from_field(k)
    end
  end

  private
    def date_from_field(k)
      return nil unless v = self[k]
      Time.parse(v.sub(/(....):(..):(..) /, '\1-\2-\3 ')) rescue nil
    end

    def position_from_field(k)
      return nil unless v = self[k]
      if v =~ /(-?\d+)\/(\d+),\s*(-?\d+)\/(\d+),\s*(-?\d+)\/(\d+)/
        deg = Rational($1.to_i, $2.to_i)
        min = Rational($3.to_i, $4.to_i)
        sec = Rational($5.to_i, $6.to_i)
        deg + min/60.0 + sec/3600.0
      else
        nil
      end
    end
end