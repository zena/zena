require File.dirname(__FILE__) + '/../test_helper'

class LinkDummy < ActiveRecord::Base
  acts_as_secure
  acts_as_multiversioned
  set_table_name 'items'
  link :icon, :class=>Image, :unique=>true
  link :tags, :class=>Collector
  # test reverse links
  link :hot, :class=>LinkDummy, :unique=>true
  link :hot_for, :class=>LinkDummy, :as=>'hot'
  link :recipients, :class=>LinkDummy
  link :letters, :class=>LinkDummy, :as=>'recipient'
  def ref_field; :parent_id; end
end

class LinkTest < Test::Unit::TestCase
  include ZenaTestUnit
  fixtures :items, :versions, :addresses, :groups, :groups_users
  
  def setup
    super
    LinkDummy.connection.execute "UPDATE items SET type='LinkDummy' WHERE id IN (11,12,19);"
  end
  
  def test_link_icon
    visitor(:lion)
    @item = secure(LinkDummy) { LinkDummy.find(19) }
    assert_nil @item.icon
    @item.icon_id = 20
    assert @item.save
    assert_equal 20, @item.icon_id
    assert_kind_of Image, icon = @item.icon
    assert_equal 20, icon[:id]
    assert_equal "bird.jpg", icon.name
  end
  
  def test_bad_icon
    visitor(:lion)
    @item = secure(LinkDummy) { LinkDummy.find(19) }
    assert_nil @item.icon
    @item.icon_id = 'hello'
    assert_nil @item.icon
    @item.icon_id = 4 # bad class
    @item.save
    assert_equal 0, Link.find_all_by_source_id_and_role(19, 'icon').size
    @item.icon_id = 13645
    @item.save
    assert_equal 0, Link.find_all_by_source_id_and_role(19, 'icon').size
  end
  
  def test_unique_icon
    visitor(:lion)
    @item = secure(LinkDummy) { LinkDummy.find(19) }
    assert_nil @item.icon
    @item.icon_id = 20
    @item.save
    assert_equal 20, @item.icon[:id]
    @item.icon_id = 21
    @item.save
    assert_equal 21, @item.icon[:id]
    assert_equal 1, Link.find_all_by_source_id_and_role(19, 'icon').size
  end
  
  def test_remove_icon
    visitor(:lion)
    @item = secure(LinkDummy) { LinkDummy.find(19) }
    assert_nothing_raised { @item.icon_id = nil }
    @item.icon_id = 20
    @item.save
    assert_equal 20, @item.icon[:id]
    @item.icon_id = nil
    @item.save
    assert_nil @item.icon
    @item.icon_id = '20'
    @item.save
    assert_equal 20, @item.icon[:id]
    @item.icon_id = ''
    @item.save
    assert_nil @item.icon
  end
  
  def test_many_tags
    visitor(:lion)
    @item = secure(LinkDummy) { LinkDummy.find(19) }
    assert_nothing_raised { @item.tags }
    assert_equal [], @item.tags
    @item.tag_ids = [23,24]
    @item.save
    tags = @item.tags
    assert_equal 2, tags.size
    assert_equal 'art', tags[0].name
    assert_equal 'news', tags[1].name
    @item.tag_ids = [23]
    @item.save
    tags = @item.tags
    assert_equal 1, tags.size
    assert_equal 'art', tags[0].name
  end
  
  def test_can_remove_tag
    visitor(:lion)
    @item = secure(LinkDummy) { LinkDummy.find(19) }
    @item.tag_ids = [23,24]
    @item.save
    assert_equal 2, @item.tags.size
    @item.remove_tag(23)
    @item.save
    tags = @item.tags
    assert_equal 1, tags.size
    assert_equal 'news', tags[0].name
  end

  def test_can_add_tag
    visitor(:lion)
    @item = secure(LinkDummy) { LinkDummy.find(19) }
    @item.add_tag(24)
    @item.save
    tags = @item.tags
    assert_equal 1, tags.size
    assert_equal 'news', tags[0].name
  end

  def test_hot_for
    visitor(:lion)
    @source = secure(LinkDummy) { LinkDummy.find(19) }
    @target = secure(LinkDummy) { LinkDummy.find(11) }
    @source.hot_id = @target[:id]
    @source.save
    assert_equal @target[:name], @source.hot[:name]
    assert_equal @source[:name], @target.hot_for[0][:name]
  end
  
  def test_recipients_and_letters
    visitor(:lion)
    @source  = secure(LinkDummy) { LinkDummy.find(19)  }
    @target1 = secure(LinkDummy) { LinkDummy.find(11) }
    @target2 = secure(LinkDummy) { LinkDummy.find(12) }
    @source.recipient_ids = [11,12]
    @source.save
    assert_equal 2, @source.recipients.size
    assert_equal @source[:name], @target1.letters[0][:name]
    assert_equal @source[:name], @target2.letters[0][:name]
    @target1.remove_letter(19)
    @target1.save
    assert_equal 1, @source.recipients.size
    assert_equal [], @target1.letters
    assert_equal @source[:name], @target2.letters[0][:name]
  end
  
end
