require 'test_helper'

class DiscussionTest < Zena::Unit::TestCase

  def test_comments
    discussion = Discussion.find(discussions_id(:inside_discussion_on_status))
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

  def test_cannot_set_site_id_for_new_record
    disc = Discussion.new(:site_id=>1234)
    assert_nil disc.site_id
  end

  def test_cannot_set_site_id
    disc = discussions(:inside_discussion_on_status)
    original_site_id = disc.site_id
    disc.update_attributes(:site_id =>1234)
    assert_equal original_site_id, disc.site_id
  end

  def test_site_id
    login(:tiger)
    disc = Discussion.create(:node_id=>nodes_id(:projects))
    assert !disc.new_record?, "Not a new record"
    assert_equal sites_id(:zena), disc.site_id
  end

  context 'A visitor without write access' do
    setup do
      login(:anon)
    end

    context 'on a node without a publication in the current lang' do
      setup do
        login(:lion)
        visitor.lang = 'fr'
        node = secure!(Node) { nodes(:status) }
        node.unpublish
        login(:anon)
        @node = secure!(Node) { nodes(:status) }
      end

      should 'see the discussion related to the seen version' do
        assert_equal discussions_id(:outside_discussion_on_status_en), @node.discussion.id
      end
    end
  end
end
