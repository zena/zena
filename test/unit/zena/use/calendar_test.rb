require 'test_helper'

class CalendarTest < Zena::View::TestCase
  include Zena::Use::Calendar::ViewMethods
  include Zena::Use::Refactor::ViewMethods # fquote
  include Zena::Use::I18n::ViewMethods # _
  include Zena::Use::Urls::ViewMethods # data_path

  def fmt(date)
    date.strftime('%Y-%m-%d %H:%M')
  end

  context 'With a timezone' do
    setup do
      login(:tiger)
      @tz = TZInfo::Timezone.get('Asia/Jakarta')
    end

    should 'map start on first' do
      # 1st of May, 2 hours in the morning for the visitor
      # October 2000 is a month starting on a Sunday 1st
      visitor_time = Time.utc(2000, 10, 1, 2)
      # UTC = 2000-09-30 19:00
      utc_time = @tz.local_to_utc(visitor_time)

      # 0 = week starts on Sunday
      start_date, end_date = cal_start_end(utc_time, :month, @tz, 0)
      assert_equal '2000-09-30 17:00', fmt(start_date)
      assert_equal '2000-11-04 17:00', fmt(end_date)

      # This is what the visitor sees:
      assert_equal '2000-10-01 00:00', fmt(@tz.utc_to_local(start_date))
      assert_equal '2000-11-05 00:00', fmt(@tz.utc_to_local(end_date))
    end

    should 'map start on previous month' do
      # 18st of May, 2 hours in the morning for the visitor
      # March 2006 is a month starting on a Sunday 26th of February
      visitor_time = Time.utc(2006, 03, 18)
      # UTC = 2006-03-17 17:00
      utc_time = @tz.local_to_utc(visitor_time)

      start_date, end_date = cal_start_end(utc_time, :month, @tz, 0)
      assert_equal '2006-02-25 17:00', fmt(start_date)
      assert_equal '2006-04-01 17:00', fmt(end_date)

      # This is what the visitor sees:
      assert_equal '2006-02-26 00:00', fmt(@tz.utc_to_local(start_date))
      assert_equal '2006-04-02 00:00', fmt(@tz.utc_to_local(end_date))
    end

    context 'with a date' do
      setup do
        assert_equal 0, _('week_start_day').to_i
        # 18st of May, 2 hours in the morning for the visitor
        # April 2011 is a month ending on Saturday 30th.
        visitor_time = Time.utc(2011, 04, 21)
        # UTC = 2006-03-17 17:00
        @utc_time = @tz.local_to_utc(visitor_time)
      end

      subject do
        cal_start_end(@utc_time, :month, @tz, 0)
      end

      should 'not overlap on next month' do
        start_date, end_date = subject
        assert_equal '2011-03-26 17:00', fmt(start_date)
        assert_equal '2011-04-30 17:00', fmt(end_date)

        # This is what the visitor sees:
        assert_equal '2011-03-27 00:00', fmt(@tz.utc_to_local(start_date))
        assert_equal '2011-05-01 00:00', fmt(@tz.utc_to_local(end_date))
      end

      should 'not include last date in cal_weeks' do
        start_date, end_date = subject

        sundays = []
        cal_weeks('', [], start_date, end_date, @tz) do |week, list|
          sundays << fmt(week)
        end

        assert_equal [
          '2011-03-26 17:00',
          '2011-04-02 17:00',
          '2011-04-09 17:00',
          '2011-04-16 17:00',
          '2011-04-23 17:00'], sundays

      end

      should 'map week names starting Sunday' do
        assert_equal "<th class='sun'>Sunday</th><th>Monday</th><th>Tuesday</th><th>Wednesday</th><th>Thursday</th><th>Friday</th><th class='sat'>Saturday</th>", cal_day_names('large', 0)
      end
      
      should 'map week names starting Monday' do
        assert_equal "<th>Monday</th><th>Tuesday</th><th>Wednesday</th><th>Thursday</th><th>Friday</th><th class='sat'>Saturday</th><th class='sun'>Sunday</th>", cal_day_names('large', 1)
      end
    end # with a date
  end # With a timezone
end