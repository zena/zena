require File.dirname(__FILE__) + '/../test_helper'

class CollectorTest < Test::Unit::TestCase
  include ZenaTestUnit
  fixtures :links, :items
  def test_truth
    assert true
  end
end
