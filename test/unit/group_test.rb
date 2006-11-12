require File.dirname(__FILE__) + '/../test_helper'

class GroupTest < Test::Unit::TestCase
  include ZenaTestUnit
  fixtures :groups

  def test_truth
    assert true
  end
end
