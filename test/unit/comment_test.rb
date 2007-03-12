require File.dirname(__FILE__) + '/../test_helper'

class CommentTest < ZenaTestUnit

  def test_replies
    comment = comments(:ant_says_inside)
    prop_reply = Comment.create(:discussion_id=>comment[:discussion_id], :reply_to=>comment[:id], :title=>'bob', :author_name=>'any', :text=>'blah')
    assert !prop_reply.new_record?, "Not a new record"
    assert_equal Zena::Status[:prop], prop_reply[:status]
    replies = comment.replies
    assert_equal 1, replies.size
    assert_equal comments_id(:tiger_reply_inside), replies[0][:id]
    assert_equal 2, replies(:with_prop=>true).size
    assert_equal prop_reply[:id], replies[1][:id]
  end
  
  def test_no_replies
    comment = comments(:lion_says_inside)
    assert_equal [], comment.replies
  end
  
  def test_author
    comment = comments(:lion_says_inside)
    assert_equal 'PLV', comment.author.initials
  end
  
  def test_remove
    comment = comments(:lion_says_inside)
    assert_equal Zena::Status[:pub], comment[:status]
    assert comment.remove
    comment = comments(:lion_says_inside)
    assert_equal Zena::Status[:rem], comment[:status]
  end
  
  def test_moderate_anonymous_comments
    bak = ZENA_ENV[:moderate_anonymous_comments]
    discussion = Discussion.create(:node_id=>11, :lang=>'en')
    ZENA_ENV[:moderate_anonymous_comments] = true
    comment = Comment.create( :user_id=>1, :title=>'coco', :text=>'spam see my web site', :author_name=>'me', :discussion_id=>discussion[:id] )
    assert !comment.new_record?, "Not a new record"
    assert_equal Zena::Status[:prop], comment[:status]
    ZENA_ENV[:moderate_anonymous_comments] = false
    comment = Comment.create( :user_id=>1, :title=>'coco again', :text=>'spam see my web site again', :author_name=>'me', :discussion_id=>discussion[:id] )
    assert !comment.new_record?, "Not a new record"
    assert_equal Zena::Status[:pub], comment[:status]
    ZENA_ENV[:moderate_anonymous_comments] = bak
    comments = discussion.comments
    assert_equal 1, comments.size
    assert_equal 2, discussion.comments(:with_prop=>true).size
  end
  
  def test_set_comment
    comment    = comments(:lion_says_inside)
    discussion = comment.discussion
    reply      = Comment.create( :user_id=>1, :text=>'blah blah', :author_name=>'me', :reply_to=>comment[:id], :discussion_id=>discussion[:id] )
    assert !reply.new_record?, "Not a new record"
    assert_equal 're: OK for me', reply[:title]
  end
  
  def test_valid_comment
    comment = Comment.create( :user_id=>1, :title=>'boo', :text=>'blah', :discussion_id=>2 )
    assert comment.new_record?, "Is a new record"
    assert_equal "can't be blank", comment.errors[:author_name]
    
    comment = Comment.create( :user_id=>3, :title=>'boo', :text=>'blah', :discussion_id=>2 )
    err comment
    assert ! comment.new_record?, "Not a new record"
    assert_nil comment.author_name, "Author name is nil"
  end
  
  def test_replies
    comment = comments(:tiger_reply_inside)
    reply1 = Comment.create( :user_id=>1, :title=>'boo1', :author_name=>'bob', :text=>'blah', :discussion_id=>2, :reply_to=>comment[:id] )
    err reply1
    reply2 = Comment.create( :user_id=>1, :title=>'boo2', :author_name=>'lisa', :text=>'blah', :discussion_id=>2, :reply_to=>comment[:id] )
    replies = comment.replies
    assert_equal 2, replies.size
    Comment.connection.execute "UPDATE comments SET status=#{Zena::Status[:prop]} WHERE id = #{reply2[:id]}"
    comment = comments(:tiger_reply_inside)
    replies = comment.replies
    assert_equal 1, replies.size # prop not seen
    assert_equal 'boo1', replies[0][:title]
  end
end
