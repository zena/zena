require File.dirname(__FILE__) + '/../test_helper'

class CommentTest < Test::Unit::TestCase
  include ZenaTestUnit
  fixtures :comments, :items, :versions
  def test_truth
    assert true
  end
end
