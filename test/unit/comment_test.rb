require File.dirname(__FILE__) + '/../test_helper'

class CommentTest < Test::Unit::TestCase
  include ZenaTestUnit

  def test_replies
    comment = comments(:ant_says_inside)
    replies = comment.replies
    assert_equal 1, replies.size
    assert_equal comments_id(:tiger_reply_inside), replies[0][:id]
  end
  
  def test_no_replies
    comment = comments(:lion_says_inside)
    assert_equal [], comment.replies
  end
  
  def test_author
    comment = comments(:lion_says_inside)
    assert_equal 'PLV', comment.author.initials
  end
    
end
