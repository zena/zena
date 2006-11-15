require File.dirname(__FILE__) + '/../test_helper'

class TrackerTest < Test::Unit::TestCase
  include ZenaTestUnit


  # Replace this with your real tests.
  def test_kpath
    assert_equal 'IPA', Tracker.kpath
  end
end
