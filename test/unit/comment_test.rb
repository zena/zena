require File.dirname(__FILE__) + '/../test_helper'

class CommentTest < UnitTestCase
  fixtures :comments, :items, :versions
  def test_truth
    assert true
  end
end
