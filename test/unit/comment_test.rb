require File.dirname(__FILE__) + '/../test_helper'

class CommentTest < ZenaTestUnit

  def test_cannot_set_site_id
    login(:anon)
    comment = comments(:ant_says_inside)
    assert_raise(Zena::AccessViolation) { comment.site_id = sites_id(:ocean) }
    assert_raise(Zena::AccessViolation) { secure(Comment) { Comment.create( :user_id=>1, :title=>'boo', :text=>'blah', :discussion_id=>2, :author_name=>'joe', :site_id => 2 ) } }
  end
  
  def test_site_id
    login(:anon)
    comment = secure(Comment) { Comment.create( :user_id=>1, :title=>'boo', :text=>'blah', :discussion_id=>2, :author_name=>'joe') }
    assert !comment.new_record?, "Not a new record"
    assert_equal sites_id(:zena), comment.site_id
  end
  
  def test_no_replies
    comment = comments(:lion_says_inside)
    assert_equal [], comment.replies
  end
  
  def test_author
    login(:anon)
    comment = secure(Comment) { comments(:lion_says_inside) }
    assert_equal 'PLV', comment.author.initials
  end
  
  def test_remove
    login(:lion)
    comment = secure(Comment) { comments(:lion_says_inside) }
    assert_equal Zena::Status[:pub], comment[:status]
    assert comment.remove
    comment = comments(:lion_says_inside)
    assert_equal Zena::Status[:rem], comment[:status]
  end
  
  def test_moderate_anonymous_comments
    login(:tiger)
    bak = visitor.status
    visitor.status = User::Status[:moderated]
    
    discussion = secure(Discussion) { Discussion.create(:node_id=>11, :lang=>'en') }
    
    comment    = secure(Comment   ) { Comment.create( :title=>'coco', :text=>'spam see my web site', :author_name=>'me', :discussion_id=>discussion[:id] ) }
    assert !comment.new_record?, "Not a new record"
    assert_equal Zena::Status[:prop], comment[:status]
    
    visitor.status = User::Status[:user]
    comment = secure(Comment) { Comment.create(:title=>'coco again', :text=>'spam see my web site again', :author_name=>'me', :discussion_id=>discussion[:id] ) }
    assert !comment.new_record?, "Not a new record"
    assert_equal Zena::Status[:pub], comment[:status]
    
    comments = discussion.comments
    assert_equal 1, comments.size
    assert_equal 2, discussion.comments(:with_prop=>true).size
  end
  
  def test_set_comment
    login(:anon)
    comment    = secure(Comment) { comments(:lion_says_inside) }
    discussion = comment.discussion
    reply      = secure(Comment) { Comment.create( :text=>'blah blah', :author_name=>'me', :reply_to=>comment[:id], :discussion_id=>discussion[:id] ) }
    assert !reply.new_record?, "Not a new record"
    assert_equal 're: OK for me', reply[:title]
  end
  
  def test_valid_comment
    login(:anon)
    comment = secure(Comment) { Comment.create( :title=>'boo', :text=>'blah', :discussion_id=>2 ) }
    assert comment.new_record?, "Is a new record"
    assert_equal "can't be blank", comment.errors[:author_name]
    
    login(:tiger)
    comment = secure(Comment) { Comment.create( :title=>'boo', :text=>'blah', :discussion_id=>2 ) }
    assert ! comment.new_record?, "Not a new record"
    assert_nil comment.author_name, "Author name is nil"
  end
  

  def test_prop_replies
    login(:anon)
    comment = comments(:ant_says_inside)
    prop_reply = secure(Comment) { Comment.create(:discussion_id=>comment[:discussion_id], :reply_to=>comment[:id], :title=>'bob', :author_name=>'any', :text=>'blah') }
    
    assert !prop_reply.new_record?, "Not a new record"
    assert_equal Zena::Status[:prop], prop_reply[:status]
    
    replies = comment.replies
    replies_with_prop = comment.replies(:with_prop=>true)
    assert_equal 1, replies.size
    assert_equal comments_id(:tiger_reply_inside), replies[0][:id]
    assert_equal 2, replies_with_prop.size
    assert_equal prop_reply[:id], replies_with_prop[1][:id]
  end
end
