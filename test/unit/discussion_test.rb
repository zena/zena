require File.dirname(__FILE__) + '/../test_helper'

class DiscussionTest < ZenaTestUnit

  def test_comments
    discussion = Discussion.find(1)
    assert_kind_of Discussion, discussion
    comments = discussion.comments
    assert_equal 3, comments.size   # only find 'root' comments
    assert_equal comments_id(:tiger_says_inside), comments[0][:id]
    assert_equal comments_id(:ant_says_inside),   comments[1][:id]
    assert_equal comments_id(:lion_says_inside),  comments[2][:id]
    allcomm = discussion.all_comments
    assert_equal 4, allcomm.size
    assert_equal comments_id(:tiger_says_inside),  allcomm[0][:id]
    assert_equal comments_id(:ant_says_inside),    allcomm[1][:id]
    assert_equal comments_id(:tiger_reply_inside), allcomm[3][:id]
  end
end
