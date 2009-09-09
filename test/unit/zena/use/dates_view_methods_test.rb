require 'test_helper'

class DatesViewMethodsTest < Zena::View::TestCase
  include Zena::Use::Dates::ViewMethods
  include Zena::Use::Refactor::ViewMethods # fquote
  include Zena::Use::I18n::ViewMethods # _
  
  def setup
    super
    I18n.locale = 'en'
    visitor.time_zone = 'UTC'
  end
  
  def test_long_time
    atime = visitor.tz.local_to_utc(Time.utc(2006,11,10,17,42,25)) # local time for visitor
    assert_equal "17:42:25", long_time(atime)
    I18n.locale = 'fr'
    assert_equal "17:42:25", long_time(atime)
  end
  
  def test_short_time
    atime = visitor.tz.local_to_utc(Time.utc(2006,11,10,17,33))
    assert_equal "17:33", short_time(atime)
    I18n.locale = 'fr'
    assert_equal "17h33", short_time(atime)
  end
  
  def test_short_time_visitor_time_zone
    login(:ant) # Europe/Zurich UTC+1, DST+1
    atime = Time.utc(2008,05,18,17,33)
    assert_equal "19:33", short_time(atime)
    I18n.locale = 'fr'
    assert_equal "19h33", short_time(atime)
  end

  def test_long_date
    atime = visitor.tz.utc_to_local(Time.gm(2006,11,10))
    assert_equal "2006-11-10", long_date(atime)
    I18n.locale = 'fr'
    assert_equal "10.11.2006", long_date(atime)
  end

  def test_full_date
    atime = visitor.tz.utc_to_local(Time.gm(2006,11,10))
    assert_equal "Friday, November 10 2006", full_date(atime)
    I18n.locale = 'fr'
    assert_equal "vendredi, 10 novembre 2006", full_date(atime)
  end
  
  def test_short_date
    atime = Time.now.utc
    visitor[:time_zone] = 'London' # utc
    assert_equal atime.strftime('%m.%d'), short_date(atime)
    I18n.locale = 'fr'
    assert_equal atime.strftime('%d.%m'), short_date(atime)
  end
  
  def test_format_date
    atime = Time.now.utc
    visitor[:time_zone] = 'London' # utc
    assert_equal atime.strftime('%m.%d'), tformat_date(atime, 'short_date')
    I18n.locale = 'fr'
    assert_equal atime.strftime('%d.%m'), tformat_date(atime, 'short_date')
  end
  
  def test_format_date_age
    atime = Time.now.utc
    visitor[:time_zone] = 'UTC' # utc
    {
      0.2         => '1 minute ago',
      -0.2        => 'in 1 minute',
      1.2         => '1 minute ago',
      8.2         => '8 minutes ago',
      -8.5        => 'in 8 minutes',
      45.1        => '45 minutes ago',
      60.1        => '1 hour ago',
      95          => '1 hour ago',
      -95         => 'in 1 hour',
      123         => '2 hours ago',
      -123        => 'in 2 hours',
      23 * 60     => '23 hours ago',
      25 * 60     => 'yesterday',
      -25 * 60    => 'tomorrow',
      29 * 60     => 'yesterday',
      49 * 60     => '2 days ago',
      -49 * 60    => 'in 2 days',
      6 * 24 * 60 => '6 days ago',
      7.1*24 * 60 => (atime - 7.1*24 * 60 * 60).strftime("%Y-%m-%d"),
      -9* 24 * 60 => (atime + 9 * 24 * 60 * 60).strftime("%Y-%m-%d"),
    }.each do |age, phrase|
      assert_equal phrase, format_date(Time.now.utc - (60 * age),'age/%Y-%m-%d')
    end
  end
  
  def test_format_date_age_not_utc
    visitor[:time_zone] = 'Europe/Zurich' # not utc
    atime = Time.now.utc
    {
      0.2         => '1 minute ago',
      -0.2        => 'in 1 minute',
      1.2         => '1 minute ago',
      8.2         => '8 minutes ago',
      -8.5        => 'in 8 minutes',
      45.1        => '45 minutes ago',
      60.1        => '1 hour ago',
      95          => '1 hour ago',
      -95         => 'in 1 hour',
      123         => '2 hours ago',
      -123        => 'in 2 hours',
      23 * 60     => '23 hours ago',
      25 * 60     => 'yesterday',
      -25 * 60    => 'tomorrow',
      29 * 60     => 'yesterday',
      49 * 60     => '2 days ago',
      -49 * 60    => 'in 2 days',
      6 * 24 * 60 => '6 days ago',
      7.1*24 * 60 => (atime - 7.1*24 * 60 * 60).strftime("%Y-%m-%d"),
      -9* 24 * 60 => (atime + 9 * 24 * 60 * 60).strftime("%Y-%m-%d"),
    }.each do |age, phrase|
      assert_equal phrase, format_date(Time.now.utc - (60 * age),'age/%Y-%m-%d')
    end
  end
  
  def test_string_to_utc_with_visitor_time_zone
    login(:ant)
    visitor[:time_zone] = "Europe/Zurich"
    
    # UTC+1, no Daylight time savings
    assert_equal Time.utc(2008,1,3,12,03,10), "2008-01-03 13:03:10".to_utc('%Y-%m-%d %H:%M:%S', visitor.tz)
    # UTC+1, Daylight time savings
    assert_equal Time.utc(2008,5,17,11,03,10), "2008-05-17 13:03:10".to_utc('%Y-%m-%d %H:%M:%S', visitor.tz)
    
    # convert back and forth
    [
      ["2008-05-17 13:03:10", '%Y-%m-%d %H:%M:%S'],
      ["03.01.2008 13:03:10", '%d.%m.%Y %H:%M:%S'],
    ].each do |date_str, format|
      assert_equal date_str, format_date(date_str.to_utc(format, visitor.tz), format)
    end
    
    login(:ant) # Europe/Paris
    visitor[:time_zone] = "Asia/Jakarta"
    
    # UTC+7, no Daylight time savings
    assert_equal Time.utc(2008,1,3,12,03,10), "2008-01-03 19:03:10".to_utc('%Y-%m-%d %H:%M:%S', visitor.tz)
    # UTC+7, no Daylight time savings
    assert_equal Time.utc(2008,5,17,12,03,10), "2008-05-17 19:03:10".to_utc('%Y-%m-%d %H:%M:%S', visitor.tz)
    
    
    # convert back and forth
    [
      ["2008-05-17 13:03:10", '%Y-%m-%d %H:%M:%S'],
      ["03.01.2008 13:03:10", '%d.%m.%Y %H:%M:%S'],
    ].each do |date_str, format|
      assert_equal date_str, format_date(date_str.to_utc(format, visitor.tz), format)
    end
  end
end

class DatesStringMethodsTest < Test::Unit::TestCase
  
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
end