require 'rubygems'
require 'tzinfo'
require 'test/unit'
require 'fileutils'
require File.join(File.dirname(__FILE__), '../../lib/core_ext/string')
require File.join(File.dirname(__FILE__), '../../lib/core_ext/fixnum')
require File.join(File.dirname(__FILE__), '../../lib/core_ext/dir')

class StringExtTest < Test::Unit::TestCase  
  def test_iso_format
    assert_equal Time.utc(2007,10,16,15,30,10), "2007-10-16 15:30:10".to_utc('%Y-%m-%d %H:%M:%S')
  end
  
  def test_swiss_format
    assert_equal Time.utc(2007,10,16,15,30), "16.10.2007 15:30".to_utc('%d.%m.%Y %H:%M')
  end
  
  def test_date_only
    assert_equal Time.utc(1975,10,16), "10/16/1975".to_utc('%m/%d/%Y')
  end
  
  def test_to_utc_with_timezone
    # UTC+1, no Daylight time savings
    assert_equal Time.utc(2008,1,3,12,03,10), "2008-01-03 13:03:10".to_utc('%Y-%m-%d %H:%M:%S', TZInfo::Timezone.get("Europe/Paris"))
    # UTC+1, +1h Daylight time savings
    assert_equal Time.utc(2008,5,17,11,03,10), "2008-05-17 13:03:10".to_utc('%Y-%m-%d %H:%M:%S', TZInfo::Timezone.get("Europe/Paris"))
  end
  
  def test_bad_to_utc
    assert_nil "2008-05-17".to_utc('%d.%m.%Y')
  end
  
  def test_as_duration
    [
      [0, '0'],
      [1, '1 second'],
      [45, '45 seconds'],
      [60, '1 minute'],
      [65, '1 minute 5 seconds'],
      [3600, '1 hour'],
      [3840, '1 hour 4 minutes'],
      [60*60*24, '1 day'],
      [60*60*24*3, '3 days'],
      [60*60*24*30, '1 month'],
      [60*60*24*31, '1 month 1 day'],
      [60*60*24*365, '1 year'],
      [60*60*24*365*5, '5 years'],
      [60*60*24*365*5 + 60*60*24*(30*2 + 1) + 125, '5 years 2 months 1 day 2 minutes 5 seconds'],
    ].each do |i,s|
      assert_equal s, i.as_duration, s
    end
  end
  
  def test_to_duration
    [
      [0, '0'],
      [1, '1 second'],
      [45, '45 seconds'],
      [60, '1 minute'],
      [65, '1 minute 5 seconds'],
      [3600, '1 hour'],
      [3840, '1 hour 4 minutes'],
      [60*60*24, '1 day'],
      [60*60*24*3, '3 days'],
      [60*60*24*30, '1 month'],
      [60*60*24*31, '1 month 1 day'],
      [60*60*24*365, '1 year'],
      [60*60*24*365*5, '5 years'],
      [60*60*24*365*5 + 60*60*24*(30*2 +1) + 125, '5 years 2 months 1 day 2 minutes 5 seconds'],
    ].each do |i,s|
      assert_equal i, s.to_duration, s
    end
  end
  
  
  def test_to_duration_other_syntaxes
    [
      [0, '0'],
      [1, '1s'],
      [45, '45s'],
      [60, '1m'],
      [65, '1m 5sec'],
      [3600, '1 h'],
      [3840, '1h 4m'],
      [60*60*24, '1d'],
      [60*60*24*3, '3d'],
      [60*60*24*30, '1M'],
      [60*60*24*31, '1 M 1 day'],
      [60*60*24*365, '1Y'],
      [60*60*24*365, '1Y year'],
      [60*60*24*368, '1Y 2 3 days'], # 1 year 3 days
      [3600 * (5 + 24) + 34,'5h 1d 34 seconds'],
      [60*60*24*365*5, '5y'],
      [60*60*24*365*5 + 60*60*24*(30*2 +1) + 125, '2M 1d 5y 2m 5s'],
    ].each do |i,s|
      assert_equal i, s.to_duration, s
    end
  end
  
  def test_abs_rel_path
    {
      'a/b/c/d' => 'd', 
      'a/x'     => '../../x',
      'y/z'     => '../../../y/z',
      'a/b/d'   => '../d',
      'a/b/c'   => '',
      }.each do |orig, test_rel|
        rel = orig.rel_path('a/b/c')
        assert_equal rel, test_rel, "'#{orig}' should become the relative path '#{test_rel}'"
        abs = rel.abs_path('a/b/c')
        assert_equal rel, test_rel, "'#{rel}' should become the absolute path '#{orig}'"
    end
    
    {
      'a/b/c/d' => 'a/b/c/d', 
      'a/x'     => 'a/x',
      }.each do |orig, test_rel|
        rel = orig.rel_path('')
        assert_equal rel, test_rel, "'#{orig}' should become the relative path '#{test_rel}'"
        abs = rel.abs_path('')
        assert_equal rel, test_rel, "'#{rel}' should become the absolute path '#{orig}'"
    end
    
    assert_equal "/a/b/c", ''.abs_path('/a/b/c')
  end
end

class DirExtTest < Test::Unit::TestCase
  def test_empty?
    name = 'asldkf9032oi09sdflk'
    FileUtils.rmtree(name)
    FileUtils.mkpath(name)
    assert File.exist?(name) && Dir.empty?(name)
    File.open(File.join(name,'hello.txt'), 'wb') {|f| f.puts "hello" }
    assert !Dir.empty?(name)
    FileUtils.rmtree(name)
  end
end