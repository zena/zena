require 'test_helper'

class ExifDataTest < Test::Unit::TestCase

  def test_create_json
    e = ExifData.new('{"Make":"SONY", "DateTime":"1998:10:01 10:15:30"}')
    assert_equal 'SONY', e['Make']
    assert_equal Time.parse('1998-10-01 10:15:30'), e.date_time
  end

  def test_create_array
    e = ExifData.new([["Make","SONY"], ["DateTime","1998:10:01 10:15:30"]])
    assert_equal 'SONY', e['Make']
    assert_equal Time.parse('1998-10-01 10:15:30'), e.date_time
  end

  def test_create_hash
    e = ExifData.new("Make" => "SONY", "DateTime" => "1998:10:01 10:15:30")
    assert_equal 'SONY', e['Make']
    assert_equal Time.parse('1998-10-01 10:15:30'), e.date_time
  end

  def test_create_blank
    assert_equal Hash[], ExifData.new('')
    assert_equal Hash[], ExifData.new(nil)
  end

  def test_date_time
    e = ExifData.new("Make" => "SONY", "DateTime" => "1998:10:01 10:15:30")
    assert_equal Time.parse('1998-10-01 10:15:30'), e.date_time
    assert_equal '1998:10:01 10:15:30', e['DateTime']
    assert_nil e.date_time_original
    assert_nil e.date_time_digitised
  end

  def test_date_time_original
    e = ExifData.new("Make" => "SONY", "DateTimeOriginal" => "1998:10:01 10:15:30")
    assert_equal Time.parse('1998-10-01 10:15:30'), e.date_time_original
    assert_equal '1998:10:01 10:15:30', e['DateTimeOriginal']
    assert_nil e.date_time
    assert_nil e.date_time_digitised
  end

  def test_date_time_digitised
    e = ExifData.new("Make" => "SONY", "DateTimeDigitised" => "1998:10:01 10:15:30")
    assert_equal Time.parse('1998-10-01 10:15:30'), e.date_time_digitised
    assert_equal '1998:10:01 10:15:30', e['DateTimeDigitised']
    assert_nil e.date_time_original
    assert_nil e.date_time
  end

  def test_to_json_should_ignore_symbols
    e = ExifData.new("Make" => "SONY", "DateTime" => "1998:10:01 10:15:30")
    # '{"data":{"Make":"SONY","DateTime":"1998:10:01 10:15:30"},"json_class":"ExifData"}'
    keys = []
    e.to_json.gsub(/"([^"]+)"/) do |m|
      keys << m
    end
    assert_equal '"1998:10:01 10:15:30","DateTime","ExifData","Make","SONY","data","json_class"', keys.sort.join(',')
  end

  def test_gps_longitude
    e = ExifData.new('{"GPSLatitude":"-6/1, -30/1, 0/1", "GPSLongitude":"29/1, 30/1, 0/1"}')
    assert_equal 29.5, e.gps_longitude
  end

  def test_gps_latitude
    e = ExifData.new('{"GPSLatitude":"-6/1, -30/1, 0/1", "GPSLongitude":"29/1, 30/1, 0/1"}')
    assert_equal -6.5, e.gps_latitude
  end
end