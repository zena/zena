require File.dirname(__FILE__) + '/../test_helper'

class ContactTest < Test::Unit::TestCase
  include ZenaTestUnit
  fixtures :items
  def test_truth
    assert true
  end
end
