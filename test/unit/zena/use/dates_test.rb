require 'test_helper'

class DatesTest < Zena::View::TestCase

  def test_date_box
    login(:anon)
    visiting(:status)
    assert_match %r{span class="date_box".*img src="\/calendar\/iconCalendar.gif".*input id='datef.*' name='node\[updated_at\]' type='text' value='2006-04-11 00:00'}m, date_box(@node, 'updated_at')
  end

  # see dates.yml
end